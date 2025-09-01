# frozen_string_literal: true

# AllSpark monitoring configuration
# This integrates the target application with AllSpark Builder for real-time monitoring

if defined?(AllSpark) && !AllSpark.instance_variable_get(:@configured)
  AllSpark.instance_variable_set(:@configured, true)
  AllSpark.configure do |config|
    # Enable monitoring (can be disabled in production if needed)
    config.enabled = ENV.fetch('ALLSPARK_ENABLED', 'true') == 'true'
    
    # AllSpark Builder URL - defaults to local development
    config.builder_url = ENV.fetch('ALLSPARK_BUILDER_URL', 'https://builder.localhost')
    
    # Instance API key - will be provided by AllSpark Builder
    config.api_key = ENV.fetch('ALLSPARK_INSTANCE_API_KEY', nil)
    
    # Context parameters for correlation
    config.app_project_id = ENV.fetch('ALLSPARK_APP_PROJECT_ID', nil)
    config.build_session_id = ENV.fetch('ALLSPARK_BUILD_SESSION_ID', nil)
    
    # Monitoring levels - DISABLE CONSOLE MONITORING TO PREVENT LOGGER RECURSION
    config.console_monitoring = false
    config.network_monitoring = true
    config.performance_monitoring = true
    config.error_monitoring = true
    config.dom_monitoring = true
    
    # Security settings
    config.sanitize_data = true
    
    # Development-specific settings
    if Rails.env.development?
      config.audit_logging = true
      config.enable_console_api = true
      config.enable_file_operations = true
      config.enable_database_introspection = true
    else
      config.audit_logging = false
      config.enable_console_api = false
      config.enable_file_operations = false
      config.enable_database_introspection = false
    end
  end
  
  
  puts "[AllSpark] Error monitoring enabled"
  puts "[AllSpark] Builder URL: #{AllSpark.configuration.builder_url}"
  puts "[AllSpark] API Key: #{AllSpark.configuration.api_key ? 'configured' : 'not configured'}"
end