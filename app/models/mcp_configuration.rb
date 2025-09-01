class McpConfiguration < ApplicationRecord
  # Associations
  belongs_to :owner, polymorphic: true
  has_many :mcp_audit_logs, dependent: :destroy
  
  # Enums
  enum :server_type, {
    stdio: 0,      # Requires process spawning
    http: 1,       # Direct HTTP access
    sse: 2,        # Server-sent events
    websocket: 3   # WebSocket connection
  }, prefix: true
  
  # Encryption - commented out for now, can be enabled when keys are configured
  # encrypts :server_config
  
  # Validations
  validates :name, presence: true
  validates :server_config, presence: true
  validates :server_type, presence: true
  
  # Scopes
  scope :active, -> { where(enabled: true) }
  scope :for_user, ->(user) { where(owner: user) }
  scope :for_team, ->(team) { where(owner: team) }
  
  # Handle JSON serialization for encrypted text column
  before_save :serialize_server_config
  after_find :deserialize_server_config
  
  attr_accessor :server_config_hash
  
  def server_config
    @server_config_hash || {}
  end
  
  def server_config=(value)
    @server_config_hash = value.is_a?(String) ? JSON.parse(value) : value
  end
  
  # Instance methods
  def to_mcp_json
    {
      name => decrypted_server_config
    }
  end
  
  
  def for_assistant
    case server_type
    when 'http', 'sse', 'websocket'
      # Return endpoint URL for HTTP-based MCPs
      { 
        type: server_type, 
        url: endpoint_url,
        credentials: extract_credentials
      }
    when 'stdio'
      # Return bridge endpoint for stdio MCPs
      { 
        type: 'http', 
        url: bridge_endpoint,
        note: 'Bridge required for stdio MCP'
      }
    end
  end
  
  def bridge_available?
    # Check if bridge service is available for stdio MCPs
    server_type_stdio? && ENV['MCP_BRIDGE_ENABLED'] == 'true'
  end
  
  def test_connection
    # Test the MCP configuration
    case server_type
    when 'http', 'sse', 'websocket'
      test_http_connection
    when 'stdio'
      test_stdio_configuration
    end
  end
  
  private
  
  def decrypted_server_config
    # Return decrypted config with environment variables resolved
    config = (server_config || {}).deep_dup
    
    # Resolve environment variables in config
    if config['env'].is_a?(Hash)
      config['env'].each do |key, value|
        # Replace {{var}} placeholders with actual values
        if value.is_a?(String) && value.match?(/\{\{.+\}\}/)
          config['env'][key] = resolve_env_variable(value)
        end
      end
    end
    
    config
  end
  
  def endpoint_url
    # Extract endpoint URL from config for HTTP-based MCPs
    server_config['endpoint'] || 
    server_config['url'] ||
    server_config.dig('args', 1) # For configs like ["http", "https://example.com"]
  end
  
  def extract_credentials
    # Extract credentials for HTTP-based MCPs
    return {} unless server_config['env'].is_a?(Hash)
    
    server_config['env'].select do |key, _|
      key.match?(/_TOKEN|_KEY|_SECRET|_PASSWORD/i)
    end
  end
  
  def bridge_endpoint
    # Generate bridge endpoint URL for stdio MCPs
    "#{ENV['MCP_BRIDGE_URL'] || 'http://mcp-bridge:8080'}/servers/#{id}"
  end
  
  def resolve_env_variable(value)
    # Resolve {{VAR_NAME}} to actual environment variable
    value.gsub(/\{\{(\w+)\}\}/) do |match|
      ENV[$1] || match
    end
  end
  
  def test_http_connection
    # Test HTTP-based MCP connection
    begin
      uri = URI.parse(endpoint_url)
      response = Net::HTTP.get_response(uri)
      { success: response.is_a?(Net::HTTPSuccess), message: response.message }
    rescue => e
      { success: false, message: e.message }
    end
  end
  
  def test_stdio_configuration
    # Test stdio MCP configuration
    begin
      # Just validate the command exists
      command = server_config['command']
      return { success: false, message: 'No command specified' } if command.blank?
      
      # Check if command is available
      system("which #{command} > /dev/null 2>&1")
      if $?.success?
        { success: true, message: 'Command found' }
      else
        { success: false, message: "Command '#{command}' not found" }
      end
    rescue => e
      { success: false, message: e.message }
    end
  end
  
  def serialize_server_config
    self[:server_config] = @server_config_hash.to_json if @server_config_hash
  end
  
  def deserialize_server_config
    if self[:server_config].present?
      @server_config_hash = JSON.parse(self[:server_config])
    end
  rescue JSON::ParserError
    @server_config_hash = {}
  end
end