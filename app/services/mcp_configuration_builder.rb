class McpConfigurationBuilder
  def initialize(user:, context_owner: nil)
    @user = user
    @context_owner = context_owner
  end

  def build
    configs = {}
    
    # Start with user configurations (lowest precedence)
    add_configurations_from(@user, configs) if @user
    
    # Add context owner configurations (higher precedence)  
    add_configurations_from(@context_owner, configs) if @context_owner
    
    # Add team configurations if user has teams (medium precedence)
    if @user&.respond_to?(:teams)
      @user.teams.each do |team|
        add_configurations_from(team, configs)
      end
    end
    
    # Instance configurations have highest precedence
    if @context_owner.is_a?(Instance)
      # Instance configs override everything
    elsif @context_owner.respond_to?(:instance)
      add_configurations_from(@context_owner.instance, configs)
    end
    
    { mcpServers: configs }
  end

  def build_for_assistant(assistant)
    configs = {}
    
    # Get configurations available to the assistant
    if assistant.respond_to?(:user)
      add_assistant_configurations_from(assistant.user, configs)
    end
    
    if assistant.respond_to?(:team)
      add_assistant_configurations_from(assistant.team, configs)
    end
    
    configs
  end

  private

  def add_configurations_from(owner, configs)
    return unless owner&.respond_to?(:mcp_configurations)
    
    owner.mcp_configurations.active.each do |config|
      # Later configurations override earlier ones
      configs.merge!(config.to_mcp_json)
    end
  end

  def add_assistant_configurations_from(owner, configs)
    return unless owner&.respond_to?(:mcp_configurations)
    
    owner.mcp_configurations.active.each do |config|
      # For assistants, return the configuration in assistant format
      assistant_config = config.for_assistant
      configs[config.name] = assistant_config
    end
  end

  def merge_configurations(base, override)
    # Deep merge configurations with override taking precedence
    base.deep_merge(override)
  end

  def decrypt_credentials(config)
    # Decrypt any encrypted credentials in the configuration
    return config unless config.is_a?(Hash)
    
    config.deep_dup.tap do |decrypted|
      if decrypted['env'].is_a?(Hash)
        decrypted['env'].each do |key, value|
          # Handle encrypted values or environment variable references
          decrypted['env'][key] = resolve_credential(value)
        end
      end
    end
  end

  def resolve_credential(value)
    return value unless value.is_a?(String)
    
    # Resolve {{ENV_VAR}} references
    if value.match?(/\{\{(\w+)\}\}/)
      value.gsub(/\{\{(\w+)\}\}/) { ENV[$1] || $& }
    else
      value
    end
  end

  def handle_config_errors
    # Log configuration errors but don't fail the build
    yield
  rescue => e
    Rails.logger.error "MCP Configuration error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    {}
  end
end