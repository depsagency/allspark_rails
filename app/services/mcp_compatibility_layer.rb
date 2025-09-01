# app/services/mcp_compatibility_layer.rb
# Provides compatibility between old MCP server system and new configuration system
class McpCompatibilityLayer
  class ServerFacade
    attr_reader :configuration
    
    def initialize(configuration)
      @configuration = configuration
    end
    
    # Make configuration look like a server
    def id
      configuration.id
    end
    
    def name
      configuration.name
    end
    
    def enabled
      configuration.enabled
    end
    alias_method :enabled?, :enabled
    
    def url
      case configuration.server_type
      when 'http', 'websocket'
        configuration.server_config['endpoint']
      when 'sse'
        configuration.server_config['url']
      else
        nil
      end
    end
    
    def transport_type
      configuration.server_type
    end
    
    def auth_type
      return nil unless configuration.server_config['headers'].present?
      
      headers = configuration.server_config['headers']
      
      if headers['Authorization']&.start_with?('Bearer ')
        'bearer'
      elsif headers['Authorization']&.start_with?('Basic ')
        'basic'
      elsif headers.keys.any? { |k| k.match?(/api[_-]?key/i) }
        'api_key'
      else
        'custom'
      end
    end
    
    def auth_config
      return {} unless configuration.server_config['headers'].present?
      
      headers = configuration.server_config['headers']
      config = {}
      
      case auth_type
      when 'bearer'
        token = headers['Authorization']&.sub('Bearer ', '')
        config['token'] = token if token
      when 'basic'
        credentials = headers['Authorization']&.sub('Basic ', '')
        if credentials
          decoded = Base64.decode64(credentials).split(':', 2)
          config['username'] = decoded[0]
          config['password'] = decoded[1]
        end
      when 'api_key'
        key_header = headers.keys.find { |k| k.match?(/api[_-]?key/i) }
        if key_header
          config['header_name'] = key_header
          config['api_key'] = headers[key_header]
        end
      when 'custom'
        config['headers'] = headers
      end
      
      config
    end
    
    def connection_config
      case configuration.server_type
      when 'stdio'
        {
          'command' => configuration.server_config['command'],
          'args' => configuration.server_config['args'],
          'env' => configuration.server_config['env']
        }.compact
      else
        {}
      end
    end
    
    # Support ActiveRecord-like methods
    def persisted?
      true
    end
    
    def to_param
      id.to_s
    end
  end
  
  class << self
    # Convert configuration to server-like object
    def configuration_to_server(configuration)
      ServerFacade.new(configuration)
    end
    
    # Convert old server format to new configuration format
    def server_to_configuration_params(server)
      {
        name: server.name,
        server_type: map_transport_type(server.transport_type),
        enabled: server.enabled,
        server_config: build_server_config(server),
        metadata: {
          'converted_from_server' => true,
          'original_server_id' => server.id
        }
      }
    end
    
    # Find MCP resources (tries both systems)
    def find_mcp_resource(id, owner: nil)
      # Try configuration first
      config = if owner
        owner.mcp_configurations.find_by(id: id)
      else
        McpConfiguration.find_by(id: id)
      end
      
      return configuration_to_server(config) if config
      
      # Fall back to server
      server = McpServer.find_by(id: id)
      return server if server
      
      nil
    end
    
    # List all MCP resources for an owner
    def list_mcp_resources(owner)
      resources = []
      
      # Add configurations
      if owner.respond_to?(:mcp_configurations)
        resources += owner.mcp_configurations.map { |c| configuration_to_server(c) }
      end
      
      # Add legacy servers
      if owner.is_a?(User) && McpServer.where(user_id: owner.id, migrated_at: nil).exists?
        resources += McpServer.where(user_id: owner.id, migrated_at: nil)
      elsif owner.respond_to?(:id) && owner.class.name
        resources += McpServer.where(
          owner_type: owner.class.name, 
          owner_id: owner.id,
          migrated_at: nil
        )
      end
      
      resources
    end
    
    # Check if using new system
    def using_new_system?(owner)
      return false unless owner.respond_to?(:mcp_configurations)
      owner.mcp_configurations.exists?
    end
    
    # Log usage for migration tracking
    def log_compatibility_usage(action, resource_type, resource_id)
      Rails.logger.info(
        "[MCP Compatibility] Action: #{action}, " \
        "Type: #{resource_type}, " \
        "ID: #{resource_id}, " \
        "Time: #{Time.current}"
      )
      
      # Could also track in Redis or database for metrics
      if defined?(Rails.cache)
        key = "mcp_compatibility:#{Date.current}:#{resource_type}"
        Rails.cache.increment(key, 1, expires_in: 30.days)
      end
    end
    
    private
    
    def map_transport_type(transport)
      case transport
      when 'stdio' then 'stdio'
      when 'http' then 'http'
      when 'sse' then 'sse'
      when 'websocket' then 'websocket'
      else 'http'
      end
    end
    
    def build_server_config(server)
      migrator = McpServerMigrator.new(server)
      # Use private method through send (not ideal but avoids duplication)
      migrator.send(:build_server_config)
    rescue
      {}
    end
  end
end