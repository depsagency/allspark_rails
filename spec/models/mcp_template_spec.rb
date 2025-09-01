require 'rails_helper'

RSpec.describe McpTemplate, type: :model do
  describe 'validations' do
    it 'validates key uniqueness' do
      template1 = create(:mcp_template, key: "unique_key")
      template2 = build(:mcp_template, key: "unique_key")
      
      expect(template2).not_to be_valid
      expect(template2.errors[:key]).to include("has already been taken")
    end

    it 'validates presence of required fields' do
      template = McpTemplate.new
      expect(template).not_to be_valid
      expect(template.errors[:key]).to include("can't be blank")
      expect(template.errors[:name]).to include("can't be blank")
      expect(template.errors[:config_template]).to include("can't be blank")
    end
  end

  describe 'TEMPLATES constant' do
    it 'contains all built-in templates' do
      expected_keys = %w[linear github slack filesystem custom_http docker postgres redis]
      
      expected_keys.each do |key|
        expect(McpTemplate::TEMPLATES).to have_key(key)
        template = McpTemplate::TEMPLATES[key]
        
        expect(template[:name]).to be_present
        expect(template[:config_template]).to be_present
      end
    end

    it 'has valid categories for all templates' do
      valid_categories = %w[productivity development communication custom]
      
      McpTemplate::TEMPLATES.each do |key, template|
        if template[:category]
          expect(valid_categories).to include(template[:category])
        end
      end
    end
  end

  describe '#instantiate_config' do
    let(:template) { create(:mcp_template) }
    let(:user) { create(:user) }

    it 'creates configuration from template' do
      config = template.instantiate_config(
        owner: user,
        name: "My Test Config",
        params: { "API_KEY" => "secret123" }
      )
      
      expect(config.owner).to eq(user)
      expect(config.name).to eq("My Test Config")
      expect(config.server_type).to eq("http")
      expect(config.server_config["endpoint"]).to eq("https://api.example.com/secret123")
      expect(config.metadata).to eq({ "template_key" => template.key })
    end

    it 'validates required fields' do
      expect {
        template.instantiate_config(
          owner: user,
          name: "Test",
          params: {}
        )
      }.to raise_error(ArgumentError, /Missing required fields: API_KEY/)
    end

    it 'handles nested replacements' do
      template = create(:mcp_template, :http)
      
      config = template.instantiate_config(
        owner: user,
        name: "Nested Config",
        params: {
          "DOMAIN" => "example.com",
          "API_TOKEN" => "abc123",
          "CLIENT_ID" => "client-456"
        }
      )
      
      expect(config.server_config["endpoint"]).to eq("https://example.com/mcp")
      expect(config.server_config["headers"]["Authorization"]).to eq("Bearer abc123")
      expect(config.server_config["headers"]["X-Client-Id"]).to eq("client-456")
    end

    it 'works with no required fields' do
      template = create(:mcp_template, :no_required_fields)
      
      config = template.instantiate_config(
        owner: user,
        name: "Public Config",
        params: {}
      )
      
      expect(config).to be_valid
      expect(config.server_config["endpoint"]).to eq("https://public-api.example.com/mcp")
    end
  end

  describe 'built-in templates' do
    describe 'linear template' do
      let(:linear) { McpTemplate::TEMPLATES["linear"] }
      
      it 'is properly configured' do
        expect(linear[:name]).to eq("Linear")
        expect(linear[:category]).to eq("productivity")
        expect(linear[:config_template][:server_type]).to eq("stdio")
        expect(linear[:config_template][:server_config][:command]).to eq("npx")
        expect(linear[:config_template][:server_config][:args]).to include("@modelcontextprotocol/server-linear")
        expect(linear[:required_fields]).to include("LINEAR_API_KEY")
      end
    end

    describe 'github template' do
      let(:github) { McpTemplate::TEMPLATES["github"] }
      
      it 'is properly configured' do
        expect(github[:name]).to eq("GitHub")
        expect(github[:category]).to eq("development")
        expect(github[:config_template][:server_type]).to eq("stdio")
        expect(github[:required_fields]).to include("GITHUB_TOKEN")
      end
    end
  end

  describe 'template instantiation with TEMPLATES' do
    let(:user) { create(:user) }

    it 'can create configs from all built-in templates' do
      McpTemplate::TEMPLATES.each do |key, template_data|
        template = McpTemplate.new(
          key: key,
          name: template_data[:name],
          description: template_data[:description],
          config_template: template_data[:config_template],
          required_fields: template_data[:required_fields] || [],
          category: template_data[:category]
        )
        
        # Create params for required fields
        params = {}
        template.required_fields.each do |field|
          params[field] = "test_value_#{field.downcase}"
        end
        
        config = template.instantiate_config(
          owner: user,
          name: "Test #{template.name}",
          params: params
        )
        
        expect(config).to be_valid
        expect(config.metadata["template_key"]).to eq(key)
      end
    end
  end
end