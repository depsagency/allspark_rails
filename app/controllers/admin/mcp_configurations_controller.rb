# frozen_string_literal: true

class Admin::McpConfigurationsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :set_mcp_configuration, only: [:show, :edit, :update, :destroy, :test_connection, :discover_tools, :monitoring]

  # GET /admin/mcp_configurations
  def index
    @mcp_configurations = McpConfiguration.includes(:owner)

    # Apply search filter if present
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @mcp_configurations = @mcp_configurations.where(
        "name ILIKE ?", search_term
      )
    end

    # Apply status filter if present
    if params[:enabled].present?
      @mcp_configurations = @mcp_configurations.where(enabled: params[:enabled] == 'true')
    end

    # Apply server type filter if present
    if params[:server_type].present?
      @mcp_configurations = @mcp_configurations.where(server_type: params[:server_type])
    end

    @mcp_configurations = @mcp_configurations.page(params[:page]).per(20)

    # Get health statistics using new analytics service
    analytics_service = McpAnalyticsService.new
    @health_stats = analytics_service.health_statistics

    respond_to do |format|
      format.html
      format.json { render json: @mcp_configurations }
    end
  end

  # GET /admin/mcp_configurations/1
  def show
    analytics_service = McpAnalyticsService.new
    @analytics = analytics_service.configuration_analytics(@mcp_configuration.id)
    @audit_logs = @mcp_configuration.mcp_audit_logs.includes(:user).order(executed_at: :desc).limit(10)
    
    # Get cached tools for this configuration
    @cached_tools = get_cached_tools(@mcp_configuration)
    @last_tool_discovery = get_last_tool_discovery(@mcp_configuration)
  end

  # GET /admin/mcp_configurations/new
  def new
    @mcp_configuration = McpConfiguration.new
    @templates = McpTemplate.all.order(:name)
  end

  # POST /admin/mcp_configurations
  def create
    @mcp_configuration = McpConfiguration.new(mcp_configuration_params)
    
    # Set owner to admin user (system-wide configuration)
    @mcp_configuration.owner = current_user

    if @mcp_configuration.save
      # Test connection immediately after creation for supported types
      if %w[http sse websocket].include?(@mcp_configuration.server_type)
        test_result = test_configuration_connection(@mcp_configuration)
        
        if test_result[:success]
          redirect_to admin_mcp_configuration_path(@mcp_configuration), 
                     notice: 'MCP configuration was successfully created and connection test passed.'
        else
          flash[:warning] = "MCP configuration was created but connection test failed: #{test_result[:error]}"
          redirect_to admin_mcp_configuration_path(@mcp_configuration)
        end
      else
        # For stdio configurations, schedule tool discovery via bridge
        schedule_bridge_tool_discovery(@mcp_configuration)
        redirect_to admin_mcp_configuration_path(@mcp_configuration), 
                   notice: 'MCP configuration was successfully created. Tool discovery scheduled.'
      end
    else
      @templates = McpTemplate.all.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  # GET /admin/mcp_configurations/1/edit
  def edit
    @templates = McpTemplate.all.order(:name)
  end

  # PATCH/PUT /admin/mcp_configurations/1
  def update
    old_server_config = @mcp_configuration.server_config.dup
    
    if @mcp_configuration.update(mcp_configuration_params)
      # Test connection after update if server config changed
      if server_config_changed?(old_server_config)
        if %w[http sse websocket].include?(@mcp_configuration.server_type)
          test_result = test_configuration_connection(@mcp_configuration)
          
          if test_result[:success]
            redirect_to admin_mcp_configuration_path(@mcp_configuration), 
                       notice: 'MCP configuration was successfully updated.'
          else
            flash[:warning] = "MCP configuration was updated but connection test failed: #{test_result[:error]}"
            redirect_to admin_mcp_configuration_path(@mcp_configuration)
          end
        else
          # For stdio configurations, re-discover tools
          schedule_bridge_tool_discovery(@mcp_configuration, force: true)
          redirect_to admin_mcp_configuration_path(@mcp_configuration), 
                     notice: 'MCP configuration was successfully updated. Tool discovery scheduled.'
        end
      else
        redirect_to admin_mcp_configuration_path(@mcp_configuration), 
                   notice: 'MCP configuration was successfully updated.'
      end
    else
      @templates = McpTemplate.all.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/mcp_configurations/1
  def destroy
    config_name = @mcp_configuration.name
    
    # Clean up any active bridge connections for stdio configs
    if @mcp_configuration.server_type == 'stdio'
      cleanup_bridge_connections(@mcp_configuration)
    end

    if @mcp_configuration.destroy
      redirect_to admin_mcp_configurations_path, 
                 notice: "MCP configuration '#{config_name}' was successfully deleted."
    else
      redirect_to admin_mcp_configuration_path(@mcp_configuration), 
                 alert: 'Failed to delete MCP configuration.'
    end
  end

  # POST /admin/mcp_configurations/1/test_connection
  def test_connection
    result = test_configuration_connection(@mcp_configuration)
    
    respond_to do |format|
      format.json { render json: result }
      format.html do
        if result[:success]
          redirect_to admin_mcp_configuration_path(@mcp_configuration), 
                     notice: 'Connection test successful!'
        else
          redirect_to admin_mcp_configuration_path(@mcp_configuration), 
                     alert: "Connection test failed: #{result[:error]}"
        end
      end
    end
  end

  # POST /admin/mcp_configurations/1/discover_tools
  # GET /admin/mcp_configurations/1/discover_tools (handles erroneous GET requests)
  def discover_tools
    # Handle GET requests by redirecting with instruction
    if request.get?
      redirect_to admin_mcp_configuration_path(@mcp_configuration), 
                 alert: 'Tool discovery must be triggered via POST request. Use the "Discover Tools" button below.'
      return
    end
    
    begin
      if @mcp_configuration.server_type == 'stdio'
        # Use bridge manager for stdio configurations
        schedule_bridge_tool_discovery(@mcp_configuration, force: true)
        message = 'Tool discovery started via bridge manager'
      else
        # Use direct connection for network configurations
        # This would need to be implemented for network-based configs
        message = 'Tool discovery started'
      end
      
      respond_to do |format|
        format.json { render json: { success: true, message: message } }
        format.html do
          redirect_to admin_mcp_configuration_path(@mcp_configuration), 
                     notice: 'Tool discovery has been started in the background. Refresh this page in a few moments to see discovered tools.'
        end
      end
    rescue => e
      respond_to do |format|
        format.json { render json: { success: false, error: e.message } }
        format.html do
          redirect_to admin_mcp_configuration_path(@mcp_configuration), 
                     alert: "Failed to start tool discovery: #{e.message}"
        end
      end
    end
  end

  # GET /admin/mcp_configurations/1/monitoring
  def monitoring
    analytics_service = McpAnalyticsService.new
    @analytics = analytics_service.configuration_analytics(@mcp_configuration.id)
    
    respond_to do |format|
      format.html
      format.json { render json: @analytics }
    end
  end

  # GET /admin/mcp_configurations/analytics
  def analytics
    timeframe = params[:timeframe] || 'last_7_days'
    analytics_service = McpAnalyticsService.new(timeframe: timeframe)
    @analytics = analytics_service.global_analytics
    
    respond_to do |format|
      format.html
      format.json { render json: @analytics }
    end
  end

  # POST /admin/mcp_configurations/bulk_action
  def bulk_action
    config_ids = params[:config_ids] || []
    action = params[:bulk_action]
    
    return redirect_to admin_mcp_configurations_path, alert: 'No configurations selected' if config_ids.empty?
    
    configurations = McpConfiguration.where(id: config_ids)
    results = { success: 0, failed: 0, errors: [] }
    
    case action
    when 'enable'
      configurations.each do |config|
        if config.update(enabled: true)
          results[:success] += 1
        else
          results[:failed] += 1
          results[:errors] << "#{config.name}: #{config.errors.full_messages.join(', ')}"
        end
      end
      
    when 'disable'
      configurations.each do |config|
        if config.update(enabled: false)
          results[:success] += 1
        else
          results[:failed] += 1
          results[:errors] << "#{config.name}: #{config.errors.full_messages.join(', ')}"
        end
      end
      
    when 'test_connections'
      configurations.each do |config|
        test_result = test_configuration_connection(config)
        if test_result[:success]
          results[:success] += 1
        else
          results[:failed] += 1
          results[:errors] << "#{config.name}: #{test_result[:error]}"
        end
      end
      
    when 'discover_tools'
      configurations.each do |config|
        begin
          if config.server_type == 'stdio'
            schedule_bridge_tool_discovery(config, force: true)
          end
          results[:success] += 1
        rescue => e
          results[:failed] += 1
          results[:errors] << "#{config.name}: #{e.message}"
        end
      end
      
    when 'delete'
      configurations.each do |config|
        if config.destroy
          results[:success] += 1
        else
          results[:failed] += 1
          results[:errors] << "#{config.name}: #{config.errors.full_messages.join(', ')}"
        end
      end
      
    else
      return redirect_to admin_mcp_configurations_path, alert: 'Invalid bulk action'
    end
    
    if results[:failed] == 0
      redirect_to admin_mcp_configurations_path, notice: "Bulk action completed successfully for #{results[:success]} configurations."
    else
      error_message = "Bulk action completed with #{results[:failed]} failures: #{results[:errors].join('; ')}"
      redirect_to admin_mcp_configurations_path, alert: error_message
    end
  end

  private

  def set_mcp_configuration
    @mcp_configuration = McpConfiguration.find(params[:id])
  end

  def mcp_configuration_params
    # Get the basic params
    permitted = params.require(:mcp_configuration).permit(
      :name, :enabled, :server_type, :server_config, :metadata
    )
    
    # Parse JSON strings if present
    if permitted[:server_config].is_a?(String)
      begin
        permitted[:server_config] = JSON.parse(permitted[:server_config])
      rescue JSON::ParserError => e
        # Keep as string if invalid JSON, will be caught by model validation
      end
    end
    
    if permitted[:metadata].is_a?(String)
      begin
        permitted[:metadata] = JSON.parse(permitted[:metadata])
      rescue JSON::ParserError => e
        # Keep as string if invalid JSON, will be caught by model validation
      end
    end
    
    permitted
  end

  def ensure_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: 'Access denied. Admin privileges required.'
    end
  end

  def test_configuration_connection(configuration)
    begin
      case configuration.server_type
      when 'http', 'sse', 'websocket'
        # Create temporary server facade for testing
        server_facade = McpCompatibilityLayer.configuration_to_server(configuration)
        client = McpClient.new(server_facade)
        client.test_connection
        { success: true }
      when 'stdio'
        # For stdio, test via bridge manager
        bridge_manager = McpBridgeManager.new
        # This would need a test method in the bridge manager
        { success: true, message: 'Bridge connection test not implemented yet' }
      else
        { success: false, error: "Unknown server type: #{configuration.server_type}" }
      end
    rescue => e
      Rails.logger.error "[Admin] Connection test failed for configuration #{configuration.id}: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def server_config_changed?(old_config)
    @mcp_configuration.server_config != old_config
  end

  def schedule_bridge_tool_discovery(configuration, force: false)
    # Schedule tool discovery via the new job
    McpConfigurationToolDiscoveryJob.perform_later(configuration.id, force: force)
    Rails.logger.info "[Admin] Tool discovery scheduled for configuration #{configuration.id} (force: #{force})"
  end

  def cleanup_bridge_connections(configuration)
    # Clean up any active bridge connections
    Rails.logger.info "[Admin] Cleaning up bridge connections for configuration #{configuration.id}"
  end

  def get_cached_tools(configuration)
    cache_key = "mcp_configuration_#{configuration.id}_tools"
    Rails.cache.read(cache_key) || []
  end

  def get_last_tool_discovery(configuration)
    metadata = configuration.metadata || {}
    discovery_info = metadata['last_tool_discovery']
    
    if discovery_info
      {
        timestamp: discovery_info['timestamp'],
        successful: discovery_info['discovery_successful'],
        tools_found: discovery_info['tools_found'],
        error: discovery_info['error']
      }
    else
      nil
    end
  end
end