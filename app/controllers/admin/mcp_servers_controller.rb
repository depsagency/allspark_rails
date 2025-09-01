class Admin::McpServersController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :set_mcp_server, only: [:show, :edit, :update, :destroy, :test_connection, :discover_tools, :monitoring]
  
  # GET /admin/mcp_servers
  def index
    # Redirect to new interface with deprecation notice
    redirect_to admin_mcp_configurations_path, 
                notice: "The MCP Servers interface has been replaced with MCP Configurations. You've been redirected to the new interface." and return
    
    @mcp_servers = McpServer.includes(:user, :instance)
    
    # Apply search filter if present
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @mcp_servers = @mcp_servers.where(
        "name ILIKE ? OR endpoint ILIKE ?", 
        search_term, search_term
      )
    end
    
    # Apply status filter if present
    if params[:status].present?
      @mcp_servers = @mcp_servers.where(status: params[:status])
    end
    
    # Apply auth type filter if present
    if params[:auth_type].present?
      @mcp_servers = @mcp_servers.where(auth_type: params[:auth_type])
    end
    
    @mcp_servers = @mcp_servers.page(params[:page]).per(20)
    
    # Get health statistics
    @health_stats = calculate_health_statistics
    
    respond_to do |format|
      format.html
      format.json { render json: @mcp_servers }
    end
  end

  # GET /admin/mcp_servers/1
  def show
    @audit_logs = @mcp_server.mcp_audit_logs.recent.limit(10)
    @connection_stats = get_connection_stats(@mcp_server)
    @available_tools = get_available_tools(@mcp_server)
    @health_status = get_health_status(@mcp_server)
  end

  # GET /admin/mcp_servers/new
  def new
    @mcp_server = McpServer.new
  end

  # POST /admin/mcp_servers
  def create
    @mcp_server = McpServer.new(mcp_server_params)
    
    # Set as system-wide server (admin creates system servers)
    @mcp_server.user_id = nil
    @mcp_server.instance_id = nil
    
    if @mcp_server.save
      # Test connection immediately after creation
      test_result = test_server_connection(@mcp_server)
      
      if test_result[:success]
        # Schedule tool discovery
        McpToolDiscoveryJob.perform_later(@mcp_server.id)
        
        redirect_to admin_mcp_server_path(@mcp_server), 
                   notice: 'MCP server was successfully created and connection test passed.'
      else
        flash[:warning] = "MCP server was created but connection test failed: #{test_result[:error]}"
        redirect_to admin_mcp_server_path(@mcp_server)
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /admin/mcp_servers/1/edit
  def edit
  end

  # PATCH/PUT /admin/mcp_servers/1
  def update
    if @mcp_server.update(mcp_server_params)
      # Test connection after update
      test_result = test_server_connection(@mcp_server)
      
      if test_result[:success]
        # Re-discover tools if endpoint or auth changed
        if endpoint_or_auth_changed?
          McpToolDiscoveryJob.perform_later(@mcp_server.id, force: true)
        end
        
        redirect_to admin_mcp_server_path(@mcp_server), 
                   notice: 'MCP server was successfully updated.'
      else
        flash[:warning] = "MCP server was updated but connection test failed: #{test_result[:error]}"
        redirect_to admin_mcp_server_path(@mcp_server)
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/mcp_servers/1
  def destroy
    server_name = @mcp_server.name
    
    # Clean up connections
    McpConnectionManager.instance.release_connection(@mcp_server)
    
    # Clean up cached tools
    McpToolRegistry.instance.unregister_server_tools(@mcp_server.id)
    
    if @mcp_server.destroy
      redirect_to admin_mcp_servers_path, 
                 notice: "MCP server '#{server_name}' was successfully deleted."
    else
      redirect_to admin_mcp_server_path(@mcp_server), 
                 alert: 'Failed to delete MCP server.'
    end
  end

  # POST /admin/mcp_servers/1/test_connection
  def test_connection
    result = test_server_connection(@mcp_server)
    
    respond_to do |format|
      format.json { render json: result }
      format.html do
        if result[:success]
          redirect_to admin_mcp_server_path(@mcp_server), 
                     notice: 'Connection test successful!'
        else
          redirect_to admin_mcp_server_path(@mcp_server), 
                     alert: "Connection test failed: #{result[:error]}"
        end
      end
    end
  end

  # POST /admin/mcp_servers/1/discover_tools
  def discover_tools
    begin
      McpToolDiscoveryJob.perform_later(@mcp_server.id, force: true)
      
      respond_to do |format|
        format.json { render json: { success: true, message: 'Tool discovery started' } }
        format.html do
          redirect_to admin_mcp_server_path(@mcp_server), 
                     notice: 'Tool discovery has been started in the background.'
        end
      end
    rescue => e
      respond_to do |format|
        format.json { render json: { success: false, error: e.message } }
        format.html do
          redirect_to admin_mcp_server_path(@mcp_server), 
                     alert: "Failed to start tool discovery: #{e.message}"
        end
      end
    end
  end

  # GET /admin/mcp_servers/1/monitoring
  def monitoring
    @usage_stats = get_usage_statistics(@mcp_server)
    @error_stats = get_error_statistics(@mcp_server)
    @performance_stats = get_performance_statistics(@mcp_server)
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          usage: @usage_stats,
          errors: @error_stats,
          performance: @performance_stats
        }
      end
    end
  end

  # GET /admin/mcp_servers/analytics
  def analytics
    timeframe = params[:timeframe] || 'last_7_days'
    @analytics = get_global_analytics_data(timeframe)
    
    respond_to do |format|
      format.html
      format.json { render json: @analytics }
    end
  end

  # POST /admin/mcp_servers/bulk_action
  # POST /admin/mcp_servers/:id/convert_to_configuration
  def convert_to_configuration
    @mcp_server = McpServer.find(params[:id])
    
    # Create new MCP configuration from server
    config = McpConfiguration.new(
      owner: @mcp_server.user || @mcp_server.instance || User.first,
      name: @mcp_server.name,
      enabled: @mcp_server.active?,
      metadata: {
        converted_from: @mcp_server.id,
        converted_at: Time.current
      }
    )
    
    # Determine server type and build config
    case @mcp_server.transport_type
    when 'http'
      config.server_type = 'http'
      config.server_config = {
        'endpoint' => @mcp_server.endpoint,
        'headers' => build_auth_headers(@mcp_server)
      }
    when 'sse'
      config.server_type = 'sse'
      config.server_config = {
        'url' => @mcp_server.endpoint,
        'headers' => build_auth_headers(@mcp_server)
      }
    when 'websocket'
      config.server_type = 'websocket'
      config.server_config = {
        'endpoint' => @mcp_server.endpoint,
        'headers' => build_auth_headers(@mcp_server)
      }
    else
      # Default to stdio for unknown types
      config.server_type = 'stdio'
      config.server_config = {
        'command' => 'npx',
        'args' => ['-y', "@modelcontextprotocol/server-#{@mcp_server.name.downcase}"],
        'env' => @mcp_server.credentials || {}
      }
    end
    
    if config.save
      # Deactivate old server
      @mcp_server.update!(status: 'inactive')
      
      redirect_to admin_mcp_servers_path, notice: "Successfully converted #{@mcp_server.name} to new configuration format."
    else
      redirect_to admin_mcp_servers_path, alert: "Failed to convert: #{config.errors.full_messages.join(', ')}"
    end
  end
  
  def bulk_action
    server_ids = params[:server_ids] || []
    action = params[:bulk_action]
    
    return redirect_to admin_mcp_servers_path, alert: 'No servers selected' if server_ids.empty?
    
    servers = McpServer.where(id: server_ids)
    results = { success: 0, failed: 0, errors: [] }
    
    case action
    when 'activate'
      servers.each do |server|
        if server.update(status: :active)
          results[:success] += 1
        else
          results[:failed] += 1
          results[:errors] << "#{server.name}: #{server.errors.full_messages.join(', ')}"
        end
      end
      
    when 'deactivate'
      servers.each do |server|
        if server.update(status: :inactive)
          results[:success] += 1
        else
          results[:failed] += 1
          results[:errors] << "#{server.name}: #{server.errors.full_messages.join(', ')}"
        end
      end
      
    when 'test_connections'
      servers.each do |server|
        test_result = test_server_connection(server)
        if test_result[:success]
          results[:success] += 1
        else
          results[:failed] += 1
          results[:errors] << "#{server.name}: #{test_result[:error]}"
        end
      end
      
    when 'discover_tools'
      servers.each do |server|
        begin
          McpToolDiscoveryJob.perform_later(server.id, force: true)
          results[:success] += 1
        rescue => e
          results[:failed] += 1
          results[:errors] << "#{server.name}: #{e.message}"
        end
      end
      
    when 'delete'
      servers.each do |server|
        if server.destroy
          results[:success] += 1
        else
          results[:failed] += 1
          results[:errors] << "#{server.name}: #{server.errors.full_messages.join(', ')}"
        end
      end
      
    else
      return redirect_to admin_mcp_servers_path, alert: 'Invalid bulk action'
    end
    
    if results[:failed] == 0
      redirect_to admin_mcp_servers_path, notice: "Bulk action completed successfully for #{results[:success]} servers."
    else
      error_message = "Bulk action completed with #{results[:failed]} failures: #{results[:errors].join('; ')}"
      redirect_to admin_mcp_servers_path, alert: error_message
    end
  end

  private

  def set_mcp_server
    @mcp_server = McpServer.find(params[:id])
  end

  def mcp_server_params
    params.require(:mcp_server).permit(
      :name, :endpoint, :protocol_version, :auth_type, :status, :transport_type,
      config: {}, credentials: {}
    )
  end

  def ensure_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: 'Access denied. Admin privileges required.'
    end
  end

  def test_server_connection(server)
    begin
      client = McpClient.new(server)
      client.test_connection
      { success: true }
    rescue => e
      Rails.logger.error "[Admin] Connection test failed for server #{server.id}: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def endpoint_or_auth_changed?
    @mcp_server.previous_changes.keys.any? { |key| %w[endpoint auth_type credentials].include?(key) }
  end

  def calculate_health_statistics
    total = McpServer.count
    active = McpServer.active.count
    inactive = McpServer.inactive.count
    error = McpServer.error.count
    
    {
      total: total,
      active: active,
      inactive: inactive,
      error: error,
      health_percentage: total > 0 ? (active.to_f / total * 100).round(1) : 100
    }
  end

  def get_connection_stats(server)
    manager = McpConnectionManager.instance
    pool_status = manager.pool_status
    
    # Find connections for this server
    server_connections = pool_status[:connections].select do |conn|
      conn[:key].include?("server_#{server.id}")
    end
    
    {
      active_connections: server_connections.size,
      healthy_connections: server_connections.count { |c| c[:healthy] },
      avg_idle_time: server_connections.empty? ? 0 : 
                    server_connections.sum { |c| c[:idle_time] } / server_connections.size
    }
  end

  def get_available_tools(server)
    registry = McpToolRegistry.instance
    registry.get_server_tools(server.id)
  rescue => e
    Rails.logger.error "Failed to get tools for server #{server.id}: #{e.message}"
    []
  end

  def get_health_status(server)
    manager = McpConnectionManager.instance
    health_status = manager.health_status(server)
    
    # Get last health check result
    cache_key = "mcp_health_failures_#{server.id}"
    consecutive_failures = Rails.cache.read(cache_key) || 0
    
    {
      healthy: health_status,
      consecutive_failures: consecutive_failures,
      last_check: Rails.cache.read("mcp_health_last_check_#{server.id}")
    }
  end

  def get_usage_statistics(server)
    logs = server.mcp_audit_logs.recent
    
    {
      total_executions: logs.count,
      successful_executions: logs.successful.count,
      failed_executions: logs.failed.count,
      avg_response_time: logs.average(:response_time_ms)&.round(2),
      most_used_tools: logs.group(:tool_name).count.sort_by { |_, count| -count }.first(5),
      daily_usage: get_daily_usage(server),
      top_users: logs.joins(:user).group('users.email').count.sort_by { |_, count| -count }.first(5)
    }
  end

  def get_error_statistics(server)
    error_logs = server.mcp_audit_logs.failed.recent
    
    {
      total_errors: error_logs.count,
      error_rate: calculate_error_rate(server),
      common_errors: group_common_errors(error_logs),
      error_trends: get_error_trends(server)
    }
  end

  def get_performance_statistics(server)
    logs = server.mcp_audit_logs.successful.recent
    response_times = logs.pluck(:response_time_ms).compact
    
    if response_times.any?
      sorted_times = response_times.sort
      {
        avg_response_time: response_times.sum.to_f / response_times.size,
        median_response_time: sorted_times[sorted_times.size / 2],
        p95_response_time: sorted_times[(sorted_times.size * 0.95).to_i],
        min_response_time: sorted_times.first,
        max_response_time: sorted_times.last
      }
    else
      {
        avg_response_time: 0,
        median_response_time: 0,
        p95_response_time: 0,
        min_response_time: 0,
        max_response_time: 0
      }
    end
  end

  def get_daily_usage(server)
    # Get usage for last 7 days
    7.downto(0).map do |days_ago|
      date = days_ago.days.ago.to_date
      count = server.mcp_audit_logs.where(
        executed_at: date.beginning_of_day..date.end_of_day
      ).count
      [date.strftime('%Y-%m-%d'), count]
    end.to_h
  end

  def calculate_error_rate(server)
    total = server.mcp_audit_logs.recent.count
    errors = server.mcp_audit_logs.failed.recent.count
    
    return 0 if total == 0
    (errors.to_f / total * 100).round(2)
  end

  def group_common_errors(error_logs)
    # Group by error patterns in response_data
    error_patterns = {}
    
    error_logs.each do |log|
      error_msg = extract_error_message(log.response_data)
      error_patterns[error_msg] ||= 0
      error_patterns[error_msg] += 1
    end
    
    error_patterns.sort_by { |_, count| -count }.first(5).to_h
  end

  def extract_error_message(response_data)
    return 'Unknown error' unless response_data.is_a?(Hash)
    
    response_data['error'] || response_data['message'] || 'Unknown error'
  end

  def get_error_trends(server)
    # Get error counts for last 7 days
    7.downto(0).map do |days_ago|
      date = days_ago.days.ago.to_date
      count = server.mcp_audit_logs.failed.where(
        executed_at: date.beginning_of_day..date.end_of_day
      ).count
      [date.strftime('%Y-%m-%d'), count]
    end.to_h
  end

  def get_global_analytics_data(timeframe)
    # Determine date range based on timeframe
    end_date = Time.current
    start_date = case timeframe
    when 'last_24_hours'
      24.hours.ago
    when 'last_7_days'
      7.days.ago
    when 'last_30_days'
      30.days.ago
    when 'last_90_days'
      90.days.ago
    else
      7.days.ago
    end

    # Base query for audit logs in timeframe
    audit_logs = McpAuditLog.where(executed_at: start_date..end_date)
    
    {
      overview: get_global_overview(audit_logs),
      usage_trends: get_global_usage_trends(start_date, end_date),
      response_time_distribution: get_response_time_distribution(audit_logs),
      top_servers: get_top_performing_servers(audit_logs),
      popular_tools: get_most_popular_tools(audit_logs),
      health: get_global_health_status,
      unhealthy_servers: get_unhealthy_servers,
      recent_activity: get_recent_activity(50)
    }
  end

  def get_global_overview(audit_logs)
    total_servers = McpServer.count
    active_servers = McpServer.active.count
    total_executions = audit_logs.count
    successful_executions = audit_logs.successful.count
    
    success_rate = total_executions > 0 ? (successful_executions.to_f / total_executions * 100).round(1) : 0
    avg_response_time = audit_logs.successful.average(:response_time_ms)&.round(0) || 0
    
    # Calculate P95 response time
    response_times = audit_logs.successful.pluck(:response_time_ms).compact.sort
    p95_index = (response_times.length * 0.95).ceil - 1
    p95_response_time = response_times[p95_index] || 0

    # Get most used tool
    most_used_tool = audit_logs.group(:tool_name).count.max_by { |_, count| count }&.first || 'None'
    
    # Count total available tools
    total_tools = McpServer.active.sum { |server| server.available_tools&.size || 0 }

    {
      total_servers: total_servers,
      active_servers: active_servers,
      total_executions: total_executions,
      success_rate: success_rate,
      avg_response_time: avg_response_time,
      p95_response_time: p95_response_time,
      total_tools: total_tools,
      most_used_tool: most_used_tool
    }
  end

  def get_global_usage_trends(start_date, end_date)
    days = (start_date.to_date..end_date.to_date).to_a
    labels = days.map { |date| date.strftime('%m/%d') }
    
    successful_data = days.map do |date|
      McpAuditLog.successful.where(
        executed_at: date.beginning_of_day..date.end_of_day
      ).count
    end
    
    failed_data = days.map do |date|
      McpAuditLog.failed.where(
        executed_at: date.beginning_of_day..date.end_of_day
      ).count
    end

    {
      labels: labels,
      successful: successful_data,
      failed: failed_data
    }
  end

  def get_response_time_distribution(audit_logs)
    response_times = audit_logs.successful.pluck(:response_time_ms).compact
    
    # Define buckets
    buckets = {
      '0-100ms' => 0,
      '100-500ms' => 0,
      '500-1000ms' => 0,
      '1000-5000ms' => 0,
      '5000ms+' => 0
    }
    
    response_times.each do |time|
      case time
      when 0..100
        buckets['0-100ms'] += 1
      when 101..500
        buckets['100-500ms'] += 1
      when 501..1000
        buckets['500-1000ms'] += 1
      when 1001..5000
        buckets['1000-5000ms'] += 1
      else
        buckets['5000ms+'] += 1
      end
    end

    {
      labels: buckets.keys,
      data: buckets.values
    }
  end

  def get_top_performing_servers(audit_logs)
    server_stats = {}
    
    McpServer.includes(:mcp_audit_logs).each do |server|
      server_logs = audit_logs.where(mcp_server: server)
      total = server_logs.count
      next if total == 0
      
      successful = server_logs.successful.count
      success_rate = (successful.to_f / total * 100).round(1)
      avg_response = server_logs.successful.average(:response_time_ms)&.round(0) || 0
      
      server_stats[server.id] = {
        name: server.name,
        endpoint: server.endpoint.truncate(40),
        executions: total,
        success_rate: success_rate,
        avg_response_time: avg_response
      }
    end
    
    # Sort by executions and take top 10
    server_stats.values.sort_by { |s| -s[:executions] }.first(10)
  end

  def get_most_popular_tools(audit_logs)
    tool_usage = audit_logs.joins(:mcp_server)
                           .group(:tool_name, 'mcp_servers.name')
                           .count
                           .map { |(tool, server), count| 
                             { 
                               name: tool, 
                               server_name: server, 
                               usage_count: count 
                             } 
                           }
                           .sort_by { |tool| -tool[:usage_count] }
                           .first(10)
    
    tool_usage
  end

  def get_global_health_status
    servers = McpServer.active
    healthy = 0
    warning = 0
    critical = 0
    
    servers.each do |server|
      recent_logs = server.mcp_audit_logs.successful.where('executed_at > ?', 1.hour.ago)
      next if recent_logs.empty?
      
      avg_response_time = recent_logs.average(:response_time_ms) || 0
      
      if avg_response_time < 1000
        healthy += 1
      elsif avg_response_time < 5000
        warning += 1
      else
        critical += 1
      end
    end
    
    # Add servers with no recent successful executions to critical
    # Only check servers that have audit logs to avoid join issues
    if McpAuditLog.exists?
      servers_with_no_recent_success = servers.joins(:mcp_audit_logs)
                                              .where.not(id: servers.joins(:mcp_audit_logs)
                                                                     .where('mcp_audit_logs.status = ? AND mcp_audit_logs.executed_at > ?', 
                                                                            0, 1.hour.ago)
                                                                     .select(:id))
                                              .count
      critical += servers_with_no_recent_success
    else
      # If no audit logs exist, all servers are potentially critical
      critical += servers.count
    end

    {
      healthy: healthy,
      warning: warning,
      critical: critical
    }
  end

  def get_unhealthy_servers
    unhealthy = []
    
    McpServer.active.each do |server|
      # Check for servers with recent failures
      recent_failures = server.mcp_audit_logs.failed.where('executed_at > ?', 1.hour.ago).count
      recent_total = server.mcp_audit_logs.where('executed_at > ?', 1.hour.ago).count
      
      if recent_total > 0 && recent_failures.to_f / recent_total > 0.5
        unhealthy << {
          id: server.id,
          name: server.name,
          status: 'warning',
          issue: "High failure rate: #{recent_failures}/#{recent_total} executions failed in last hour"
        }
      end
      
      # Check for servers with no recent activity
      last_execution = server.mcp_audit_logs.maximum(:executed_at)
      if last_execution.nil? || last_execution < 24.hours.ago
        unhealthy << {
          id: server.id,
          name: server.name,
          status: 'error',
          issue: last_execution ? "No activity since #{last_execution.strftime('%m/%d/%Y %H:%M')}" : "No recorded activity"
        }
      end
    end
    
    unhealthy.first(10) # Limit to 10 most critical
  end

  def get_recent_activity(limit = 50)
    return [] unless McpAuditLog.exists?
    
    McpAuditLog.includes(:user, :mcp_server)
               .order(executed_at: :desc)
               .limit(limit)
               .map do |log|
      {
        timestamp: log.executed_at,
        server_name: log.mcp_server&.name || 'Unknown Server',
        tool_name: log.tool_name,
        user_email: log.user&.email || 'Unknown User',
        status: log.status,
        response_time: log.response_time_ms || 0
      }
    end
  end
  
  def build_auth_headers(server)
    headers = {}
    
    case server.auth_type
    when 'api_key'
      headers['Authorization'] = "Bearer #{server.credentials['api_key']}"
    when 'basic'
      headers['Authorization'] = "Basic #{Base64.encode64("#{server.credentials['username']}:#{server.credentials['password']}").strip}"
    when 'custom'
      headers.merge!(server.credentials['headers'] || {})
    end
    
    headers
  end
end
