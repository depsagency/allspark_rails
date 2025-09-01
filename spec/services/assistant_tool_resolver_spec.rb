require 'rails_helper'

RSpec.describe AssistantToolResolver, type: :service do
  let(:assistant) { create(:assistant) }
  let(:user) { assistant.user }
  
  describe '#resolve_tools' do
    context 'with no configurations' do
      it 'returns empty array' do
        resolver = AssistantToolResolver.new(assistant)
        expect(resolver.resolve_tools).to eq([])
      end
    end
    
    context 'with HTTP configuration' do
      let!(:http_config) do
        create(:mcp_configuration,
          owner: user,
          name: "HTTP Server",
          server_type: "http",
          enabled: true
        )
      end
      
      it 'marks as using existing client' do
        resolver = AssistantToolResolver.new(assistant)
        tools = resolver.resolve_tools
        
        expect(tools.length).to eq(1)
        tool = tools.first
        expect(tool[:name]).to eq("HTTP Server")
        expect(tool[:type]).to eq(:existing_client)
        expect(tool[:config][:use_existing_client]).to be true
      end
    end
    
    context 'with stdio configuration' do
      let!(:stdio_config) do
        create(:mcp_configuration,
          owner: user,
          name: "Stdio Server",
          server_type: "stdio",
          enabled: true
        )
      end
      
      it 'marks as requiring bridge' do
        resolver = AssistantToolResolver.new(assistant)
        tools = resolver.resolve_tools
        
        expect(tools.length).to eq(1)
        tool = tools.first
        expect(tool[:name]).to eq("Stdio Server")
        expect(tool[:type]).to eq(:bridge_required)
        expect(tool[:config][:bridge_required]).to be true
        expect(tool[:config][:message]).to include("bridge service")
      end
    end
    
    context 'with mixed configurations' do
      let!(:http_config) { create(:mcp_configuration, :http, owner: user, enabled: true) }
      let!(:stdio_config) { create(:mcp_configuration, :stdio, owner: user, enabled: true) }
      let!(:websocket_config) { create(:mcp_configuration, :websocket, owner: user, enabled: true) }
      let!(:disabled_config) { create(:mcp_configuration, :disabled, owner: user) }
      
      it 'resolves all enabled configurations appropriately' do
        resolver = AssistantToolResolver.new(assistant)
        tools = resolver.resolve_tools
        
        expect(tools.length).to eq(3) # Only enabled ones
        
        # Check each type is handled correctly
        http_tool = tools.find { |t| t[:config][:server_type] == "http" }
        stdio_tool = tools.find { |t| t[:config][:server_type] == "stdio" }
        websocket_tool = tools.find { |t| t[:config][:server_type] == "websocket" }
        
        expect(http_tool[:type]).to eq(:existing_client)
        expect(stdio_tool[:type]).to eq(:bridge_required)
        expect(websocket_tool[:type]).to eq(:existing_client)
      end
    end
    
    context 'with legacy MCP servers' do
      let!(:legacy_server) do
        create(:mcp_server,
          user: user,
          name: "Legacy Server",
          transport_type: "http",
          enabled: true,
          migrated_at: nil
        )
      end
      
      it 'includes legacy servers in results' do
        resolver = AssistantToolResolver.new(assistant)
        tools = resolver.resolve_tools
        
        legacy_tool = tools.find { |t| t[:name] == "Legacy Server" }
        expect(legacy_tool).not_to be_nil
        expect(legacy_tool[:type]).to eq(:legacy)
        expect(legacy_tool[:server]).to eq(legacy_server)
      end
    end
  end
  
  describe '#load_tools_for_assistant' do
    let!(:http_config) { create(:mcp_configuration, owner: user, enabled: true) }
    
    it 'attempts to load tools for HTTP configs' do
      # Mock the MCP client behavior
      mock_server = double("server")
      allow(McpCompatibilityLayer).to receive(:configuration_to_server).and_return(mock_server)
      
      mock_client = double("client")
      allow(McpClient).to receive(:new).with(mock_server).and_return(mock_client)
      allow(mock_client).to receive(:tools).and_return([
        { "name" => "test_tool", "description" => "Test tool" }
      ])
      
      resolver = AssistantToolResolver.new(assistant)
      resolver.load_tools_for_assistant
      
      # Verify it tried to load tools
      expect(McpClient).to have_received(:new)
    end
    
    it 'handles errors gracefully' do
      allow_any_instance_of(McpClient).to receive(:tools).and_raise(StandardError, "Connection failed")
      
      resolver = AssistantToolResolver.new(assistant)
      
      # Should not raise error
      expect { resolver.load_tools_for_assistant }.not_to raise_error
    end
  end
end