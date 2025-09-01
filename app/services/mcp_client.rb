class McpClient
  MCP_VERSION = "1.0"
  
  def initialize(mcp_server)
    @mcp_server = mcp_server
    @connection_manager = McpConnectionManager.instance
  end

  def test_connection
    McpInstrumentation.instance.instrument_connection(@mcp_server.id) do
      connection = get_connection
      connection.test_connection
    end
  rescue => e
    McpErrorHandler.instance.handle_error(e, {
      server_id: @mcp_server.id,
      server_name: @mcp_server.name,
      context: 'connection_test'
    })
    false
  end

  def discover_tools
    McpInstrumentation.instance.instrument_tool_discovery(@mcp_server.id) do
      connection = get_connection
      
      Rails.logger.debug "[MCP] Discovering tools for server #{@mcp_server.name}"
      
      payload = {
        jsonrpc: "2.0",
        id: generate_request_id,
        method: "tools/list",
        params: {}
      }
      
      response = connection.send_request(payload)
      result = parse_response(response)
      
      tools = extract_tools_from_response(result)
      
      Rails.logger.info "[MCP] Discovered #{tools.size} tools for server #{@mcp_server.name}"
      tools
    end
  rescue => e
    McpErrorHandler.instance.handle_error(e, {
      server_id: @mcp_server.id,
      server_name: @mcp_server.name,
      context: 'tool_discovery'
    })
    []
  end

  def call_tool(tool_name, arguments = {}, user: nil, assistant: nil)
    McpInstrumentation.instance.instrument_tool_execution(
      @mcp_server.id, 
      tool_name, 
      user_id: user&.id, 
      assistant_id: assistant&.id
    ) do
      start_time = Time.current
      connection = get_connection
      
      Rails.logger.debug "[MCP] Calling tool '#{tool_name}' on server #{@mcp_server.name}"
      
      payload = {
        jsonrpc: "2.0",
        id: generate_request_id,
        method: "tools/call",
        params: {
          name: tool_name,
          arguments: arguments
        }
      }
      
      response = connection.send_request(payload)
      result = parse_response(response)
      
      response_time_ms = ((Time.current - start_time) * 1000).round
      
      # Log the execution if user and assistant are provided
      if user && assistant
        McpAuditLog.log_execution(
          user: user,
          mcp_server: @mcp_server,
          assistant: assistant,
          tool_name: tool_name,
          request_data: arguments,
          response_data: result,
          status: :success,
          response_time_ms: response_time_ms
        )
      end
      
      Rails.logger.info "[MCP] Tool '#{tool_name}' executed successfully in #{response_time_ms}ms"
      format_tool_response(result)
    end
  rescue => e
    # Calculate response time for failed requests
    response_time_ms = (Time.current.to_f * 1000).round rescue 0
    
    # Log the failed execution
    if user && assistant
      McpAuditLog.log_execution(
        user: user,
        mcp_server: @mcp_server,
        assistant: assistant,
        tool_name: tool_name,
        request_data: arguments,
        response_data: { error: e.message },
        status: determine_error_status(e),
        response_time_ms: response_time_ms
      )
    end
    
    # Handle error through error handler
    error_response = McpErrorHandler.instance.handle_error(e, {
      server_id: @mcp_server.id,
      server_name: @mcp_server.name,
      tool_name: tool_name,
      user_id: user&.id,
      assistant_id: assistant&.id,
      request_id: generate_request_id
    })
    
    error_response
  end

  def get_tool_schema(tool_name)
    tools = discover_tools
    tool = tools.find { |t| t['name'] == tool_name }
    
    return nil unless tool
    
    {
      name: tool['name'],
      description: tool['description'],
      parameters: tool['inputSchema'] || {},
      return_type: tool['outputSchema'] || {}
    }
  end

  def ping
    connection = get_connection
    
    payload = {
      jsonrpc: "2.0",
      id: generate_request_id,
      method: "ping",
      params: {}
    }
    
    response = connection.send_request(payload)
    result = parse_response(response)
    
    result['pong'] == true
  rescue => e
    Rails.logger.debug "[MCP] Ping failed for server #{@mcp_server.id}: #{e.message}"
    false
  end

  def get_server_info
    connection = get_connection
    
    payload = {
      jsonrpc: "2.0",
      id: generate_request_id,
      method: "initialize",
      params: {
        protocolVersion: MCP_VERSION,
        capabilities: {
          tools: true
        },
        clientInfo: {
          name: "AllSpark",
          version: "1.0"
        }
      }
    }
    
    response = connection.send_request(payload)
    result = parse_response(response)
    
    {
      protocol_version: result['protocolVersion'],
      server_name: result.dig('serverInfo', 'name'),
      server_version: result.dig('serverInfo', 'version'),
      capabilities: result['capabilities'] || {}
    }
  rescue => e
    Rails.logger.error "[MCP] Failed to get server info for #{@mcp_server.id}: #{e.message}"
    nil
  end

  private

  def get_connection
    @connection_manager.connection_for(@mcp_server)
  end

  def generate_request_id
    SecureRandom.uuid
  end

  def parse_response(response_body)
    data = JSON.parse(response_body)
    
    if data['error']
      handle_mcp_error(data['error'])
    else
      data['result'] || data
    end
  rescue JSON::ParserError => e
    raise McpConnection::Base::ProtocolError, "Invalid JSON response: #{e.message}"
  end

  def handle_mcp_error(error)
    case error['code']
    when -32600
      raise McpConnection::Base::ProtocolError, "Invalid Request: #{error['message']}"
    when -32601
      raise McpConnection::Base::ProtocolError, "Method not found: #{error['message']}"
    when -32602
      raise McpConnection::Base::ProtocolError, "Invalid params: #{error['message']}"
    when -32603
      raise McpConnection::Base::ProtocolError, "Internal error: #{error['message']}"
    when -32000..-32099
      # Server error range
      raise McpConnection::Base::ConnectionError, "Server error: #{error['message']}"
    else
      raise McpConnection::Base::ConnectionError, "MCP Error #{error['code']}: #{error['message']}"
    end
  end

  def extract_tools_from_response(result)
    if result.is_a?(Hash) && result['tools'].is_a?(Array)
      result['tools']
    elsif result.is_a?(Array)
      result
    else
      raise McpConnection::Base::ProtocolError, "Invalid tools list response format"
    end
  end

  def format_tool_response(result)
    # Ensure the response follows our standard format
    if result.is_a?(Hash)
      if result['error']
        { error: result['error'] }
      elsif result['content']
        { success: true, content: result['content'] }
      elsif result['result']
        { success: true, result: result['result'] }
      else
        { success: true, data: result }
      end
    else
      { success: true, result: result }
    end
  end

  def determine_error_status(error)
    case error
    when McpConnection::Base::TimeoutError
      :timeout
    when McpConnection::Base::AuthenticationError,
         McpConnection::Base::ConnectionError,
         McpConnection::Base::ProtocolError,
         McpConnection::Base::RateLimitError
      :failure
    else
      :failure
    end
  end
end