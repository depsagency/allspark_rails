# frozen_string_literal: true

# MCP Production Configuration
Rails.application.configure do
  # MCP-specific configuration namespace
  config.mcp = ActiveSupport::OrderedOptions.new
  
  # Connection settings
  config.mcp.connection_pool_size = ENV.fetch('MCP_CONNECTION_POOL_SIZE', 10).to_i
  config.mcp.connection_timeout = ENV.fetch('MCP_CONNECTION_TIMEOUT', 30).to_i
  config.mcp.max_retries = ENV.fetch('MCP_MAX_RETRIES', 3).to_i
  config.mcp.retry_delay = ENV.fetch('MCP_RETRY_DELAY', 1).to_f
  
  # Health check settings
  config.mcp.health_check_interval = ENV.fetch('MCP_HEALTH_CHECK_INTERVAL', 300).to_i # 5 minutes
  config.mcp.health_check_timeout = ENV.fetch('MCP_HEALTH_CHECK_TIMEOUT', 10).to_i
  config.mcp.consecutive_failure_threshold = ENV.fetch('MCP_FAILURE_THRESHOLD', 3).to_i
  
  # Tool discovery settings
  config.mcp.tool_discovery_interval = ENV.fetch('MCP_TOOL_DISCOVERY_INTERVAL', 3600).to_i # 1 hour
  config.mcp.tool_cache_ttl = ENV.fetch('MCP_TOOL_CACHE_TTL', 1800).to_i # 30 minutes
  config.mcp.enable_tool_caching = ENV.fetch('MCP_ENABLE_TOOL_CACHING', 'true') == 'true'
  
  # Audit and cleanup settings
  config.mcp.audit_log_retention_days = ENV.fetch('MCP_AUDIT_RETENTION_DAYS', 90).to_i
  config.mcp.cleanup_batch_size = ENV.fetch('MCP_CLEANUP_BATCH_SIZE', 1000).to_i
  config.mcp.enable_automatic_cleanup = ENV.fetch('MCP_ENABLE_AUTO_CLEANUP', 'true') == 'true'
  
  # Performance monitoring
  config.mcp.enable_instrumentation = ENV.fetch('MCP_ENABLE_INSTRUMENTATION', 'true') == 'true'
  config.mcp.slow_query_threshold = ENV.fetch('MCP_SLOW_QUERY_THRESHOLD', 5000).to_i # 5 seconds
  config.mcp.enable_metrics_collection = ENV.fetch('MCP_ENABLE_METRICS', 'true') == 'true'
  
  # Security settings
  config.mcp.enable_encryption = ENV.fetch('MCP_ENABLE_ENCRYPTION', 'true') == 'true'
  config.mcp.credential_encryption_key = ENV['MCP_CREDENTIAL_ENCRYPTION_KEY']
  config.mcp.oauth_state_ttl = ENV.fetch('MCP_OAUTH_STATE_TTL', 600).to_i # 10 minutes
  
  # Rate limiting (when enabled)
  config.mcp.enable_rate_limiting = ENV.fetch('MCP_ENABLE_RATE_LIMITING', 'false') == 'true'
  config.mcp.user_rate_limits = {
    per_second: ENV.fetch('MCP_USER_RATE_PER_SECOND', 5).to_i,
    per_minute: ENV.fetch('MCP_USER_RATE_PER_MINUTE', 50).to_i,
    per_hour: ENV.fetch('MCP_USER_RATE_PER_HOUR', 500).to_i,
    per_day: ENV.fetch('MCP_USER_RATE_PER_DAY', 2000).to_i
  }
  
  config.mcp.global_rate_limits = {
    per_second: ENV.fetch('MCP_GLOBAL_RATE_PER_SECOND', 100).to_i,
    per_minute: ENV.fetch('MCP_GLOBAL_RATE_PER_MINUTE', 1000).to_i,
    per_hour: ENV.fetch('MCP_GLOBAL_RATE_PER_HOUR', 10000).to_i,
    per_day: ENV.fetch('MCP_GLOBAL_RATE_PER_DAY', 50000).to_i
  }
  
  # Error handling
  config.mcp.error_notification_webhook = ENV['MCP_ERROR_WEBHOOK_URL']
  config.mcp.critical_error_threshold = ENV.fetch('MCP_CRITICAL_ERROR_THRESHOLD', 10).to_i
  config.mcp.error_alert_interval = ENV.fetch('MCP_ERROR_ALERT_INTERVAL', 300).to_i # 5 minutes
  
  # Feature flags
  config.mcp.enable_oauth_support = ENV.fetch('MCP_ENABLE_OAUTH', 'true') == 'true'
  config.mcp.enable_multi_tenant = ENV.fetch('MCP_ENABLE_MULTI_TENANT', 'true') == 'true'
  config.mcp.enable_personal_servers = ENV.fetch('MCP_ENABLE_PERSONAL_SERVERS', 'true') == 'true'
  
  # Development and debugging
  config.mcp.enable_debug_logging = ENV.fetch('MCP_DEBUG_LOGGING', Rails.env.development?).to_s == 'true'
  config.mcp.log_request_bodies = ENV.fetch('MCP_LOG_REQUEST_BODIES', 'false') == 'true'
  config.mcp.log_response_bodies = ENV.fetch('MCP_LOG_RESPONSE_BODIES', 'false') == 'true'
end

# Initialize MCP subsystems after configuration
# Only run during server startup, not asset precompilation
Rails.application.config.after_initialize do
  # Skip initialization during asset precompilation
  next if defined?(Rails::Server).nil? && !Rails.env.test?
  
  begin
    # Start automatic cleanup if enabled
    if Rails.application.config.mcp.enable_automatic_cleanup
      McpAuditLogCleanupJob.start_cleanup_cycle(
        retention_days: Rails.application.config.mcp.audit_log_retention_days,
        batch_size: Rails.application.config.mcp.cleanup_batch_size
      )
    end
    
    # Initialize connection manager
    McpConnectionManager.instance
    
    # Initialize tool registry
    McpToolRegistry.instance
    
    # Initialize error handler
    McpErrorHandler.instance
    
    Rails.logger.info "[MCP] Production configuration initialized successfully"
  rescue => e
    Rails.logger.error "[MCP] Failed to initialize MCP subsystems: #{e.message}"
  end
end