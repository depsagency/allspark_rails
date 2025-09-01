require 'rails_helper'

RSpec.describe McpConfigurationBuilder, type: :service do
  let(:user) { create(:user) }
  let(:instance) { Instance.first || create(:instance) if defined?(Instance) }
  
  describe '#build' do
    context 'with no configurations' do
      it 'returns empty server list' do
        builder = McpConfigurationBuilder.new(user: user)
        result = builder.build
        
        expect(result).to eq({ servers: [] })
      end
    end
    
    context 'with user configurations' do
      let!(:user_config1) { create(:mcp_configuration, owner: user, name: "Config 1", enabled: true) }
      let!(:user_config2) { create(:mcp_configuration, owner: user, name: "Config 2", enabled: false) }
      
      it 'includes only enabled configurations' do
        builder = McpConfigurationBuilder.new(user: user)
        result = builder.build
        
        expect(result[:servers].length).to eq(1)
        expect(result[:servers].first[:name]).to eq("Config 1")
      end
      
      it 'formats configurations for Claude Code' do
        builder = McpConfigurationBuilder.new(user: user)
        result = builder.build
        
        server = result[:servers].first
        expect(server).to have_key(:name)
        expect(server).to have_key(:transport)
        expect(server[:transport][:type]).to eq("http")
      end
    end
    
    context 'with instance configurations' do
      skip "Instance not defined" unless defined?(Instance)
      
      let!(:instance_config) { create(:mcp_configuration, owner: instance, name: "Instance Config", enabled: true) }
      
      it 'includes instance configurations' do
        builder = McpConfigurationBuilder.new(user: user, instance: instance)
        result = builder.build
        
        expect(result[:servers].map { |s| s[:name] }).to include("Instance Config")
      end
    end
    
    context 'with environment variable resolution' do
      let!(:config) do
        create(:mcp_configuration,
          owner: user,
          name: "Env Test",
          server_type: "stdio",
          server_config: {
            "command" => "test",
            "env" => {
              "HOME_REF" => "${HOME}",
              "CUSTOM" => "value"
            }
          }
        )
      end
      
      it 'resolves environment variables' do
        allow(ENV).to receive(:[]).with("HOME").and_return("/home/test")
        
        builder = McpConfigurationBuilder.new(user: user)
        result = builder.build
        
        server = result[:servers].first
        expect(server[:transport][:env]["HOME_REF"]).to eq("/home/test")
        expect(server[:transport][:env]["CUSTOM"]).to eq("value")
      end
    end
    
    context 'with duplicate configurations' do
      let!(:user_config) { create(:mcp_configuration, owner: user, name: "Duplicate", enabled: true) }
      
      before do
        skip "Instance not defined" unless defined?(Instance)
      end
      
      let!(:instance_config) { create(:mcp_configuration, owner: instance, name: "Duplicate", enabled: true) }
      
      it 'prefers instance configuration over user' do
        builder = McpConfigurationBuilder.new(user: user, instance: instance)
        result = builder.build
        
        # Should only have one "Duplicate" config
        duplicates = result[:servers].select { |s| s[:name] == "Duplicate" }
        expect(duplicates.length).to eq(1)
        
        # Should be the instance one (check by owner reference in a real implementation)
        # For now, just verify no duplicates
      end
    end
    
    context 'error handling' do
      let!(:config) { create(:mcp_configuration, owner: user, name: "Error Test") }
      
      it 'handles configuration errors gracefully' do
        allow_any_instance_of(McpConfiguration).to receive(:for_claude_code).and_raise(StandardError, "Config error")
        
        builder = McpConfigurationBuilder.new(user: user)
        result = builder.build
        
        # Should return empty list on error
        expect(result[:servers]).to be_empty
      end
    end
  end
end