module HasMcpConfigurations
  extend ActiveSupport::Concern

  included do
    has_many :mcp_configurations, as: :owner, dependent: :destroy
  end

  # Instance methods
  def available_mcp_configurations
    # Get all active MCP configurations for this owner
    mcp_configurations.active
  end

  def mcp_configuration_for(name)
    # Find a specific MCP configuration by name
    mcp_configurations.active.find_by(name: name)
  end

  def add_mcp_configuration(template_or_params)
    case template_or_params
    when McpTemplate
      # Create from template
      config = template_or_params.instantiate_configuration
      config.owner = self
      config.save!
      config
    when String, Symbol
      # Create from template key
      template = McpTemplate.find_template(template_or_params)
      raise ArgumentError, "Unknown template: #{template_or_params}" unless template
      add_mcp_configuration(template)
    when Hash
      # Create from params
      mcp_configurations.create!(template_or_params)
    else
      raise ArgumentError, "Invalid argument type: #{template_or_params.class}"
    end
  end

  def enable_mcp_configuration(name_or_id)
    config = find_mcp_configuration(name_or_id)
    config&.update!(enabled: true)
  end

  def disable_mcp_configuration(name_or_id)
    config = find_mcp_configuration(name_or_id)
    config&.update!(enabled: false)
  end

  def mcp_configurations_as_json
    # Get all configurations as JSON for Claude Code
    configs = {}
    available_mcp_configurations.each do |config|
      configs.merge!(config.to_mcp_json)
    end
    { mcpServers: configs }
  end

  def has_mcp_configuration?(name)
    mcp_configurations.active.exists?(name: name)
  end

  def mcp_configuration_count
    mcp_configurations.active.count
  end

  private

  def find_mcp_configuration(name_or_id)
    if name_or_id.is_a?(String) && name_or_id.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
      # UUID
      mcp_configurations.find_by(id: name_or_id)
    else
      # Name
      mcp_configurations.find_by(name: name_or_id)
    end
  end
end