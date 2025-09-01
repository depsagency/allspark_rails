# app/services/mcp_server_migrator.rb
class McpServerMigrator
  attr_reader :server, :errors
  
  def initialize(server)
    @server = server
    @errors = []
  end
  
  def migrate!
    ActiveRecord::Base.transaction do
      configuration = build_configuration
      
      if configuration.save
        # Update server to indicate migration
        server.update_column(:migrated_at, Time.current) if server.respond_to?(:migrated_at)
        configuration
      else
        @errors = configuration.errors.full_messages
        raise ActiveRecord::Rollback, "Configuration validation failed: #{@errors.join(', ')}"
      end
    end
  end
  
  def can_migrate?
    validate_migration
    @errors.empty?
  end
  
  private
  
  def build_configuration
    McpConfiguration.new(
      owner: determine_owner,
      name: server.name,
      server_type: map_server_type,
      enabled: server.enabled,
      server_config: build_server_config,
      metadata: build_metadata
    )
  end
  
  def determine_owner
    # If server has polymorphic owner, use it
    if server.owner_type.present? && server.owner_id.present?
      server.owner_type.constantize.find_by(id: server.owner_id)
    # Otherwise fall back to user
    elsif server.user_id.present?
      User.find_by(id: server.user_id)
    else
      nil
    end
  end
  
  def map_server_type
    case server.transport_type
    when 'stdio' then 'stdio'
    when 'http' then 'http'
    when 'sse' then 'sse'
    when 'websocket' then 'websocket'
    else 'http' # default to http
    end
  end
  
  def build_server_config
    config = {}
    
    case server.transport_type
    when 'stdio'
      config.merge!(build_stdio_config)
    when 'http', 'sse', 'websocket'
      config.merge!(build_network_config)
    end
    
    # Add authentication if present
    if server.auth_config.present?
      config.merge!(build_auth_config)
    end
    
    config
  end
  
  def build_stdio_config
    config = {}
    
    if server.connection_config.present?
      # Extract command - could be in different fields
      command = server.connection_config['command'] || 
                server.connection_config['path'] ||
                server.connection_config['executable']
      
      config['command'] = command if command.present?
      
      # Extract arguments
      args = server.connection_config['args'] || 
             server.connection_config['arguments'] || 
             []
      config['args'] = Array(args) if args.present?
      
      # Extract environment variables
      env = server.connection_config['env'] || 
            server.connection_config['environment'] || 
            {}
      config['env'] = env if env.present?
    end
    
    config
  end
  
  def build_network_config
    config = {}
    
    # Determine endpoint URL
    endpoint = server.url
    endpoint ||= server.connection_config['endpoint'] if server.connection_config.present?
    endpoint ||= server.connection_config['url'] if server.connection_config.present?
    
    if endpoint.present?
      # Use appropriate key based on server type
      key = server.transport_type == 'http' ? 'endpoint' : 'url'
      config[key] = endpoint
    end
    
    # Add any connection-specific headers
    if server.connection_config&.dig('headers').present?
      config['headers'] ||= {}
      config['headers'].merge!(server.connection_config['headers'])
    end
    
    config
  end
  
  def build_auth_config
    return {} unless server.auth_config.present?
    
    headers = {}
    
    case server.auth_type
    when 'api_key'
      header_name = server.auth_config['header_name'] || 'X-API-Key'
      api_key = server.auth_config['api_key'] || server.auth_config['key']
      headers[header_name] = api_key if api_key.present?
      
    when 'bearer'
      token = server.auth_config['token'] || server.auth_config['access_token']
      headers['Authorization'] = "Bearer #{token}" if token.present?
      
    when 'basic'
      username = server.auth_config['username']
      password = server.auth_config['password']
      
      if username.present? && password.present?
        credentials = Base64.strict_encode64("#{username}:#{password}")
        headers['Authorization'] = "Basic #{credentials}"
      end
      
    when 'custom'
      # For custom auth, use headers directly
      custom_headers = server.auth_config['headers'] || {}
      headers.merge!(custom_headers)
    end
    
    # Return config with headers if any were set
    headers.any? ? { 'headers' => headers } : {}
  end
  
  def build_metadata
    {
      'migrated_from_server_id' => server.id,
      'migrated_at' => Time.current.iso8601,
      'original_transport' => server.transport_type,
      'original_auth_type' => server.auth_type,
      'migration_version' => '1.0'
    }
  end
  
  def validate_migration
    @errors = []
    
    # Check if server exists
    unless server.present?
      @errors << "Server not found"
      return
    end
    
    # Check if already migrated
    if server.respond_to?(:migrated_at) && server.migrated_at.present?
      @errors << "Server already migrated at #{server.migrated_at}"
      return
    end
    
    # Check if owner can be determined
    owner = determine_owner
    unless owner.present?
      @errors << "Cannot determine owner for server"
      return
    end
    
    # Check if configuration already exists
    existing = McpConfiguration.where(
      owner: owner,
      name: server.name
    ).exists?
    
    if existing
      @errors << "Configuration with name '#{server.name}' already exists for this owner"
    end
    
    # Validate required fields based on transport type
    case server.transport_type
    when 'stdio'
      if server.connection_config.blank? || 
         (server.connection_config['command'].blank? && 
          server.connection_config['path'].blank? && 
          server.connection_config['executable'].blank?)
        @errors << "Stdio server missing command configuration"
      end
    when 'http', 'sse', 'websocket'
      if server.url.blank? && 
         server.connection_config&.dig('endpoint').blank? && 
         server.connection_config&.dig('url').blank?
        @errors << "Network server missing endpoint URL"
      end
    end
  end
end