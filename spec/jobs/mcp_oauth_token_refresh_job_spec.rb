# frozen_string_literal: true

require 'rails_helper'

RSpec.describe McpOauthTokenRefreshJob, type: :job do
  let(:oauth_config) do
    {
      'oauth' => {
        'client_id' => 'test_client_id',
        'client_secret' => 'test_client_secret',
        'token_endpoint' => 'https://example.com/oauth/token'
      }
    }
  end

  let(:credentials) do
    {
      'access_token' => 'old_access_token',
      'refresh_token' => 'test_refresh_token',
      'token_type' => 'Bearer',
      'expires_at' => 2.minutes.from_now.iso8601,
      'scope' => 'read write'
    }
  end

  let(:mcp_server) do
    create(:mcp_server, 
           auth_type: :oauth, 
           config: oauth_config, 
           credentials: credentials,
           status: :active)
  end

  describe '#perform' do
    context 'with valid refresh token' do
      let(:new_token_response) do
        {
          'access_token' => 'new_access_token',
          'refresh_token' => 'new_refresh_token',
          'token_type' => 'Bearer',
          'expires_in' => 3600,
          'scope' => 'read write'
        }
      end

      before do
        stub_request(:post, 'https://example.com/oauth/token')
          .with(
            body: hash_including(
              'grant_type' => 'refresh_token',
              'refresh_token' => 'test_refresh_token',
              'client_id' => 'test_client_id',
              'client_secret' => 'test_client_secret'
            )
          )
          .to_return(
            status: 200,
            body: new_token_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        allow_any_instance_of(McpOauthTokenRefreshJob).to receive(:test_connection).and_return({ success: true })
      end

      it 'refreshes the access token' do
        expect(McpToolDiscoveryJob).to receive(:perform_later).with(mcp_server.id)

        described_class.new.perform(mcp_server.id)

        mcp_server.reload
        expect(mcp_server.credentials['access_token']).to eq('new_access_token')
        expect(mcp_server.credentials['refresh_token']).to eq('new_refresh_token')
        expect(mcp_server.status).to eq('active')
      end

      it 'schedules tool discovery after successful refresh' do
        expect(McpToolDiscoveryJob).to receive(:perform_later).with(mcp_server.id)
        described_class.new.perform(mcp_server.id)
      end

      it 'logs successful refresh' do
        expect(Rails.logger).to receive(:info).with(/Successfully refreshed token/)
        described_class.new.perform(mcp_server.id)
      end

      context 'when token does not need refresh yet' do
        let(:credentials) do
          {
            'access_token' => 'current_token',
            'refresh_token' => 'test_refresh_token',
            'expires_at' => 10.minutes.from_now.iso8601
          }
        end

        it 'skips refresh and logs info' do
          expect(Rails.logger).to receive(:info).with(/does not need refresh yet/)
          expect(McpToolDiscoveryJob).not_to receive(:perform_later)
          
          described_class.new.perform(mcp_server.id)
        end
      end
    end

    context 'with failed token refresh' do
      before do
        stub_request(:post, 'https://example.com/oauth/token')
          .to_return(status: 400, body: { error: 'invalid_grant' }.to_json)
      end

      it 'marks server as error status' do
        expect(Rails.logger).to receive(:error).with(/Failed to refresh token/)
        
        described_class.new.perform(mcp_server.id)
        
        mcp_server.reload
        expect(mcp_server.status).to eq('error')
      end
    end

    context 'with connection test failure after refresh' do
      let(:new_token_response) do
        {
          'access_token' => 'new_access_token',
          'refresh_token' => 'new_refresh_token',
          'expires_in' => 3600
        }
      end

      before do
        stub_request(:post, 'https://example.com/oauth/token')
          .to_return(
            status: 200,
            body: new_token_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        allow_any_instance_of(McpOauthTokenRefreshJob).to receive(:test_connection)
          .and_return({ success: false, error: 'Connection failed' })
      end

      it 'updates token but marks server as error' do
        expect(Rails.logger).to receive(:error).with(/Connection test failed after token refresh/)
        
        described_class.new.perform(mcp_server.id)
        
        mcp_server.reload
        expect(mcp_server.credentials['access_token']).to eq('new_access_token')
        expect(mcp_server.status).to eq('error')
      end
    end

    context 'with missing refresh token' do
      let(:credentials) do
        {
          'access_token' => 'current_token',
          'token_type' => 'Bearer',
          'expires_at' => 2.minutes.from_now.iso8601
        }
      end

      it 'marks server as error and logs warning' do
        expect(Rails.logger).to receive(:error).with(/No refresh token available/)
        
        described_class.new.perform(mcp_server.id)
        
        mcp_server.reload
        expect(mcp_server.status).to eq('error')
      end
    end

    context 'with non-OAuth server' do
      let(:mcp_server) { create(:mcp_server, auth_type: :api_key) }

      it 'logs warning and returns early' do
        expect(Rails.logger).to receive(:warn).with(/Server .* is not configured for OAuth/)
        
        described_class.new.perform(mcp_server.id)
        
        expect(mcp_server.status).to eq('inactive') # unchanged
      end
    end

    context 'with network error' do
      before do
        stub_request(:post, 'https://example.com/oauth/token')
          .to_raise(HTTP::Error.new('Network error'))
      end

      it 'marks server as error and re-raises exception' do
        expect(Rails.logger).to receive(:error).with(/Error refreshing token/)
        
        expect {
          described_class.new.perform(mcp_server.id)
        }.to raise_error(HTTP::Error)
        
        mcp_server.reload
        expect(mcp_server.status).to eq('error')
      end
    end
  end

  describe 'scheduling next refresh' do
    let(:new_token_response) do
      {
        'access_token' => 'new_access_token',
        'refresh_token' => 'new_refresh_token',
        'expires_in' => 3600 # 1 hour
      }
    end

    before do
      stub_request(:post, 'https://example.com/oauth/token')
        .to_return(
          status: 200,
          body: new_token_response.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      allow_any_instance_of(McpOauthTokenRefreshJob).to receive(:test_connection).and_return({ success: true })
    end

    it 'schedules next refresh 10 minutes before expiration' do
      travel_to Time.current do
        expected_refresh_time = 50.minutes.from_now # 1 hour - 10 minutes

        expect(described_class).to receive(:set).with(wait_until: be_within(5.seconds).of(expected_refresh_time))
          .and_return(double(perform_later: nil))

        described_class.new.perform(mcp_server.id)
      end
    end
  end
end