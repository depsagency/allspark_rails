require "test_helper"

class McpTemplateTest < ActiveSupport::TestCase
  test "should validate key uniqueness" do
    # Create first template
    template1 = McpTemplate.create!(
      key: "unique_key",
      name: "Test Template",
      config_template: { server_type: "http" }
    )
    
    # Try to create duplicate
    template2 = McpTemplate.new(
      key: "unique_key",
      name: "Another Template",
      config_template: { server_type: "http" }
    )
    
    assert_not template2.valid?
    assert_includes template2.errors[:key], "has already been taken"
  end

  test "should validate presence of required fields" do
    template = McpTemplate.new
    assert_not template.valid?
    assert_includes template.errors[:key], "can't be blank"
    assert_includes template.errors[:name], "can't be blank"
    assert_includes template.errors[:config_template], "can't be blank"
  end

  test "TEMPLATES constant should contain all built-in templates" do
    expected_keys = [:linear, :github, :filesystem, :google_drive, :postgres, :http_server, :websocket_server]
    
    expected_keys.each do |key|
      assert McpTemplate::TEMPLATES.key?(key), "Missing template: #{key}"
      template = McpTemplate::TEMPLATES[key]
      
      assert template[:name].present?, "Template #{key} missing name"
      assert template[:config_template].present?, "Template #{key} missing config_template"
    end
  end

  test "instantiate_configuration should create configuration from template" do
    template = McpTemplate.create!(
      key: "test_template",
      name: "Test Template",
      description: "A test template",
      config_template: {
        endpoint: "https://api.example.com/{{API_KEY}}"
      },
      required_fields: ["API_KEY"]
    )
    
    config = template.instantiate_configuration(
      name: "My Test Config",
      API_KEY: "secret123"
    )
    
    assert_equal "My Test Config", config.name
    assert_equal "http", config.server_type
    assert_equal "https://api.example.com/secret123", config.server_config["endpoint"]
    assert_includes config.metadata, "template_key"
    assert_equal "test_template", config.metadata["template_key"]
  end

  test "should validate required fields using helper methods" do
    template = McpTemplate.new(
      key: "test",
      name: "Test",
      config_template: { server_type: "http" },
      required_fields: ["API_KEY", "SECRET"]
    )
    
    # Test missing_fields method
    missing = template.missing_fields("API_KEY" => "present")
    assert_includes missing, "SECRET"
    assert_not_includes missing, "API_KEY"
    
    # Test valid_params? method
    assert_not template.valid_params?("API_KEY" => "present")
    assert template.valid_params?("API_KEY" => "present", "SECRET" => "also_present")
  end

  test "instantiate_configuration should handle nested replacements" do
    template = McpTemplate.new(
      key: "nested",
      name: "Nested Template",
      config_template: {
        endpoint: "https://{{DOMAIN}}/api",
        headers: {
          "Authorization" => "Bearer {{TOKEN}}",
          "X-Client-Id" => "{{CLIENT_ID}}"
        }
      },
      required_fields: ["DOMAIN", "TOKEN", "CLIENT_ID"]
    )
    
    config = template.instantiate_configuration(
      name: "Nested Config",
      DOMAIN: "example.com",
      TOKEN: "abc123",
      CLIENT_ID: "client-456"
    )
    
    assert_equal "https://example.com/api", config.server_config["endpoint"]
    assert_equal "Bearer abc123", config.server_config["headers"]["Authorization"]
    assert_equal "client-456", config.server_config["headers"]["X-Client-Id"]
  end

  test "template categories should be valid" do
    valid_categories = %w[productivity development communication custom]
    
    McpTemplate::TEMPLATES.each do |key, template|
      if template[:category]
        assert_includes valid_categories, template[:category],
          "Template #{key} has invalid category: #{template[:category]}"
      end
    end
  end

  test "linear template should be properly configured" do
    linear = McpTemplate::TEMPLATES["linear"]
    
    assert_equal "Linear", linear[:name]
    assert_equal "productivity", linear[:category]
    assert_equal "stdio", linear[:config_template][:server_type]
    assert_equal "npx", linear[:config_template][:server_config][:command]
    assert_includes linear[:config_template][:server_config][:args], "@modelcontextprotocol/server-linear"
    assert_includes linear[:required_fields], "LINEAR_API_KEY"
  end

  test "github template should be properly configured" do
    github = McpTemplate::TEMPLATES["github"]
    
    assert_equal "GitHub", github[:name]
    assert_equal "development", github[:category]
    assert_equal "stdio", github[:config_template][:server_type]
    assert_includes github[:required_fields], "GITHUB_TOKEN"
  end

  test "create_from_template should work with TEMPLATES constant" do
    user = User.create!(
      email: 'template_test@example.com',
      password: 'password123'
    )
    
    McpTemplate::TEMPLATES.each do |key, template_data|
      template = McpTemplate.new(
        key: key,
        name: template_data[:name],
        description: template_data[:description],
        config_template: template_data[:config_template],
        required_fields: template_data[:required_fields] || [],
        category: template_data[:category],
        icon_url: template_data[:icon_url],
        documentation_url: template_data[:documentation_url]
      )
      
      # Create params for required fields
      params = {}
      template.required_fields.each do |field|
        params[field] = "test_value_#{field.downcase}"
      end
      
      # Should not raise error
      config = template.instantiate_configuration(
        params.merge(name: "Test #{template.name}")
      )
      
      assert config.valid?, "Config from #{key} template should be valid: #{config.errors.full_messages}"
    end
  end
end