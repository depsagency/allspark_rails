class McpConfigurationToolDiscoveryJob < ApplicationJob
  queue_as :default
  
  # Rate limiting: don't run discovery more than once per minute per configuration
  DISCOVERY_COOLDOWN = 1.minute
  MAX_RETRIES = 3
  RETRY_DELAY = 30.seconds

  retry_on StandardError,
           wait: RETRY_DELAY,
           attempts: MAX_RETRIES

  discard_on ActiveRecord::RecordNotFound

  def perform(configuration_id, force: false)
    @configuration = McpConfiguration.find(configuration_id)
    
    Rails.logger.info "[MCP Config Discovery] Starting tool discovery for configuration #{@configuration.name} (#{configuration_id})"
    
    # Check cooldown unless forced
    unless force || discovery_allowed?
      Rails.logger.debug "[MCP Config Discovery] Skipping discovery for #{@configuration.name} - cooldown in effect"
      return
    end
    
    # Only discover tools for enabled configurations
    unless @configuration.enabled?
      Rails.logger.debug "[MCP Config Discovery] Skipping discovery for #{@configuration.name} - configuration not enabled"
      return
    end
    
    # Discover tools based on configuration type
    tools = discover_tools_with_instrumentation
    
    # Update cache
    cache_discovered_tools(tools)
    
    # Update configuration metadata with discovery info
    update_configuration_metadata(tools.any?)
    
    # Schedule next discovery unless forced
    schedule_next_discovery unless force
    
    # Broadcast tool updates
    broadcast_tool_updates(tools)
    
    Rails.logger.info "[MCP Config Discovery] Completed discovery for #{@configuration.name}: #{tools.size} tools found"
    
    tools
  rescue => e
    handle_discovery_error(e)
    raise
  end

  # Class methods for scheduling
  def self.discover_all_configurations(force: false)
    McpConfiguration.active.find_each do |config|
      perform_later(config.id, force: force)
    end
  end

  def self.discover_configuration(configuration, force: false)
    perform_later(configuration.id, force: force)
  end

  def self.schedule_periodic_discovery
    # Schedule discovery for all enabled configurations every 5 minutes
    McpConfiguration.active.find_each do |config|
      perform_later(config.id, force: false)
    end
  end

  private

  def discovery_allowed?
    last_discovery_key = "mcp_config_discovery_last_#{@configuration.id}"
    last_discovery = Rails.cache.read(last_discovery_key)
    
    return true if last_discovery.nil?
    
    Time.current - last_discovery > DISCOVERY_COOLDOWN
  end

  def discover_tools_with_instrumentation
    case @configuration.server_type
    when 'stdio'
      discover_stdio_tools
    when 'http', 'sse', 'websocket'
      discover_network_tools
    else
      Rails.logger.warn "[MCP Config Discovery] Unknown server type: #{@configuration.server_type}"
      []
    end
  end

  def discover_stdio_tools
    Rails.logger.info "[MCP Config Discovery] Discovering stdio tools via bridge manager"
    
    # Use bridge manager for stdio configurations
    bridge_manager = McpBridgeManager.new
    
    # Create a user context (use system user or first admin)
    user = User.where(role: :system_admin).first || User.first
    unless user
      Rails.logger.error "[MCP Config Discovery] No user available for stdio discovery"
      return []
    end
    
    begin
      # Get tools through bridge manager
      tools = bridge_manager.discover_tools(user, @configuration.id)
      validate_discovered_tools(tools)
    rescue => e
      Rails.logger.error "[MCP Config Discovery] Failed to discover stdio tools: #{e.message}"
      []
    end
  end

  def discover_network_tools
    Rails.logger.info "[MCP Config Discovery] Discovering network tools via direct connection"
    
    begin
      # Create temporary server facade for compatibility
      server_facade = McpCompatibilityLayer.configuration_to_server(@configuration)
      client = McpClient.new(server_facade)
      
      # Discover tools via client
      tools = client.discover_tools
      validate_discovered_tools(tools)
    rescue => e
      Rails.logger.error "[MCP Config Discovery] Failed to discover network tools: #{e.message}"
      []
    end
  end

  def validate_discovered_tools(tools)
    return [] unless tools.is_a?(Array)
    
    validated = []
    
    tools.each do |tool|
      if valid_tool_definition?(tool)
        validated << normalize_tool_definition(tool)
      else
        Rails.logger.warn "[MCP Config Discovery] Invalid tool definition skipped: #{tool.inspect}"
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
    
    # Add configuration metadata
    normalized['_configuration_id'] = @configuration.id
    normalized['_configuration_name'] = @configuration.name
    normalized['_discovered_at'] = Time.current.iso8601
    normalized['_version'] = tool['version'] || '1.0'
    normalized['_server_type'] = @configuration.server_type
    
    normalized
  end

  def cache_discovered_tools(tools)
    cache_key = "mcp_configuration_#{@configuration.id}_tools"
    cache_version_key = "mcp_configuration_#{@configuration.id}_tools_version"
    last_discovery_key = "mcp_config_discovery_last_#{@configuration.id}"
    
    # Cache tools for 5 minutes
    Rails.cache.write(cache_key, tools, expires_in: 5.minutes)
    
    # Track discovery time
    Rails.cache.write(last_discovery_key, Time.current, expires_in: 1.hour)
    
    # Increment version for cache invalidation
    version = Rails.cache.read(cache_version_key) || 0
    Rails.cache.write(cache_version_key, version + 1, expires_in: 1.hour)
    
    # Store in registry if available (disabled for now to avoid deadlock)
    # if defined?(McpToolRegistry)
    #   registry = McpToolRegistry.instance
    #   registry.register_configuration_tools(@configuration.id, tools)
    # end
  end

  def update_configuration_metadata(tools_found)
    metadata = @configuration.metadata || {}
    metadata['last_tool_discovery'] = {
      'timestamp' => Time.current.iso8601,
      'tools_found' => tools_found,
      'discovery_successful' => tools_found
    }
    
    @configuration.update(metadata: metadata)
  end

  def schedule_next_discovery
    # Schedule next discovery in 5 minutes
    self.class.set(wait: 5.minutes).perform_later(@configuration.id, force: false)
  end

  def broadcast_tool_updates(tools)
    # Broadcast to any listening assistants or UI components
    ActionCable.server.broadcast(
      "mcp_configuration_tools_#{@configuration.id}",
      {
        type: 'tools_updated',
        configuration_id: @configuration.id,
        configuration_name: @configuration.name,
        tool_count: tools.size,
        tools: tools.map { |t| t.slice('name', 'description') },
        timestamp: Time.current.iso8601
      }
    )
    
    # Also broadcast to global MCP channel
    ActionCable.server.broadcast(
      'mcp_configuration_updates',
      {
        type: 'configuration_tools_updated',
        configuration_id: @configuration.id,
        configuration_name: @configuration.name,
        tool_count: tools.size,
        timestamp: Time.current.iso8601
      }
    )
  end

  def handle_discovery_error(error)
    Rails.logger.error "[MCP Config Discovery] Error discovering tools for #{@configuration.name}: #{error.message}"
    
    # Update configuration metadata with error info
    metadata = @configuration.metadata || {}
    metadata['last_tool_discovery'] = {
      'timestamp' => Time.current.iso8601,
      'tools_found' => false,
      'discovery_successful' => false,
      'error' => error.message
    }
    
    @configuration.update(metadata: metadata)
    
    # Clear cached tools on error
    cache_key = "mcp_configuration_#{@configuration.id}_tools"
    Rails.cache.delete(cache_key)
  end
end