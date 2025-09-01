require 'rails_helper'

RSpec.describe McpConfiguration, type: :model do
  let(:user) { create(:user) }
  let(:instance) { Instance.first || create(:instance) if defined?(Instance) }

  describe 'validations' do
    it 'validates presence of required fields' do
      config = McpConfiguration.new
      expect(config).not_to be_valid
      expect(config.errors[:owner]).to include("must exist")
      expect(config.errors[:name]).to include("can't be blank")
      expect(config.errors[:server_type]).to include("can't be blank")
      expect(config.errors[:server_config]).to include("can't be blank")
    end

    it 'validates server type inclusion' do
      config = McpConfiguration.new(
        owner: user,
        name: "Test Config",
        server_config: { command: "test" },
        server_type: "invalid"
      )
      expect(config).not_to be_valid
      expect(config.errors[:server_type]).to include("is not included in the list")
    end
  end

  describe 'creation' do
    it 'creates valid configuration for user' do
      config = McpConfiguration.new(
        owner: user,
        name: "My Linear",
        server_type: "http",
        server_config: { 
          endpoint: "https://api.linear.app/mcp",
          headers: { "Authorization" => "Bearer test123" }
        },
        enabled: true
      )
      expect(config).to be_valid
      expect(config.save).to be true
    end

    it 'supports polymorphic owner' do
      skip "Instance model not defined" unless defined?(Instance)
      
      config = McpConfiguration.create!(
        owner: instance,
        name: "Instance Config",
        server_type: "stdio",
        server_config: { command: "mcp-server", args: ["--test"] }
      )
      
      expect(config.owner).to eq(instance)
      expect(config.owner_type).to eq("Instance")
    end
  end

  describe 'JSON serialization' do
    it 'handles JSON serialization for server_config' do
      config = McpConfiguration.create!(
        owner: user,
        name: "JSON Test",
        server_type: "http",
        server_config: { 
          endpoint: "https://test.com",
          headers: { "X-Test" => "value" }
        }
      )
      
      # Reload to test persistence
      config.reload
      expect(config.server_config["endpoint"]).to eq("https://test.com")
      expect(config.server_config["headers"]["X-Test"]).to eq("value")
    end
  end

  describe 'scopes' do
    let!(:enabled_config) do
      McpConfiguration.create!(
        owner: user,
        name: "Enabled",
        server_type: "http",
        server_config: { endpoint: "https://test.com" },
        enabled: true
      )
    end

    let!(:disabled_config) do
      McpConfiguration.create!(
        owner: user,
        name: "Disabled",
        server_type: "http",
        server_config: { endpoint: "https://test.com" },
        enabled: false
      )
    end

    it 'active scope returns only enabled configurations' do
      active_configs = McpConfiguration.active
      expect(active_configs).to include(enabled_config)
      expect(active_configs).not_to include(disabled_config)
    end

    it 'for_user scope returns user configurations' do
      other_user = create(:user)
      other_config = McpConfiguration.create!(
        owner: other_user,
        name: "Other Config",
        server_type: "http",
        server_config: { endpoint: "https://test.com" }
      )
      
      user_configs = McpConfiguration.for_user(user)
      expect(user_configs).to include(enabled_config)
      expect(user_configs).to include(disabled_config)
      expect(user_configs).not_to include(other_config)
    end
  end

  describe '#to_mcp_json' do
    it 'formats configuration for MCP' do
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
      expect(json[:name]).to eq("Test Server")
      expect(json[:transport][:type]).to eq("stdio")
      expect(json[:transport][:command]).to eq("mcp-linear")
      expect(json[:transport][:args]).to eq(["--api-key", "test"])
      expect(json[:transport][:env]).to eq({ "DEBUG" => "true" })
    end
  end

  describe '#for_claude_code' do
    it 'includes all fields' do
      config = McpConfiguration.new(
        name: "Claude Test",
        server_type: "http",
        server_config: {
          endpoint: "https://api.test.com",
          headers: { "X-API-Key" => "secret" }
        }
      )
      
      claude_config = config.for_claude_code
      expect(claude_config[:name]).to eq("Claude Test")
      expect(claude_config[:transport][:type]).to eq("http")
      expect(claude_config[:transport][:endpoint]).to eq("https://api.test.com")
      expect(claude_config[:transport][:headers]).to eq({ "X-API-Key" => "secret" })
    end
  end

  describe '#for_assistant' do
    it 'returns minimal config for HTTP' do
      config = McpConfiguration.new(
        name: "Assistant Test",
        server_type: "http",
        server_config: {
          endpoint: "https://api.test.com",
          headers: { "Authorization" => "Bearer token" }
        }
      )
      
      assistant_config = config.for_assistant
      expect(assistant_config[:name]).to eq("Assistant Test")
      expect(assistant_config[:server_type]).to eq("http")
      expect(assistant_config[:config]).to eq({ use_existing_client: true })
    end

    it 'indicates bridge needed for stdio' do
      config = McpConfiguration.new(
        name: "Stdio Test",
        server_type: "stdio",
        server_config: { command: "test-server" }
      )
      
      assistant_config = config.for_assistant
      expect(assistant_config[:server_type]).to eq("stdio")
      expect(assistant_config[:config][:bridge_required]).to be true
      expect(assistant_config[:config][:message]).not_to be_nil
    end
  end

  describe '#bridge_available?' do
    it 'returns false for stdio' do
      stdio_config = McpConfiguration.new(server_type: "stdio")
      http_config = McpConfiguration.new(server_type: "http")
      
      expect(stdio_config.bridge_available?).to be false
      expect(http_config.bridge_available?).to be true
    end
  end

  describe 'metadata' do
    it 'handles metadata properly' do
      config = McpConfiguration.create!(
        owner: user,
        name: "Metadata Test",
        server_type: "http",
        server_config: { endpoint: "https://test.com" },
        metadata: {
          "template_key" => "github",
          "custom_field" => "value"
        }
      )
      
      config.reload
      expect(config.metadata["template_key"]).to eq("github")
      expect(config.metadata["custom_field"]).to eq("value")
    end
  end
end