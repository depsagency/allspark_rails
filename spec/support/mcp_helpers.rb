module McpHelpers
  # Mock MCP server responses
  def mock_mcp_server_response(server, method, response)
    connection_double = instance_double("McpConnection::Base")
    allow(McpConnectionManager.instance).to receive(:connection_for).with(server).and_return(connection_double)
    
    case method
    when :test_connection
      allow(connection_double).to receive(:test_connection).and_return(response)
    when :send_request
      allow(connection_double).to receive(:send_request).and_return(response.to_json)
    when :discover_tools
      tools_response = { "tools" => response }.to_json
      allow(connection_double).to receive(:send_request).and_return(tools_response)
    end
    
    connection_double
  end

  # Mock successful tool discovery
  def mock_successful_tool_discovery(server, tools = default_mock_tools)
    mock_mcp_server_response(server, :discover_tools, tools)
  end

  # Mock failed tool discovery
  def mock_failed_tool_discovery(server, error_message = "Connection failed")
    connection_double = instance_double("McpConnection::Base")
    allow(McpConnectionManager.instance).to receive(:connection_for).with(server).and_return(connection_double)
    allow(connection_double).to receive(:send_request).and_raise(McpConnection::Base::ConnectionError.new(error_message))
    connection_double
  end

  # Mock successful tool execution
  def mock_successful_tool_execution(server, tool_name, result = { "success" => true })
    connection_double = instance_double("McpConnection::Base")
    allow(McpConnectionManager.instance).to receive(:connection_for).with(server).and_return(connection_double)
    
    response = { "result" => result }.to_json
    allow(connection_double).to receive(:send_request).and_return(response)
    
    connection_double
  end

  # Mock failed tool execution
  def mock_failed_tool_execution(server, tool_name, error_message = "Tool execution failed")
    connection_double = instance_double("McpConnection::Base")
    allow(McpConnectionManager.instance).to receive(:connection_for).with(server).and_return(connection_double)
    allow(connection_double).to receive(:send_request).and_raise(McpConnection::Base::ProtocolError.new(error_message))
    connection_double
  end

  # Mock connection test
  def mock_connection_test(server, success = true)
    if success
      mock_mcp_server_response(server, :test_connection, true)
    else
      connection_double = instance_double("McpConnection::Base")
      allow(McpConnectionManager.instance).to receive(:connection_for).with(server).and_return(connection_double)
      allow(connection_double).to receive(:test_connection).and_raise(McpConnection::Base::ConnectionError.new("Connection failed"))
      connection_double
    end
  end

  # Create authentication stubs
  def stub_mcp_authentication(auth_type, credentials)
    case auth_type
    when :api_key
      stub_api_key_auth(credentials)
    when :oauth
      stub_oauth_auth(credentials)
    when :bearer_token
      stub_bearer_token_auth(credentials)
    when :basic
      stub_basic_auth(credentials)
    end
  end

  def stub_api_key_auth(credentials)
    # Mock successful API key validation
    allow_any_instance_of(McpConnection::ApiKeyConnection).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(McpConnection::ApiKeyConnection).to receive(:connect).and_return(true)
  end

  def stub_oauth_auth(credentials)
    # Mock successful OAuth token validation
    allow_any_instance_of(McpConnection::OauthConnection).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(McpConnection::OauthConnection).to receive(:connect).and_return(true)
    allow_any_instance_of(McpConnection::OauthConnection).to receive(:refresh_token!).and_return(true)
  end

  def stub_bearer_token_auth(credentials)
    # Mock successful bearer token validation
    allow_any_instance_of(McpConnection::BearerTokenConnection).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(McpConnection::BearerTokenConnection).to receive(:connect).and_return(true)
  end

  def stub_basic_auth(credentials)
    # Mock successful basic auth validation
    allow_any_instance_of(McpConnection::BasicConnection).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(McpConnection::BasicConnection).to receive(:connect).and_return(true)
  end

  # Error scenario helpers
  def simulate_connection_timeout(server)
    connection_double = instance_double("McpConnection::Base")
    allow(McpConnectionManager.instance).to receive(:connection_for).with(server).and_return(connection_double)
    allow(connection_double).to receive(:send_request).and_raise(McpConnection::Base::TimeoutError.new("Request timed out"))
    connection_double
  end

  def simulate_rate_limiting(server)
    connection_double = instance_double("McpConnection::Base")
    allow(McpConnectionManager.instance).to receive(:connection_for).with(server).and_return(connection_double)
    allow(connection_double).to receive(:send_request).and_raise(McpConnection::Base::RateLimitError.new("Rate limit exceeded"))
    connection_double
  end

  def simulate_authentication_failure(server)
    connection_double = instance_double("McpConnection::Base")
    allow(McpConnectionManager.instance).to receive(:connection_for).with(server).and_return(connection_double)
    allow(connection_double).to receive(:send_request).and_raise(McpConnection::Base::AuthenticationError.new("Invalid credentials"))
    connection_double
  end

  # Performance test helpers
  def simulate_slow_response(server, delay_seconds = 2)
    connection_double = instance_double("McpConnection::Base")
    allow(McpConnectionManager.instance).to receive(:connection_for).with(server).and_return(connection_double)
    
    allow(connection_double).to receive(:send_request) do
      sleep(delay_seconds)
      { "result" => { "success" => true } }.to_json
    end
    
    connection_double
  end

  def simulate_large_response(server, size_kb = 100)
    connection_double = instance_double("McpConnection::Base")
    allow(McpConnectionManager.instance).to receive(:connection_for).with(server).and_return(connection_double)
    
    large_data = "x" * (size_kb * 1024)
    response = { "result" => { "data" => large_data } }.to_json
    
    allow(connection_double).to receive(:send_request).and_return(response)
    connection_double
  end

  # Integration test utilities
  def with_real_mcp_server(endpoint, auth_type = :none, credentials = {})
    server = create(:mcp_server, 
      endpoint: endpoint, 
      auth_type: auth_type, 
      credentials: credentials,
      status: :active
    )
    
    yield server
  ensure
    server&.destroy
  end

  def with_vcr_cassette(cassette_name, &block)
    VCR.use_cassette(cassette_name, &block)
  end

  # Default mock data
  def default_mock_tools
    [
      {
        "name" => "linear_search",
        "description" => "Search Linear issues",
        "inputSchema" => {
          "type" => "object",
          "properties" => {
            "query" => {
              "type" => "string",
              "description" => "Search query"
            },
            "limit" => {
              "type" => "integer", 
              "description" => "Maximum results",
              "default" => 10
            }
          },
          "required" => ["query"]
        }
      },
      {
        "name" => "linear_create_issue",
        "description" => "Create a new Linear issue",
        "inputSchema" => {
          "type" => "object",
          "properties" => {
            "title" => {
              "type" => "string",
              "description" => "Issue title"
            },
            "description" => {
              "type" => "string",
              "description" => "Issue description"
            },
            "teamId" => {
              "type" => "string",
              "description" => "Team ID"
            }
          },
          "required" => ["title", "teamId"]
        }
      }
    ]
  end

  def default_search_result
    {
      "issues" => [
        {
          "id" => "issue-123",
          "title" => "Test Issue",
          "description" => "This is a test issue",
          "url" => "https://linear.app/test/issue/123"
        }
      ],
      "total" => 1
    }
  end

  def default_create_result
    {
      "issue" => {
        "id" => "issue-456",
        "title" => "New Issue",
        "url" => "https://linear.app/test/issue/456"
      }
    }
  end

  # Cache helpers
  def clear_mcp_caches
    Rails.cache.clear
    McpConnectionManager.instance.clear_all_connections
  end

  def with_mcp_cache_disabled
    original_enabled = Rails.cache.enabled?
    Rails.cache.enabled = false
    yield
  ensure
    Rails.cache.enabled = original_enabled
  end

  # Instrumentation helpers
  def capture_mcp_notifications
    events = []
    
    McpInstrumentation::EVENTS.values.each do |event_name|
      ActiveSupport::Notifications.subscribe(event_name) do |name, start, finish, id, payload|
        events << {
          name: name,
          duration: (finish - start) * 1000,
          payload: payload
        }
      end
    end
    
    yield
    
    events
  ensure
    # Unsubscribe to avoid test pollution
    ActiveSupport::Notifications.unsubscribe_all
  end

  def expect_mcp_event(event_type, &block)
    events = capture_mcp_notifications(&block)
    event_name = McpInstrumentation::EVENTS[event_type]
    
    expect(events).to include(
      hash_including(name: event_name)
    )
  end

  # Error handling helpers
  def capture_mcp_errors
    errors = []
    original_handler = McpErrorHandler.instance
    
    allow(original_handler).to receive(:handle_error) do |error, context|
      errors << { error: error, context: context }
      original_handler.send(:build_error_response, original_handler.send(:build_error_data, error, context))
    end
    
    yield
    
    errors
  end

  def expect_mcp_error(error_type, &block)
    errors = capture_mcp_errors(&block)
    
    expect(errors).to include(
      hash_including(
        error: an_instance_of(error_type)
      )
    )
  end
end

# Include in RSpec
RSpec.configure do |config|
  config.include McpHelpers, type: :model
  config.include McpHelpers, type: :service
  config.include McpHelpers, type: :request
  config.include McpHelpers, type: :system
  
  config.before(:each) do
    # Clear MCP-related state before each test
    clear_mcp_caches if respond_to?(:clear_mcp_caches)
  end
end