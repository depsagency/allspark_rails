require 'rails_helper'

RSpec.describe McpServer, type: :model do
  let(:user) { create(:user) }
  let(:instance) { create(:instance) }

  describe 'associations' do
    it { should belong_to(:user).optional }
    it { should belong_to(:instance).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:endpoint) }
    it { should validate_presence_of(:protocol_version) }

    describe 'uniqueness validations' do
      context 'when instance_id is present' do
        it 'validates uniqueness of name scoped to instance' do
          create(:mcp_server, name: 'Test Server', instance: instance)
          duplicate = build(:mcp_server, name: 'Test Server', instance: instance)
          
          expect(duplicate).not_to be_valid
          expect(duplicate.errors[:name]).to include('has already been taken')
        end

        it 'allows same name in different instances' do
          other_instance = create(:instance)
          create(:mcp_server, name: 'Test Server', instance: instance)
          duplicate = build(:mcp_server, name: 'Test Server', instance: other_instance)
          
          expect(duplicate).to be_valid
        end
      end

      context 'when user_id is present and instance_id is nil' do
        it 'validates uniqueness of name scoped to user' do
          create(:mcp_server, name: 'Test Server', user: user, instance: nil)
          duplicate = build(:mcp_server, name: 'Test Server', user: user, instance: nil)
          
          expect(duplicate).not_to be_valid
          expect(duplicate.errors[:name]).to include('has already been taken')
        end

        it 'allows same name for different users' do
          other_user = create(:user)
          create(:mcp_server, name: 'Test Server', user: user, instance: nil)
          duplicate = build(:mcp_server, name: 'Test Server', user: other_user, instance: nil)
          
          expect(duplicate).to be_valid
        end
      end
    end
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(inactive: 0, active: 1, error: 2) }
    it { should define_enum_for(:auth_type).with_values(none: 0, api_key: 1, oauth: 2, bearer_token: 3) }
  end

  describe 'JSON serialization' do
    let(:server) { create(:mcp_server) }

    it 'serializes config as JSON' do
      config = { 'timeout' => 30, 'retries' => 3 }
      server.update(config: config)
      
      expect(server.reload.config).to eq(config)
    end

    it 'serializes credentials as JSON' do
      credentials = { 'api_key' => 'secret-key', 'endpoint' => 'https://api.example.com' }
      server.update(credentials: credentials)
      
      expect(server.reload.credentials).to eq(credentials)
    end
  end

  describe 'scopes' do
    let!(:system_server) { create(:mcp_server, :system_wide) }
    let!(:instance_server) { create(:mcp_server, :instance_scoped, instance: instance) }
    let!(:user_server) { create(:mcp_server, :user_scoped, user: user) }

    describe '.available_to_user' do
      it 'includes system-wide servers' do
        expect(McpServer.available_to_user(user)).to include(system_server)
      end

      it 'includes user-specific servers' do
        expect(McpServer.available_to_user(user)).to include(user_server)
      end

      it 'includes servers from user instances' do
        user.instances << instance
        expect(McpServer.available_to_user(user)).to include(instance_server)
      end
    end

    describe '.available_to_instance' do
      it 'includes system-wide servers' do
        expect(McpServer.available_to_instance(instance)).to include(system_server)
      end

      it 'includes instance-specific servers' do
        expect(McpServer.available_to_instance(instance)).to include(instance_server)
      end
    end

    describe '.system_wide' do
      it 'returns only system-wide servers' do
        expect(McpServer.system_wide).to contain_exactly(system_server)
      end
    end

    describe '.by_status' do
      let!(:active_server) { create(:mcp_server, status: :active) }
      let!(:inactive_server) { create(:mcp_server, status: :inactive) }

      it 'filters by status' do
        expect(McpServer.by_status(:active)).to include(active_server)
        expect(McpServer.by_status(:active)).not_to include(inactive_server)
      end
    end
  end

  describe 'callbacks' do
    describe 'before_validation :set_defaults' do
      let(:server) { build(:mcp_server, protocol_version: nil, status: nil, auth_type: nil, config: nil, credentials: nil) }

      it 'sets default values' do
        server.valid?
        
        expect(server.protocol_version).to eq('1.0')
        expect(server.status).to eq('inactive')
        expect(server.auth_type).to eq('none')
        expect(server.config).to eq({})
        expect(server.credentials).to eq({})
      end
    end

    describe 'after_save :clear_tools_cache' do
      let(:server) { create(:mcp_server) }

      it 'clears the tools cache when server is updated' do
        # Set up cache
        cache_key = "mcp_server_#{server.id}_tools"
        Rails.cache.write(cache_key, ['tool1', 'tool2'])
        
        # Update server
        server.update(name: 'New Name')
        
        # Cache should be cleared
        expect(Rails.cache.read(cache_key)).to be_nil
      end
    end
  end

  describe '#available_tools' do
    let(:server) { create(:mcp_server, :active) }

    before do
      # Mock the McpClient
      allow(McpClient).to receive(:new).with(server).and_return(double(discover_tools: ['tool1', 'tool2']))
    end

    it 'caches the result for 5 minutes' do
      expect(Rails.cache).to receive(:fetch).with("mcp_server_#{server.id}_tools", expires_in: 5.minutes)
      
      server.available_tools
    end

    it 'calls fetch_tools_from_server' do
      expect(server).to receive(:fetch_tools_from_server).and_return(['tool1', 'tool2'])
      
      server.available_tools
    end
  end

  describe '#test_connection' do
    let(:server) { create(:mcp_server) }
    let(:mock_client) { double('McpClient') }

    before do
      allow(McpClient).to receive(:new).with(server).and_return(mock_client)
    end

    context 'when connection is successful' do
      before do
        allow(mock_client).to receive(:test_connection).and_return(true)
      end

      it 'returns success' do
        result = server.test_connection
        expect(result).to be_truthy
      end
    end

    context 'when connection fails' do
      before do
        allow(mock_client).to receive(:test_connection).and_raise(StandardError.new('Connection failed'))
      end

      it 'updates status to error' do
        expect { server.test_connection }.to change { server.reload.status }.to('error')
      end

      it 'returns failure with error message' do
        result = server.test_connection
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Connection failed')
      end
    end
  end

  describe '#clear_tools_cache' do
    let(:server) { create(:mcp_server) }

    it 'deletes the tools cache' do
      cache_key = "mcp_server_#{server.id}_tools"
      Rails.cache.write(cache_key, ['tool1', 'tool2'])
      
      server.clear_tools_cache
      
      expect(Rails.cache.read(cache_key)).to be_nil
    end
  end

  describe 'private methods' do
    describe '#fetch_tools_from_server' do
      let(:server) { create(:mcp_server, :active) }
      let(:mock_client) { double('McpClient') }

      before do
        allow(McpClient).to receive(:new).with(server).and_return(mock_client)
      end

      context 'when server is not active' do
        let(:server) { create(:mcp_server, :inactive) }

        it 'returns empty array' do
          result = server.send(:fetch_tools_from_server)
          expect(result).to eq([])
        end
      end

      context 'when tool discovery is successful' do
        before do
          allow(mock_client).to receive(:discover_tools).and_return(['tool1', 'tool2'])
        end

        it 'returns discovered tools' do
          result = server.send(:fetch_tools_from_server)
          expect(result).to eq(['tool1', 'tool2'])
        end

        it 'updates status to active if was inactive' do
          server.update(status: :inactive)
          expect { server.send(:fetch_tools_from_server) }.to change { server.reload.status }.to('active')
        end
      end

      context 'when tool discovery fails' do
        before do
          allow(mock_client).to receive(:discover_tools).and_raise(StandardError.new('Discovery failed'))
          allow(Rails.logger).to receive(:error)
        end

        it 'logs the error' do
          expect(Rails.logger).to receive(:error).with("Failed to fetch tools from MCP server #{server.id}: Discovery failed")
          
          server.send(:fetch_tools_from_server)
        end

        it 'updates status to error' do
          expect { server.send(:fetch_tools_from_server) }.to change { server.reload.status }.to('error')
        end

        it 'returns empty array' do
          result = server.send(:fetch_tools_from_server)
          expect(result).to eq([])
        end
      end
    end
  end
end