require 'rails_helper'

RSpec.describe McpServerMigrator, type: :service do
  let(:user) { create(:user) }
  
  describe '#migrate!' do
    context 'with valid HTTP server' do
      let(:server) do
        create(:mcp_server,
          user: user,
          name: "HTTP Server",
          transport_type: "http",
          url: "https://api.example.com/mcp",
          enabled: true,
          auth_type: "bearer",
          auth_config: { "token" => "secret123" }
        )
      end
      
      it 'creates configuration from server' do
        migrator = McpServerMigrator.new(server)
        config = migrator.migrate!
        
        expect(config).to be_persisted
        expect(config.name).to eq("HTTP Server")
        expect(config.server_type).to eq("http")
        expect(config.server_config["endpoint"]).to eq("https://api.example.com/mcp")
        expect(config.server_config["headers"]["Authorization"]).to eq("Bearer secret123")
        expect(config.enabled).to be true
      end
      
      it 'marks server as migrated' do
        migrator = McpServerMigrator.new(server)
        migrator.migrate!
        
        server.reload
        expect(server.migrated_at).not_to be_nil
      end
      
      it 'adds migration metadata' do
        migrator = McpServerMigrator.new(server)
        config = migrator.migrate!
        
        expect(config.metadata["migrated_from_server_id"]).to eq(server.id)
        expect(config.metadata["migrated_at"]).to be_present
        expect(config.metadata["original_transport"]).to eq("http")
      end
    end
    
    context 'with stdio server' do
      let(:server) do
        create(:mcp_server,
          user: user,
          name: "Stdio Server",
          transport_type: "stdio",
          connection_config: {
            "command" => "mcp-server",
            "args" => ["--port", "3000"],
            "env" => { "DEBUG" => "true" }
          }
        )
      end
      
      it 'converts stdio configuration' do
        migrator = McpServerMigrator.new(server)
        config = migrator.migrate!
        
        expect(config.server_type).to eq("stdio")
        expect(config.server_config["command"]).to eq("mcp-server")
        expect(config.server_config["args"]).to eq(["--port", "3000"])
        expect(config.server_config["env"]).to eq({ "DEBUG" => "true" })
      end
    end
    
    context 'with different auth types' do
      it 'handles API key auth' do
        server = create(:mcp_server,
          user: user,
          auth_type: "api_key",
          auth_config: {
            "header_name" => "X-API-Key",
            "api_key" => "key123"
          }
        )
        
        migrator = McpServerMigrator.new(server)
        config = migrator.migrate!
        
        expect(config.server_config["headers"]["X-API-Key"]).to eq("key123")
      end
      
      it 'handles basic auth' do
        server = create(:mcp_server,
          user: user,
          auth_type: "basic",
          auth_config: {
            "username" => "user",
            "password" => "pass"
          }
        )
        
        migrator = McpServerMigrator.new(server)
        config = migrator.migrate!
        
        encoded = Base64.strict_encode64("user:pass")
        expect(config.server_config["headers"]["Authorization"]).to eq("Basic #{encoded}")
      end
      
      it 'handles custom auth' do
        server = create(:mcp_server,
          user: user,
          auth_type: "custom",
          auth_config: {
            "headers" => {
              "X-Custom-Header" => "value",
              "X-Another-Header" => "another"
            }
          }
        )
        
        migrator = McpServerMigrator.new(server)
        config = migrator.migrate!
        
        expect(config.server_config["headers"]["X-Custom-Header"]).to eq("value")
        expect(config.server_config["headers"]["X-Another-Header"]).to eq("another")
      end
    end
    
    context 'with polymorphic owner' do
      let(:server) do
        create(:mcp_server,
          owner_type: "User",
          owner_id: user.id,
          user_id: nil,
          name: "Polymorphic Server"
        )
      end
      
      it 'uses polymorphic owner' do
        migrator = McpServerMigrator.new(server)
        config = migrator.migrate!
        
        expect(config.owner).to eq(user)
        expect(config.owner_type).to eq("User")
      end
    end
  end
  
  describe '#can_migrate?' do
    let(:server) { create(:mcp_server, user: user, name: "Test Server") }
    
    it 'returns true for valid server' do
      migrator = McpServerMigrator.new(server)
      expect(migrator.can_migrate?).to be true
    end
    
    it 'returns false if already migrated' do
      server.update_column(:migrated_at, Time.current)
      
      migrator = McpServerMigrator.new(server)
      expect(migrator.can_migrate?).to be false
      expect(migrator.errors).to include(/already migrated/)
    end
    
    it 'returns false if configuration with same name exists' do
      create(:mcp_configuration, owner: user, name: "Test Server")
      
      migrator = McpServerMigrator.new(server)
      expect(migrator.can_migrate?).to be false
      expect(migrator.errors).to include(/already exists/)
    end
    
    it 'returns false for stdio without command' do
      server = build(:mcp_server,
        user: user,
        transport_type: "stdio",
        connection_config: {}
      )
      
      migrator = McpServerMigrator.new(server)
      expect(migrator.can_migrate?).to be false
      expect(migrator.errors).to include(/missing command/)
    end
    
    it 'returns false for http without URL' do
      server = build(:mcp_server,
        user: user,
        transport_type: "http",
        url: nil,
        connection_config: {}
      )
      
      migrator = McpServerMigrator.new(server)
      expect(migrator.can_migrate?).to be false
      expect(migrator.errors).to include(/missing endpoint/)
    end
  end
end