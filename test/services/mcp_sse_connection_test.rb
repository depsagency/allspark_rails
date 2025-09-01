require 'test_helper'

class McpSseConnectionTest < ActiveSupport::TestCase
  setup do
    @mcp_server = McpServer.create!(
      name: "Test SSE Server",
      endpoint: "https://example.com/mcp/sse",
      protocol_version: "1.0",
      transport_type: "sse",
      auth_type: "no_auth",
      status: "active"
    )
    
    @connection = McpConnection::SseConnection.new(@mcp_server)
  end

  test "should initialize with correct attributes" do
    assert_equal @mcp_server, @connection.instance_variable_get(:@mcp_server)
    assert_equal false, @connection.instance_variable_get(:@connected)
    assert_equal URI.parse(@mcp_server.endpoint), @connection.instance_variable_get(:@uri)
  end

  test "should handle connect method" do
    # Mock the HTTP connection test
    mock_http = Minitest::Mock.new
    mock_response = Minitest::Mock.new
    
    mock_response.expect(:is_a?, true, [Net::HTTPSuccess])
    mock_http.expect(:request, mock_response, [Net::HTTP::Get])
    
    Net::HTTP.stub :new, mock_http do
      assert @connection.connect
      assert @connection.instance_variable_get(:@connected)
    end
    
    mock_http.verify
    mock_response.verify
  end

  test "should handle disconnect method" do
    @connection.connect rescue nil # Ignore connection errors
    @connection.disconnect
    
    assert_equal false, @connection.instance_variable_get(:@connected)
    assert_nil @connection.instance_variable_get(:@last_event_id)
  end

  test "should build SSE request with correct headers" do
    request = @connection.send(:build_sse_request, '/test')
    
    assert_equal 'text/event-stream', request['Accept']
    assert_equal 'no-cache', request['Cache-Control']
  end

  test "should add auth headers for api_key auth type" do
    @mcp_server.update!(
      auth_type: 'api_key',
      credentials: { 'api_key' => 'test-key-123' }
    )
    
    connection = McpConnection::SseConnection.new(@mcp_server)
    request = connection.send(:build_sse_request, '/test')
    
    assert_equal 'Bearer test-key-123', request['Authorization']
  end

  test "should parse SSE events correctly" do
    event_data = {
      type: 'tool',
      data: '{"name":"test_tool","description":"Test tool"}',
      id: '123'
    }
    
    parsed = @connection.send(:parse_sse_event, event_data)
    
    assert_equal 'tool', parsed[:type]
    assert_equal '{"name":"test_tool","description":"Test tool"}', parsed[:data]
    assert_equal '123', parsed[:id]
  end

  test "should parse tool event data" do
    tool_json = '{"name":"create_issue","description":"Create a Linear issue","inputSchema":{"type":"object","properties":{"title":{"type":"string"}}}}'
    
    tool = @connection.send(:parse_tool_event, tool_json)
    
    assert_equal 'create_issue', tool['name']
    assert_equal 'Create a Linear issue', tool['description']
    assert_equal 'object', tool['inputSchema']['type']
  end

  test "should handle malformed JSON in tool event" do
    malformed_json = '{"name":"test", invalid json}'
    
    tool = @connection.send(:parse_tool_event, malformed_json)
    
    assert_nil tool
  end

  test "should raise error when not connected" do
    assert_raises(McpConnection::Base::ConnectionError) do
      @connection.send_request({ method: 'tools/list' })
    end
  end

  test "should support tools/list method" do
    @connection.instance_variable_set(:@connected, true)
    
    # Mock the SSE streaming
    mock_response = {
      result: {
        tools: [
          { 'name' => 'tool1', 'description' => 'First tool' },
          { 'name' => 'tool2', 'description' => 'Second tool' }
        ]
      }
    }
    
    @connection.stub :stream_sse_events, nil do
      @connection.stub :discover_tools_via_sse, mock_response do
        result = @connection.send_request({ method: 'tools/list' })
        
        assert_equal 2, result[:result][:tools].size
        assert_equal 'tool1', result[:result][:tools][0]['name']
      end
    end
  end

  test "should support tools/call method" do
    @connection.instance_variable_set(:@connected, true)
    
    payload = {
      method: 'tools/call',
      params: {
        name: 'create_issue',
        arguments: { title: 'Test Issue' }
      }
    }
    
    mock_result = { result: { id: 'LIN-123', title: 'Test Issue' } }
    
    @connection.stub :call_tool_via_sse, mock_result do
      result = @connection.send_request(payload)
      
      assert_equal 'LIN-123', result[:result][:id]
      assert_equal 'Test Issue', result[:result][:title]
    end
  end

  test "should raise protocol error for unsupported methods" do
    @connection.instance_variable_set(:@connected, true)
    
    assert_raises(McpConnection::Base::ProtocolError) do
      @connection.send_request({ method: 'unsupported/method' })
    end
  end
end