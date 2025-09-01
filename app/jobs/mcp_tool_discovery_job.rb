class McpToolDiscoveryJob < ApplicationJob
  queue_as :default
  
  # Rate limiting: don't run discovery more than once per minute per server
  DISCOVERY_COOLDOWN = 1.minute
  MAX_RETRIES = 3
  RETRY_DELAY = 30.seconds

  retry_on McpConnection::Base::ConnectionError, 
           McpConnection::Base::TimeoutError,
           wait: RETRY_DELAY,
           attempts: MAX_RETRIES

  retry_on McpConnection::Base::RateLimitError,
           wait: :exponentially_longer,
           attempts: MAX_RETRIES

  discard_on McpConnection::Base::AuthenticationError,
             McpConnection::Base::ProtocolError

  def perform(server_id, force: false)
    @server = McpServer.find(server_id)
    
    Rails.logger.info "[MCP Discovery] Starting tool discovery for server #{@server.name} (#{server_id})"
    
    # Check cooldown unless forced
    unless force || discovery_allowed?
      Rails.logger.debug "[MCP Discovery] Skipping discovery for #{@server.name} - cooldown in effect"
      return
    end
    
    # Only discover tools for active servers
    unless @server.active?
      Rails.logger.debug "[MCP Discovery] Skipping discovery for #{@server.name} - server not active"
      return
    end
    
    # Discover tools
    tools = discover_tools_with_instrumentation
    
    # Update cache
    cache_discovered_tools(tools)
    
    # Update server status if successful
    update_server_status(tools.any?)
    
    # Schedule next discovery
    schedule_next_discovery unless force
    
    # Broadcast tool updates
    broadcast_tool_updates(tools)
    
    Rails.logger.info "[MCP Discovery] Completed discovery for #{@server.name}: #{tools.size} tools found"
    
    tools
  rescue => e
    handle_discovery_error(e)
    raise
  end

  # Class methods for scheduling
  def self.discover_all_servers(force: false)
    McpServer.active.find_each do |server|
      perform_later(server.id, force: force)
    end
  end

  def self.discover_server(server, force: false)
    perform_later(server.id, force: force)
  end

  def self.schedule_periodic_discovery
    # Schedule discovery for all active servers every 5 minutes
    McpServer.active.find_each do |server|
      perform_later(server.id, force: false)
    end
  end

  private

  def discovery_allowed?
    last_discovery_key = "mcp_discovery_last_#{@server.id}"
    last_discovery = Rails.cache.read(last_discovery_key)
    
    return true if last_discovery.nil?
    
    Time.current - last_discovery > DISCOVERY_COOLDOWN
  end

  def discover_tools_with_instrumentation
    McpInstrumentation.instance.instrument_tool_discovery(@server.id) do
      client = McpClient.new(@server)
      tools = client.discover_tools
      
      # Validate tools
      validated_tools = validate_discovered_tools(tools)
      
      Rails.logger.debug "[MCP Discovery] Validated #{validated_tools.size}/#{tools.size} tools for #{@server.name}"
      
      validated_tools
    end
  end

  def validate_discovered_tools(tools)
    return [] unless tools.is_a?(Array)
    
    validated = []
    
    tools.each do |tool|
      if valid_tool_definition?(tool)
        validated << normalize_tool_definition(tool)
      else
        Rails.logger.warn "[MCP Discovery] Invalid tool definition skipped: #{tool.inspect}"
      end
    end
    
    validated
  end

  def valid_tool_definition?(tool)
    return false unless tool.is_a?(Hash)
    return false unless tool['name'].present?
    return false unless tool['description'].present?
    
    # Validate schema if present
    if tool['inputSchema'].present?
      return false unless tool['inputSchema'].is_a?(Hash)
      return false unless tool['inputSchema']['type'] == 'object'
    end
    
    true
  end

  def normalize_tool_definition(tool)
    normalized = {
      'name' => tool['name'].to_s.strip,
      'description' => tool['description'].to_s.strip,
      'inputSchema' => tool['inputSchema'] || {},
      'outputSchema' => tool['outputSchema'] || {}
    }
    
    # Add server metadata
    normalized['_server_id'] = @server.id
    normalized['_server_name'] = @server.name
    normalized['_discovered_at'] = Time.current.iso8601
    normalized['_version'] = tool['version'] || '1.0'
    
    normalized
  end

  def cache_discovered_tools(tools)
    cache_key = "mcp_server_#{@server.id}_tools"
    cache_version_key = "mcp_server_#{@server.id}_tools_version"
    last_discovery_key = "mcp_discovery_last_#{@server.id}"
    
    # Cache tools for 5 minutes (matches server model cache)
    Rails.cache.write(cache_key, tools, expires_in: 5.minutes)
    
    # Track discovery time
    Rails.cache.write(last_discovery_key, Time.current, expires_in: 1.hour)
    
    # Increment version for cache invalidation
    version = Rails.cache.read(cache_version_key) || 0
    Rails.cache.write(cache_version_key, version + 1, expires_in: 1.hour)
    
    # Store in registry
    registry = McpToolRegistry.instance
    registry.register_server_tools(@server.id, tools)
  end

  def update_server_status(tools_found)
    if tools_found
      @server.update(status: :active) unless @server.active?
    else
      Rails.logger.warn "[MCP Discovery] No tools found for #{@server.name} - this might indicate an issue"
    end
  end

  def schedule_next_discovery
    # Schedule next discovery in 5 minutes
    self.class.set(wait: 5.minutes).perform_later(@server.id, force: false)
  end

  def broadcast_tool_updates(tools)
    # Broadcast to any listening assistants or UI components
    ActionCable.server.broadcast(
      "mcp_tools_#{@server.id}",
      {
        type: 'tools_updated',
        server_id: @server.id,
        server_name: @server.name,
        tool_count: tools.size,
        tools: tools.map { |t| t.slice('name', 'description') },
        timestamp: Time.current.iso8601
      }
    )
    
    # Also broadcast to global MCP channel
    ActionCable.server.broadcast(
      'mcp_updates',
      {
        type: 'server_tools_updated',
        server_id: @server.id,
        server_name: @server.name,
        tool_count: tools.size,
        timestamp: Time.current.iso8601
      }
    )
  end

  def handle_discovery_error(error)
    Rails.logger.error "[MCP Discovery] Error discovering tools for #{@server.name}: #{error.message}"
    
    # Update server status on certain errors
    case error
    when McpConnection::Base::AuthenticationError
      @server.update(status: :error)
      Rails.logger.error "[MCP Discovery] Authentication failed for #{@server.name} - marking as error"
    when McpConnection::Base::ConnectionError
      # Don't immediately mark as error - might be temporary
      Rails.logger.warn "[MCP Discovery] Connection failed for #{@server.name} - will retry"
    end
    
    # Clear cached tools on error
    cache_key = "mcp_server_#{@server.id}_tools"
    Rails.cache.delete(cache_key)
    
    # Handle error through error handler
    McpErrorHandler.instance.handle_error(error, {
      server_id: @server.id,
      server_name: @server.name,
      context: 'tool_discovery_job',
      job_id: job_id,
      attempt: executions
    })
  end
end