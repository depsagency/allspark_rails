class McpConnectionManager
  include Singleton

  DEFAULT_POOL_SIZE = 10
  IDLE_TIMEOUT = 30.minutes
  HEALTH_CHECK_INTERVAL = 5.minutes

  def initialize
    @connections = Concurrent::Map.new
    @pool_sizes = Concurrent::Map.new
    @last_used = Concurrent::Map.new
    @health_status = Concurrent::Map.new
    @mutex = Mutex.new
    
    start_cleanup_thread
    start_health_check_thread
  end

  def connection_for(mcp_server, user = nil)
    key = connection_key(mcp_server, user)
    
    @mutex.synchronize do
      connection = get_or_create_connection(key, mcp_server)
      @last_used[key] = Time.current
      connection
    end
  end

  def release_connection(mcp_server, user = nil)
    key = connection_key(mcp_server, user)
    
    @mutex.synchronize do
      connection = @connections[key]
      if connection
        connection.disconnect if connection.respond_to?(:disconnect)
        @connections.delete(key)
        @last_used.delete(key)
        @health_status.delete(key)
      end
    end
  end

  def pool_status
    @mutex.synchronize do
      {
        total_connections: @connections.size,
        connections: @connections.keys.map do |key|
          {
            key: key,
            last_used: @last_used[key],
            healthy: @health_status[key] || false,
            idle_time: Time.current - (@last_used[key] || Time.current)
          }
        end,
        pool_sizes: @pool_sizes.each_pair.to_h
      }
    end
  end

  def health_status(mcp_server, user = nil)
    server_id = mcp_server.is_a?(McpServer) ? mcp_server.id : mcp_server
    
    # Check cache first
    health_cache_key = "mcp_health_status_#{server_id}"
    cached_status = Rails.cache.read(health_cache_key)
    return cached_status unless cached_status.nil?
    
    # Fall back to internal tracking
    key = connection_key(mcp_server, user)
    @health_status[key] || false
  end

  def update_health_status(server_id, healthy)
    @mutex.synchronize do
      # Update internal tracking for all connections to this server
      @health_status.keys.each do |key|
        if key.include?("server_#{server_id}")
          @health_status[key] = healthy
        end
      end
      
      # Update cache
      health_cache_key = "mcp_health_status_#{server_id}"
      Rails.cache.write(health_cache_key, healthy, expires_in: 10.minutes)
    end
  end

  def clear_all_connections
    @mutex.synchronize do
      @connections.each_value do |connection|
        begin
          connection.disconnect if connection.respond_to?(:disconnect)
        rescue => e
          Rails.logger.warn "[MCP] Error disconnecting connection: #{e.message}"
        end
      end
      
      @connections.clear
      @last_used.clear
      @health_status.clear
      @pool_sizes.clear
    end
  end

  def configure_pool_size(mcp_server, size)
    key = connection_key(mcp_server)
    @pool_sizes[key] = size.to_i
  end

  def pool_size_for(mcp_server)
    key = connection_key(mcp_server)
    @pool_sizes[key] || DEFAULT_POOL_SIZE
  end

  # Statistics and monitoring
  def connection_stats
    @mutex.synchronize do
      active_connections = @connections.size
      healthy_connections = @health_status.values.count(true)
      idle_connections = @last_used.values.count { |time| time < (Time.current - 5.minutes) }
      
      {
        active: active_connections,
        healthy: healthy_connections,
        idle: idle_connections,
        unhealthy: active_connections - healthy_connections,
        total_pools: @pool_sizes.size,
        memory_usage: calculate_memory_usage
      }
    end
  end

  def cleanup_connections(force: false)
    @mutex.synchronize do
      expired_keys = []
      
      @last_used.each do |key, last_used_time|
        if force || (last_used_time < (Time.current - IDLE_TIMEOUT))
          expired_keys << key
        end
      end
      
      expired_keys.each do |key|
        connection = @connections[key]
        if connection
          begin
            connection.disconnect if connection.respond_to?(:disconnect)
          rescue => e
            Rails.logger.warn "[MCP] Error disconnecting expired connection #{key}: #{e.message}"
          end
        end
        
        @connections.delete(key)
        @last_used.delete(key)
        @health_status.delete(key)
      end
      
      Rails.logger.info "[MCP] Cleaned up #{expired_keys.size} expired connections" if expired_keys.any?
      expired_keys.size
    end
  end

  def shutdown
    Rails.logger.info "[MCP] Shutting down connection manager"
    
    @cleanup_thread&.kill
    @health_check_thread&.kill
    
    clear_all_connections
  end

  private

  def connection_key(mcp_server, user = nil)
    if user
      "server_#{mcp_server.id}_user_#{user.id}"
    else
      "server_#{mcp_server.id}"
    end
  end

  def get_or_create_connection(key, mcp_server)
    connection = @connections[key]
    
    if connection.nil?
      connection = create_connection(mcp_server)
      @connections[key] = connection
      @last_used[key] = Time.current
    end
    
    connection
  end

  def create_connection(mcp_server)
    # Determine the connection class based on transport type
    connection_class = case mcp_server.transport_type
    when 'sse'
      McpConnection::SseConnection
    when 'websocket'
      # TODO: Implement WebSocket connection when needed
      raise NotImplementedError, "WebSocket transport not yet implemented"
    else # 'http' or nil (default)
      # For HTTP transport, use auth-specific connection classes
      case mcp_server.auth_type
      when 'api_key'
        McpConnection::ApiKeyConnection
      when 'oauth'
        McpConnection::OauthConnection
      when 'bearer_token'
        McpConnection::BearerTokenConnection
      when 'basic'
        McpConnection::BasicConnection
      when 'no_auth'
        McpConnection::BasicConnection # Use basic connection for no-auth
      else
        raise ArgumentError, "Unsupported auth type: #{mcp_server.auth_type}"
      end
    end
    
    # Create the connection instance
    connection_class.new(mcp_server)
  rescue => e
    Rails.logger.error "[MCP] Failed to create connection for server #{mcp_server.id}: #{e.message}"
    raise
  end

  def start_cleanup_thread
    @cleanup_thread = Thread.new do
      loop do
        begin
          sleep 60 # Run cleanup every minute
          cleanup_connections
        rescue => e
          Rails.logger.error "[MCP] Connection cleanup thread error: #{e.message}"
        end
      end
    end
    
    @cleanup_thread.name = "mcp-connection-cleanup"
  end

  def start_health_check_thread
    @health_check_thread = Thread.new do
      loop do
        begin
          sleep HEALTH_CHECK_INTERVAL
          perform_health_checks
        rescue => e
          Rails.logger.error "[MCP] Health check thread error: #{e.message}"
        end
      end
    end
    
    @health_check_thread.name = "mcp-health-check"
  end

  def perform_health_checks
    # Use the dedicated health check job instead of inline checks
    McpHealthCheckJob.perform_later
  end

  def schedule_periodic_health_checks
    # Schedule periodic health checks
    McpHealthCheckJob.schedule_periodic_checks
  end

  def calculate_memory_usage
    # Rough estimate of memory usage
    connection_count = @connections.size
    metadata_count = @last_used.size + @health_status.size + @pool_sizes.size
    
    # Assume each connection uses ~1KB and metadata uses ~100 bytes per entry
    (connection_count * 1024) + (metadata_count * 100)
  end
end

# Ensure cleanup on app shutdown
at_exit do
  McpConnectionManager.instance.shutdown rescue nil
end