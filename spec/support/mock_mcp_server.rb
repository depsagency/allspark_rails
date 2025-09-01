#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'

# Mock MCP server for testing
# This simulates a simple MCP server that responds to JSON-RPC requests
class MockMcpServer
  def initialize
    @tools = [
      {
        'name' => 'echo',
        'description' => 'Echo back the input',
        'inputSchema' => {
          'type' => 'object',
          'properties' => {
            'message' => { 'type' => 'string' }
          }
        }
      },
      {
        'name' => 'add',
        'description' => 'Add two numbers',
        'inputSchema' => {
          'type' => 'object',
          'properties' => {
            'a' => { 'type' => 'number' },
            'b' => { 'type' => 'number' }
          }
        }
      }
    ]
  end
  
  def run
    STDERR.puts "[Mock MCP] Server started"
    
    loop do
      begin
        line = STDIN.gets
        break unless line
        
        request = JSON.parse(line.strip)
        response = handle_request(request)
        
        STDOUT.puts JSON.generate(response)
        STDOUT.flush
      rescue JSON::ParserError => e
        STDERR.puts "[Mock MCP] Parse error: #{e.message}"
        error_response(nil, -32700, "Parse error: #{e.message}")
      rescue => e
        STDERR.puts "[Mock MCP] Error: #{e.message}"
        error_response(nil, -32603, "Internal error: #{e.message}")
      end
    end
    
    STDERR.puts "[Mock MCP] Server stopped"
  end
  
  private
  
  def handle_request(request)
    method = request['method']
    params = request['params']
    id = request['id']
    
    case method
    when 'initialize'
      handle_initialize(id, params)
    when 'tools/list'
      handle_tools_list(id)
    when 'tools/call'
      handle_tool_call(id, params)
    when 'ping'
      success_response(id, { pong: true })
    else
      error_response(id, -32601, "Method not found: #{method}")
    end
  end
  
  def handle_initialize(id, params)
    success_response(id, {
      protocolVersion: '2024-11-05',
      capabilities: {
        tools: {}
      },
      serverInfo: {
        name: 'mock-mcp-server',
        version: '1.0.0'
      }
    })
  end
  
  def handle_tools_list(id)
    success_response(id, { tools: @tools })
  end
  
  def handle_tool_call(id, params)
    tool_name = params['name']
    arguments = params['arguments'] || {}
    
    case tool_name
    when 'echo'
      message = arguments['message'] || 'Hello'
      success_response(id, {
        content: [{ type: 'text', text: message }]
      })
    when 'add'
      a = arguments['a'] || 0
      b = arguments['b'] || 0
      result = a + b
      success_response(id, {
        content: [{ type: 'text', text: "Result: #{result}" }]
      })
    else
      error_response(id, -32602, "Unknown tool: #{tool_name}")
    end
  end
  
  def success_response(id, result)
    {
      jsonrpc: '2.0',
      id: id,
      result: result
    }
  end
  
  def error_response(id, code, message)
    response = {
      jsonrpc: '2.0',
      error: {
        code: code,
        message: message
      }
    }
    response[:id] = id if id
    response
  end
end

# Run the server if executed directly
if __FILE__ == $0
  server = MockMcpServer.new
  server.run
end