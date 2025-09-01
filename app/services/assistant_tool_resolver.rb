class AssistantToolResolver
  attr_reader :assistant, :errors

  def initialize(assistant)
    @assistant = assistant
    @errors = []
  end

  def available_tools
    tools = []
    
    # Add native tools first
    tools += native_tools
    
    # Add MCP tools
    tools += mcp_tools
    
    tools.uniq { |tool| tool[:name] }
  end

  def resolve_mcp_tools
    mcp_tools
  end

  def tool_by_name(name)
    available_tools.find { |tool| tool[:name] == name }
  end

  def has_tool?(name)
    available_tools.any? { |tool| tool[:name] == name }
  end

  private

  def native_tools
    # Get tools that are built into the assistant
    tools = []
    
    # Check the assistant's tools configuration instead of capabilities
    if assistant.tools.present?
      assistant.tools.each do |tool_config|
        case tool_config['type']
        when 'web_search'
          tools << {
            name: 'web_search',
            type: 'native',
            description: 'Search the web for information',
            available: true
          }
        when 'calculator'
          tools << {
            name: 'calculator',
            type: 'native',
            description: 'Perform mathematical calculations',
            available: true
          }
        when 'claude_code'
          tools << {
            name: 'claude_code',
            type: 'native',
            description: 'Execute code and manage projects',
            available: true
          }
        when 'knowledge_search'
          tools << {
            name: 'knowledge_search',
            type: 'native',
            description: 'Search knowledge base',
            available: true
          }
        end
      end
    end
    
    tools
  end

  def mcp_tools
    tools = []
    
    # Get MCP configurations available to the assistant
    configurations = gather_mcp_configurations
    
    configurations.each do |config|
      case config.server_type
      when 'http', 'sse', 'websocket'
        # For HTTP-based MCPs, try to discover tools
        tools += discover_http_mcp_tools(config)
      when 'stdio'
        # For stdio MCPs, check if bridge is available
        tools += handle_stdio_mcp(config)
      end
    end
    
    tools
  end

  def gather_mcp_configurations
    configs = []
    
    # Get configurations owned by the assistant's user
    if assistant.respond_to?(:user) && assistant.user
      configs += McpConfiguration.for_user(assistant.user).active
    end
    
    # Get configurations from the assistant's team if it belongs to one
    if assistant.respond_to?(:agent_team) && assistant.agent_team
      configs += McpConfiguration.for_team(assistant.agent_team).active
    end
    
    # Get system-wide configurations (no owner)
    configs += McpConfiguration.where(owner: nil).active
    
    configs.uniq(&:id)
  end

  def discover_http_mcp_tools(config)
    tools = []
    
    begin
      # Use existing MCP client for HTTP-based servers
      client = McpClient.new(config)
      discovered_tools = client.discover_tools
      
      discovered_tools.each do |tool_def|
        tools << {
          name: "mcp_#{tool_def['name']}",
          type: 'mcp',
          server_type: config.server_type,
          server_name: config.name,
          server_id: config.id,
          description: tool_def['description'],
          input_schema: tool_def['inputSchema'],
          available: true,
          mcp_tool_name: tool_def['name']
        }
      end
    rescue => e
      Rails.logger.error "Failed to discover tools from #{config.name}: #{e.message}"
      @errors << "#{config.name}: #{e.message}"
      
      # Add placeholder indicating the MCP exists but tools couldn't be discovered
      tools << {
        name: "mcp_#{config.name.parameterize.underscore}",
        type: 'mcp',
        server_type: config.server_type,
        server_name: config.name,
        server_id: config.id,
        description: "MCP server '#{config.name}' (tools unavailable: #{e.message})",
        available: false,
        error: e.message
      }
    end
    
    tools
  end

  def handle_stdio_mcp(config)
    tools = []
    
    # Check if we can use the MCP Bridge Manager directly
    if config.enabled?
      begin
        # Try to discover tools through the actual MCP Bridge Manager
        user = find_user_for_config(config)
        if user
          bridge_manager = McpBridgeManager.new
          discovered_tools = bridge_manager.list_tools(user, config.id)
          
          discovered_tools.each do |tool_def|
            tool_description = tool_def[:description] || tool_def['description']
            tool_name = tool_def[:name] || tool_def['name']
            
            # Add performance notes for slow tools
            if tool_name == 'get_user_issues'
              tool_description += " (Note: This tool may take 10+ seconds for users with many issues. Consider using search_issues with filters for faster results.)"
            end
            
            tools << {
              name: "mcp_#{tool_name}",
              type: 'mcp',
              server_type: 'stdio_bridge',
              server_name: config.name,
              server_id: config.id,
              description: tool_description,
              input_schema: tool_def[:inputSchema] || tool_def['inputSchema'],
              available: true,
              mcp_tool_name: tool_name
            }
          end
        end
      rescue => e
        Rails.logger.error "Failed to discover tools through bridge manager for #{config.name}: #{e.message}"
        @errors << "#{config.name} (bridge): #{e.message}"
        
        # Fall back to development mode if bridge fails
        if Rails.env.development? || ENV['ENABLE_STDIO_MCP_DEVELOPMENT'] == 'true'
          tools += fallback_development_tools(config)
        end
      end
    elsif Rails.env.development? || ENV['ENABLE_STDIO_MCP_DEVELOPMENT'] == 'true'
      # Fall back to development mode tools
      tools += fallback_development_tools(config)
    else
      # Bridge not available - add placeholder
      tools << {
        name: "mcp_#{config.name.parameterize.underscore}",
        type: 'mcp',
        server_type: 'stdio',
        server_name: config.name,
        server_id: config.id,
        description: "#{config.name} (stdio MCP - requires bridge service)",
        available: false,
        bridge_required: true
      }
    end
    
    tools
  end

  def bridge_available?
    ENV['MCP_BRIDGE_ENABLED'] == 'true' && ENV['MCP_BRIDGE_URL'].present?
  end

  def find_user_for_config(config)
    # Try to find the user that owns this configuration
    case config.owner_type
    when 'User'
      config.owner
    when 'AgentTeam'
      # If assistant belongs to a team, try to find a team member
      if assistant.respond_to?(:agent_team) && assistant.agent_team&.id == config.owner_id
        assistant.agent_team.users.first
      end
    when 'Instance'
      # For instance configs, try to find the assistant's user
      if assistant.respond_to?(:user)
        assistant.user
      end
    else
      # Try to find the assistant's user as fallback
      assistant.respond_to?(:user) ? assistant.user : nil
    end
  end

  def fallback_development_tools(config)
    tools = []
    
    # TEMPORARY: For development, assume common Linear tools are available
    # This bypasses the bridge requirement for testing
    if config.name.downcase.include?('linear')
      tools << {
        name: "mcp_linear_issues",
        type: 'mcp',
        server_type: 'stdio',
        server_name: config.name,
        server_id: config.id,
        description: "Access Linear issues and projects",
        available: true,
        mcp_tool_name: 'linear_issues',
        development_mode: true
      }
      
      tools << {
        name: "mcp_linear_create_issue",
        type: 'mcp',
        server_type: 'stdio',
        server_name: config.name,
        server_id: config.id,
        description: "Create new Linear issues",
        available: true,
        mcp_tool_name: 'linear_create_issue',
        development_mode: true
      }
    else
      # For other stdio MCPs, add a generic tool
      tools << {
        name: "mcp_#{config.name.parameterize.underscore}",
        type: 'mcp',
        server_type: 'stdio',
        server_name: config.name,
        server_id: config.id,
        description: "#{config.name} MCP tools (development mode)",
        available: true,
        development_mode: true
      }
    end
    
    tools
  end

  # Compatibility method for existing code
  def load_mcp_tools
    mcp_tools
  end
end