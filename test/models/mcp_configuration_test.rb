require "test_helper"

class McpConfigurationTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: 'mcp_test@example.com',
      password: 'password123'
    )
    @instance = nil # instances not defined
  end

  test "should validate presence of required fields" do
    config = McpConfiguration.new
    assert_not config.valid?
    assert_includes config.errors[:owner], "must exist"
    assert_includes config.errors[:name], "can't be blank"
    assert_includes config.errors[:server_type], "can't be blank"
    assert_includes config.errors[:server_config], "can't be blank"
  end

  test "should validate server type inclusion" do
    config = McpConfiguration.new(
      owner: @user,
      name: "Test Config",
      server_config: { command: "test" },
      server_type: "invalid"
    )
    assert_not config.valid?
    assert_includes config.errors[:server_type], "is not included in the list"
  end

  test "should create valid configuration for user" do
    config = McpConfiguration.new(
      owner: @user,
      name: "My Linear",
      server_type: "http",
      server_config: { 
        endpoint: "https://api.linear.app/mcp",
        headers: { "Authorization" => "Bearer test123" }
      },
      enabled: true
    )
    assert config.valid?
    assert config.save
  end

  test "should support polymorphic owner" do
    skip "Instance model not defined" unless defined?(Instance)
    
    config = McpConfiguration.create!(
      owner: @instance,
      name: "Instance Config",
      server_type: "stdio",
      server_config: { command: "mcp-server", args: ["--test"] }
    )
    
    assert_equal @instance, config.owner
    assert_equal "Instance", config.owner_type
  end

  test "should handle JSON serialization for server_config" do
    config = McpConfiguration.create!(
      owner: @user,
      name: "JSON Test",
      server_type: "http",
      server_config: { 
        endpoint: "https://test.com",
        headers: { "X-Test" => "value" }
      }
    )
    
    # Reload to test persistence
    config.reload
    assert_equal "https://test.com", config.server_config["endpoint"]
    assert_equal "value", config.server_config["headers"]["X-Test"]
  end

  test "active scope should return only enabled configurations" do
    enabled = McpConfiguration.create!(
      owner: @user,
      name: "Enabled",
      server_type: "http",
      server_config: { endpoint: "https://test.com" },
      enabled: true
    )
    
    disabled = McpConfiguration.create!(
      owner: @user,
      name: "Disabled",
      server_type: "http",
      server_config: { endpoint: "https://test.com" },
      enabled: false
    )
    
    active_configs = McpConfiguration.active
    assert_includes active_configs, enabled
    assert_not_includes active_configs, disabled
  end

  test "for_user scope should return user configurations" do
    user_config = McpConfiguration.create!(
      owner: @user,
      name: "User Config",
      server_type: "http",
      server_config: { endpoint: "https://test.com" }
    )
    
    other_user = User.create!(
      email: 'other_mcp_test@example.com',
      password: 'password123'
    )
    other_config = McpConfiguration.create!(
      owner: other_user,
      name: "Other Config",
      server_type: "http",
      server_config: { endpoint: "https://test.com" }
    )
    
    user_configs = McpConfiguration.for_user(@user)
    assert_includes user_configs, user_config
    assert_not_includes user_configs, other_config
  end

  test "to_mcp_json should format configuration for MCP" do
    config = McpConfiguration.new(
      name: "Test Server",
      server_type: "stdio",
      server_config: {
        command: "mcp-linear",
        args: ["--api-key", "test"],
        env: { "DEBUG" => "true" }
      }
    )
    
    json = config.to_mcp_json
    assert_equal "Test Server", json[:name]
    assert_equal "stdio", json[:transport][:type]
    assert_equal "mcp-linear", json[:transport][:command]
    assert_equal ["--api-key", "test"], json[:transport][:args]
    assert_equal({ "DEBUG" => "true" }, json[:transport][:env])
  end

  test "for_claude_code should include all fields" do
    config = McpConfiguration.new(
      name: "Claude Test",
      server_type: "http",
      server_config: {
        endpoint: "https://api.test.com",
        headers: { "X-API-Key" => "secret" }
      }
    )
    
    claude_config = config.for_claude_code
    assert_equal "Claude Test", claude_config[:name]
    assert_equal "http", claude_config[:transport][:type]
    assert_equal "https://api.test.com", claude_config[:transport][:endpoint]
    assert_equal({ "X-API-Key" => "secret" }, claude_config[:transport][:headers])
  end

  test "for_assistant should return minimal config for HTTP" do
    config = McpConfiguration.new(
      name: "Assistant Test",
      server_type: "http",
      server_config: {
        endpoint: "https://api.test.com",
        headers: { "Authorization" => "Bearer token" }
      }
    )
    
    assistant_config = config.for_assistant
    assert_equal "Assistant Test", assistant_config[:name]
    assert_equal "http", assistant_config[:server_type]
    assert_equal({ use_existing_client: true }, assistant_config[:config])
  end

  test "for_assistant should indicate bridge needed for stdio" do
    config = McpConfiguration.new(
      name: "Stdio Test",
      server_type: "stdio",
      server_config: { command: "test-server" }
    )
    
    assistant_config = config.for_assistant
    assert_equal "stdio", assistant_config[:server_type]
    assert_equal true, assistant_config[:config][:bridge_required]
    assert_not_nil assistant_config[:config][:message]
  end

  test "bridge_available? should return false for stdio" do
    stdio_config = McpConfiguration.new(server_type: "stdio")
    http_config = McpConfiguration.new(server_type: "http")
    
    assert_not stdio_config.bridge_available?
    assert http_config.bridge_available?
  end

  test "should handle metadata properly" do
    config = McpConfiguration.create!(
      owner: @user,
      name: "Metadata Test",
      server_type: "http",
      server_config: { endpoint: "https://test.com" },
      metadata: {
        "template_key" => "github",
        "custom_field" => "value"
      }
    )
    
    config.reload
    assert_equal "github", config.metadata["template_key"]
    assert_equal "value", config.metadata["custom_field"]
  end
end