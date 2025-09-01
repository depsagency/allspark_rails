class McpConfigValidator
  attr_reader :errors

  def initialize
    @errors = []
  end

  def validate(configuration)
    @errors.clear
    
    # Validate basic structure
    validate_basic_structure(configuration)
    
    # Validate server config format
    validate_server_config(configuration.server_config) if configuration.server_config.present?
    
    # Validate server type
    validate_server_type(configuration)
    
    # Validate required fields
    validate_required_fields(configuration)
    
    # Test decryptability if encryption is enabled
    validate_decryption(configuration) if configuration.respond_to?(:server_config_before_type_cast)
    
    @errors.empty?
  end

  def valid?
    @errors.empty?
  end

  def error_messages
    @errors.join(", ")
  end

  private

  def validate_basic_structure(configuration)
    unless configuration.is_a?(McpConfiguration)
      @errors << "Invalid configuration object"
      return
    end
    
    if configuration.name.blank?
      @errors << "Name is required"
    end
    
    if configuration.server_config.blank?
      @errors << "Server configuration is required"
    end
  end

  def validate_server_config(config)
    unless config.is_a?(Hash)
      @errors << "Server config must be a hash"
      return
    end
    
    case determine_server_type(config)
    when 'stdio'
      validate_stdio_config(config)
    when 'http', 'sse'
      validate_http_config(config)
    when 'websocket'
      validate_websocket_config(config)
    end
  end

  def validate_stdio_config(config)
    if config['command'].blank?
      @errors << "Command is required for stdio servers"
    end
    
    # Check if command exists (basic check)
    if config['command'].present? && !command_exists?(config['command'])
      @errors << "Command '#{config['command']}' not found in PATH"
    end
    
    # Validate args is an array if present
    if config['args'].present? && !config['args'].is_a?(Array)
      @errors << "Args must be an array"
    end
  end

  def validate_http_config(config)
    if config['endpoint'].blank? && config['url'].blank?
      @errors << "Endpoint or URL is required for HTTP servers"
    end
    
    # Validate URL format
    url = config['endpoint'] || config['url']
    if url.present?
      begin
        uri = URI.parse(url)
        unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
          @errors << "Invalid URL format: #{url}"
        end
      rescue URI::InvalidURIError
        @errors << "Invalid URL: #{url}"
      end
    end
  end

  def validate_websocket_config(config)
    if config['endpoint'].blank?
      @errors << "Endpoint is required for WebSocket servers"
    end
    
    # Validate WebSocket URL
    if config['endpoint'].present?
      unless config['endpoint'].match?(/^wss?:\/\//)
        @errors << "WebSocket endpoint must start with ws:// or wss://"
      end
    end
  end

  def validate_server_type(configuration)
    if configuration.server_type.blank?
      @errors << "Server type is required"
    end
    
    # Ensure server type matches config
    expected_type = determine_server_type(configuration.server_config)
    if expected_type && configuration.server_type != expected_type
      @errors << "Server type mismatch: config suggests '#{expected_type}' but type is '#{configuration.server_type}'"
    end
  end

  def validate_required_fields(configuration)
    # If created from template, check required fields
    if configuration.metadata && configuration.metadata['template_key']
      template = McpTemplate.find_by(key: configuration.metadata['template_key'])
      if template && template.required_fields.present?
        missing_fields = check_missing_fields(configuration.server_config, template.required_fields)
        if missing_fields.any?
          @errors << "Missing required fields: #{missing_fields.join(', ')}"
        end
      end
    end
  end

  def validate_decryption(configuration)
    # Try to decrypt to ensure it works
    begin
      configuration.decrypted_server_config
    rescue => e
      @errors << "Failed to decrypt server config: #{e.message}"
    end
  end

  def determine_server_type(config)
    return nil unless config.is_a?(Hash)
    
    if config['command'].present?
      'stdio'
    elsif config['endpoint'].present?
      if config['endpoint'].include?('ws://') || config['endpoint'].include?('wss://')
        'websocket'
      else
        'http'
      end
    elsif config['url'].present?
      'sse'
    else
      nil
    end
  end

  def command_exists?(command)
    # Basic check if command exists in PATH
    system("which #{command} > /dev/null 2>&1")
  end

  def check_missing_fields(config, required_fields)
    missing = []
    
    required_fields.each do |field|
      field_str = field.to_s
      
      # Check in main config
      value = config[field_str]
      
      # Check in env if not found
      if value.blank? && config['env'].is_a?(Hash)
        value = config['env'][field_str] || config['env'][field_str.upcase]
      end
      
      # Check if it's a template variable
      if value.present? && value.is_a?(String) && value.match?(/\{\{.+\}\}/)
        missing << field_str
      elsif value.blank?
        missing << field_str
      end
    end
    
    missing
  end
end