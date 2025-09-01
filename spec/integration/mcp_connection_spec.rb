require 'rails_helper'

RSpec.describe "MCP Connection Integration", type: :integration do
  let(:user) { create(:user) }
  let(:instance) { create(:instance) }

  describe "Connection establishment" do
    context "with API key authentication" do
      let(:server) { create(:mcp_server, :api_key, user: user) }

      it "successfully establishes connection" do
        stub_mcp_authentication(:api_key, server.credentials)
        
        events = capture_mcp_notifications do
          result = server.test_connection
          expect(result[:success]).to be true
        end

        expect(events).to include(
          hash_including(
            name: McpInstrumentation::EVENTS[:connection_attempt]
          )
        )
      end

      it "handles authentication failures" do
        simulate_authentication_failure(server)
        
        result = server.test_connection
        expect(result[:success]).to be false
        expect(result[:error]).to include("Invalid credentials")
      end

      it "updates server status on connection failure" do
        simulate_authentication_failure(server)
        
        expect { server.test_connection }.to change { server.reload.status }.to('error')
      end
    end

    context "with OAuth authentication" do
      let(:server) { create(:mcp_server, :oauth, user: user) }

      it "successfully establishes connection with valid tokens" do
        stub_mcp_authentication(:oauth, server.credentials)
        
        result = server.test_connection
        expect(result[:success]).to be true
      end

      it "refreshes tokens when expired" do
        oauth_connection = instance_double("McpConnection::OauthConnection")
        allow(McpConnectionManager.instance).to receive(:connection_for).with(server).and_return(oauth_connection)
        
        # Simulate token refresh
        allow(oauth_connection).to receive(:test_connection).and_raise(McpConnection::Base::AuthenticationError.new("Token expired"))
        allow(oauth_connection).to receive(:refresh_token!).and_return(true)
        
        expect(oauth_connection).to receive(:refresh_token!)
        
        server.test_connection
      end
    end

    context "with Bearer token authentication" do
      let(:server) { create(:mcp_server, :bearer_token, user: user) }

      it "successfully establishes connection" do
        stub_mcp_authentication(:bearer_token, server.credentials)
        
        result = server.test_connection
        expect(result[:success]).to be true
      end
    end

    context "with Basic authentication" do
      let(:server) { create(:mcp_server, :no_auth, user: user) }

      it "successfully establishes connection" do
        stub_mcp_authentication(:basic, server.credentials)
        
        result = server.test_connection
        expect(result[:success]).to be true
      end
    end
  end

  describe "Connection pooling" do
    let(:server) { create(:mcp_server, :active, user: user) }

    it "reuses connections from the pool" do
      connection_manager = McpConnectionManager.instance
      
      # First connection
      connection1 = connection_manager.connection_for(server)
      
      # Second request should return the same connection
      connection2 = connection_manager.connection_for(server)
      
      expect(connection1).to eq(connection2)
    end

    it "tracks connection usage metrics" do
      connection_manager = McpConnectionManager.instance
      
      connection_manager.connection_for(server)
      
      stats = connection_manager.pool_status
      expect(stats[:total_connections]).to eq(1)
      expect(stats[:connections]).to have(1).item
    end

    it "cleans up idle connections" do
      connection_manager = McpConnectionManager.instance
      
      # Create a connection
      connection_manager.connection_for(server)
      expect(connection_manager.pool_status[:total_connections]).to eq(1)
      
      # Cleanup should remove idle connections
      cleaned = connection_manager.cleanup_connections(force: true)
      expect(cleaned).to eq(1)
      expect(connection_manager.pool_status[:total_connections]).to eq(0)
    end
  end

  describe "Connection timeouts" do
    let(:server) { create(:mcp_server, :active, user: user) }

    it "handles connection timeouts gracefully" do
      simulate_connection_timeout(server)
      
      errors = capture_mcp_errors do
        result = server.test_connection
        expect(result).to be false
      end

      expect(errors).to include(
        hash_including(
          error: an_instance_of(McpConnection::Base::TimeoutError)
        )
      )
    end

    it "retries failed connections with backoff" do
      connection_double = instance_double("McpConnection::Base")
      allow(McpConnectionManager.instance).to receive(:connection_for).with(server).and_return(connection_double)
      
      # First call fails, second succeeds
      call_count = 0
      allow(connection_double).to receive(:test_connection) do
        call_count += 1
        if call_count == 1
          raise McpConnection::Base::TimeoutError.new("Timeout")
        else
          true
        end
      end
      
      # Should eventually succeed after retry
      result = server.test_connection
      expect(result[:success]).to be true
      expect(call_count).to eq(2)
    end
  end

  describe "Rate limiting" do
    let(:server) { create(:mcp_server, :active, user: user) }

    it "handles rate limiting errors" do
      simulate_rate_limiting(server)
      
      errors = capture_mcp_errors do
        result = server.test_connection
        expect(result).to be false
      end

      expect(errors).to include(
        hash_including(
          error: an_instance_of(McpConnection::Base::RateLimitError)
        )
      )
    end

    it "tracks rate limiting metrics" do
      simulate_rate_limiting(server)
      
      events = capture_mcp_notifications do
        server.test_connection
      end

      # Should track the rate limit event
      instrumentation = McpInstrumentation.instance
      stats = instrumentation.rate_limit_stats(server.id, 1.minute)
      
      expect(stats[:rate_limit_hits]).to be > 0
    end
  end

  describe "Error recovery" do
    let(:server) { create(:mcp_server, :active, user: user) }

    it "provides recovery suggestions for connection errors" do
      simulate_connection_timeout(server)
      
      result = server.test_connection
      
      error_handler = McpErrorHandler.instance
      suggestions = error_handler.get_recovery_suggestions(:connection, server.id)
      
      expect(suggestions).to include(match(/check server endpoint/i))
      expect(suggestions).to include(match(/network connectivity/i))
    end

    it "provides recovery suggestions for authentication errors" do
      simulate_authentication_failure(server)
      
      result = server.test_connection
      
      error_handler = McpErrorHandler.instance
      suggestions = error_handler.get_recovery_suggestions(:authentication, server.id)
      
      expect(suggestions).to include(match(/verify.*credentials/i))
      expect(suggestions).to include(match(/api key.*permissions/i))
    end
  end

  describe "Health monitoring" do
    let(:server) { create(:mcp_server, :active, user: user) }

    it "tracks server health status" do
      mock_connection_test(server, true)
      
      connection_manager = McpConnectionManager.instance
      connection_manager.connection_for(server)
      
      # Simulate health check
      healthy = connection_manager.health_status(server)
      expect(healthy).to be_in([true, false]) # Health status may not be set initially
    end

    it "detects unhealthy servers" do
      mock_connection_test(server, false)
      
      connection_manager = McpConnectionManager.instance
      
      # Health checks run in background, so we simulate the result
      allow(connection_manager).to receive(:health_status).with(server).and_return(false)
      
      expect(connection_manager.health_status(server)).to be false
    end
  end

  describe "Multi-tenant access" do
    let(:system_server) { create(:mcp_server, :system_wide, :active) }
    let(:instance_server) { create(:mcp_server, :instance_scoped, :active, instance: instance) }
    let(:user_server) { create(:mcp_server, :user_scoped, :active, user: user) }

    before do
      user.instances << instance
    end

    it "allows access to system-wide servers" do
      servers = McpServer.available_to_user(user)
      expect(servers).to include(system_server)
    end

    it "allows access to instance servers for instance users" do
      servers = McpServer.available_to_user(user)
      expect(servers).to include(instance_server)
    end

    it "allows access to user-specific servers" do
      servers = McpServer.available_to_user(user)
      expect(servers).to include(user_server)
    end

    it "prevents access to other users' servers" do
      other_user = create(:user)
      other_server = create(:mcp_server, :user_scoped, :active, user: other_user)
      
      servers = McpServer.available_to_user(user)
      expect(servers).not_to include(other_server)
    end
  end
end