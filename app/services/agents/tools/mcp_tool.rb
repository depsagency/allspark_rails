class Agents::Tools::McpTool
  extend Langchain::ToolDefinition

  NAME = "mcp_tool"
  ANNOTATIONS_PATH = Pathname.new(__dir__).join("../../../schemas/agents/tools/mcp_tool.json")

  def self.description
    "Executes tools from MCP (Model Context Protocol) servers"
  end

  def initialize(mcp_server:, tool_name:, tool_description: nil, tool_schema: nil, user: nil)
    @mcp_server = mcp_server
    @tool_name = tool_name
    @tool_description = tool_description
    @tool_schema = tool_schema
    @user = user
    
    # Support both old servers and new configurations
    @client = if @mcp_server.is_a?(McpCompatibilityLayer::ServerFacade)
      # Log usage for migration tracking
      McpCompatibilityLayer.log_compatibility_usage(
        'tool_init', 
        'configuration', 
        @mcp_server.configuration.id
      )
      
      # For configurations, we don't use the client directly
      # (Claude Code will use the config, Assistants will use the resolver)
      nil
    else
      # Legacy server - use existing client
      McpCompatibilityLayer.log_compatibility_usage(
        'tool_init', 
        'server', 
        @mcp_server.id
      )
      
      McpClient.new(@mcp_server)
    end
  end

  # Override the NAME to be dynamic based on the tool
  def self.name_for_tool(tool_name)
    "mcp_#{tool_name}"
  end

  def name
    self.class.name_for_tool(@tool_name)
  end

  def description
    @tool_description || "MCP tool: #{@tool_name} from #{@mcp_server.name}"
  end

  # Define the function with a generic parameter that can accept any MCP tool arguments
  define_function :execute, description: "Execute the MCP tool" do
    property :args, type: "object", description: "Arguments for the MCP tool (varies by tool)", required: false
  end

  def execute(**args)
    Rails.logger.info "[MCP Tool] Executing #{@tool_name} on #{@mcp_server.name} with args: #{args.inspect}"
    
    start_time = Time.current
    
    # Filter arguments to only include those expected by the tool
    filtered_args = filter_arguments(args)
    
    # Execute based on server type
    result = if @mcp_server.is_a?(McpCompatibilityLayer::ServerFacade)
      execute_for_configuration(filtered_args)
    else
      # Legacy server - use existing client
      @client.call_tool(@tool_name, filtered_args, user: @user, assistant: current_assistant)
    end
    
    response_time = ((Time.current - start_time) * 1000).round
    
    # Format the result for the assistant
    formatted_result = format_result(result)
    
    Rails.logger.info "[MCP Tool] #{@tool_name} completed in #{response_time}ms"
    
    formatted_result
  rescue => e
    Rails.logger.error "[MCP Tool] Error executing #{@tool_name}: #{e.message}"
    
    {
      error: "MCP tool execution failed: #{e.message}",
      tool_name: @tool_name,
      server: @mcp_server.name
    }
  end

  # Tool information for assistant configuration
  def self.create_from_mcp_tool(mcp_server, tool_definition, user: nil)
    tool_name = tool_definition['name']
    tool_description = tool_definition['description']
    tool_schema = tool_definition['inputSchema']
    
    # Create a shorter, unique class name to avoid OpenAI's 64-character function name limit
    # Convert tool names to abbreviated forms
    abbreviated_name = abbreviate_tool_name(tool_name)
    class_name = "Mcp#{abbreviated_name}Tool"
    
    # Check if we already created this class
    unless const_defined?(class_name)
      # Create a new class that inherits from McpTool but has a unique name
      tool_class = Class.new(self)
      
      # Set the class name in the constant table BEFORE defining functions
      # This ensures the class has a name when Langchain tries to access it
      const_set(class_name, tool_class)
      
      # Now define the function - the class should have a proper name
      tool_class.class_eval do
        define_function :execute, description: tool_description || "Execute #{tool_name}" do
          property :args, type: "object", description: "Arguments for #{tool_name}", required: false
        end
      end
    else
      tool_class = const_get(class_name)
    end
    
    # Create an instance of the unique class
    tool_class.new(
      mcp_server: mcp_server,
      tool_name: tool_name,
      tool_description: tool_description,
      tool_schema: tool_schema,
      user: user
    )
  end

  # Abbreviate tool names to keep function names under 64 characters
  def self.abbreviate_tool_name(tool_name)
    # Common abbreviations for Linear tools
    abbreviations = {
      'linear_create_issue' => 'LinearCreate',
      'linear_list_issues' => 'LinearList',
      'linear_update_issue' => 'LinearUpdate',
      'linear_list_teams' => 'LinearTeams',
      'linear_list_projects' => 'LinearProjects',
      'linear_search_issues' => 'LinearSearch',
      'linear_get_issue' => 'LinearGet',
      'linear_list_workflow_states' => 'LinearStates'
    }
    
    # Return abbreviation if available, otherwise create a short form
    abbreviations[tool_name] || tool_name.gsub(/[_-]/, '').capitalize[0..15]
  end

  def tool_info
    {
      name: name,
      description: description,
      server: @mcp_server.name,
      server_id: @mcp_server.id,
      mcp_tool_name: @tool_name,
      schema: @tool_schema,
      enabled: @mcp_server.active?
    }
  end

  private

  def build_parameters_schema
    # Use the tool's input schema if available, otherwise use generic args
    if @tool_schema.is_a?(Hash) && @tool_schema['properties']
      # Convert MCP schema to function calling schema
      {
        type: "object",
        properties: @tool_schema['properties'],
        required: @tool_schema['required'] || []
      }
    else
      # Fallback to generic args parameter
      {
        type: "object",
        properties: {
          args: {
            type: "object", 
            description: "Arguments for the MCP tool (varies by tool)"
          }
        },
        required: []
      }
    end
  end

  def filter_arguments(args)
    return args unless @tool_schema.is_a?(Hash)
    
    # If we have a schema, filter to only include valid properties
    if @tool_schema['properties'].is_a?(Hash)
      valid_properties = @tool_schema['properties'].keys
      args.select { |key, _| valid_properties.include?(key.to_s) }
    else
      args
    end
  end

  def format_result(result)
    if result.is_a?(Hash) && result['error']
      # Return error in expected format
      {
        error: result['error'],
        tool_name: @tool_name,
        server: @mcp_server.name
      }
    elsif result.is_a?(Hash) && result['success']
      # Successful result
      content = result['content'] || result['result'] || result['data']
      
      {
        success: true,
        content: format_content(content),
        tool_name: @tool_name,
        server: @mcp_server.name,
        response_time: result['response_time']
      }
    else
      # Handle other result formats
      {
        success: true,
        content: format_content(result),
        tool_name: @tool_name,
        server: @mcp_server.name
      }
    end
  end

  def format_content(content)
    case content
    when String
      content
    when Hash
      # Format hash as readable text
      if content['message']
        content['message']
      elsif content['text']
        content['text']
      elsif content['result']
        content['result'].to_s
      else
        content.inspect
      end
    when Array
      # Format array as list
      if content.all? { |item| item.is_a?(Hash) && item['title'] }
        # Looks like search results or similar
        content.map { |item| "- #{item['title']}: #{item['description'] || item['url']}" }.join("\n")
      else
        content.map(&:to_s).join(", ")
      end
    else
      content.to_s
    end
  end

  def current_assistant
    # Try to get the current assistant from context
    # This might be set by the assistant execution context
    @current_assistant ||= Thread.current[:current_assistant]
  end
  
  def execute_for_configuration(args)
    config = @mcp_server.configuration
    
    case config.server_type
    when 'stdio'
      # Use MCP Bridge Manager for stdio servers
      begin
        bridge_manager = McpBridgeManager.new
        result = bridge_manager.execute_tool(@user, config.id, @tool_name, args)
        
        # Convert bridge manager response to standard format
        if result[:success]
          {
            'success' => true,
            'content' => result[:content],
            'response_time' => (result[:execution_time] * 1000).round # Convert to ms
          }
        else
          {
            'error' => result[:error][:message],
            'error_code' => result[:error][:code]
          }
        end
      rescue => e
        Rails.logger.error "[MCP Tool] Bridge manager error: #{e.message}"
        {
          'error' => "Bridge error: #{e.message}",
          'error_code' => -32603
        }
      end
    when 'http', 'sse', 'websocket'
      # For network configs, create a temporary client
      # This maintains compatibility during migration
      temp_server = create_temp_server_from_config(config)
      temp_client = McpClient.new(temp_server)
      temp_client.call_tool(@tool_name, args, user: @user, assistant: current_assistant)
    else
      {
        error: "Unknown server type: #{config.server_type}",
        tool_name: @tool_name,
        server: @mcp_server.name
      }
    end
  end
  
  def create_temp_server_from_config(config)
    # Create a temporary McpServer object from configuration
    # This is a compatibility shim during migration
    server = McpServer.new(
      name: config.name,
      enabled: config.enabled,
      transport_type: config.server_type,
      url: config.server_config['endpoint'] || config.server_config['url']
    )
    
    # Set auth if present
    if config.server_config['headers'].present?
      headers = config.server_config['headers']
      
      if headers['Authorization']&.start_with?('Bearer ')
        server.auth_type = 'bearer'
        server.auth_config = { 'token' => headers['Authorization'].sub('Bearer ', '') }
      elsif headers['Authorization']&.start_with?('Basic ')
        server.auth_type = 'basic'
        # Would need to decode basic auth here
      elsif headers.keys.any? { |k| k.match?(/api[_-]?key/i) }
        server.auth_type = 'api_key'
        key_header = headers.keys.find { |k| k.match?(/api[_-]?key/i) }
        server.auth_config = {
          'header_name' => key_header,
          'api_key' => headers[key_header]
        }
      end
    end
    
    server
  end
  
  def simulate_linear_tool_call(args)
    # TEMPORARY: Simulate Linear API responses for development
    case @tool_name
    when 'linear_issues', 'mcp_linear_issues'
      {
        success: true,
        content: "Found 3 Linear issues:\n1. Fix authentication bug (In Progress)\n2. Update documentation (Todo)\n3. Optimize database queries (Backlog)",
        tool_name: @tool_name,
        server: @mcp_server.name,
        note: "[DEVELOPMENT MODE] This is simulated data. Real Linear integration requires bridge service."
      }
    when 'linear_create_issue', 'mcp_linear_create_issue'
      title = args[:title] || args['title'] || 'New Issue'
      {
        success: true,
        content: "Created Linear issue: #{title} (ID: LIN-#{rand(100..999)})",
        tool_name: @tool_name,
        server: @mcp_server.name,
        note: "[DEVELOPMENT MODE] This is simulated data. Real Linear integration requires bridge service."
      }
    else
      {
        success: true,
        content: "Simulated response for #{@tool_name} with args: #{args.inspect}",
        tool_name: @tool_name,
        server: @mcp_server.name,
        note: "[DEVELOPMENT MODE] This is simulated data."
      }
    end
  end
end