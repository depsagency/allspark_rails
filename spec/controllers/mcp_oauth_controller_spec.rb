# frozen_string_literal: true

require 'rails_helper'

RSpec.describe McpOauthController, type: :controller do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:instance) { create(:instance) }
  let(:oauth_config) do
    {
      'oauth' => {
        'client_id' => 'test_client_id',
        'client_secret' => 'test_client_secret',
        'authorization_endpoint' => 'https://example.com/oauth/authorize',
        'token_endpoint' => 'https://example.com/oauth/token',
        'scope' => 'read write'
      }
    }
  end

  before do
    sign_in user
  end

  describe 'GET #authorize' do
    context 'with system-wide server' do
      let(:mcp_server) { create(:mcp_server, auth_type: :oauth, config: oauth_config) }

      it 'redirects to OAuth provider with correct parameters' do
        get :authorize, params: { server_id: mcp_server.id }
        
        expect(response).to have_http_status(:redirect)
        redirect_location = URI.parse(response.location)
        redirect_params = Rack::Utils.parse_query(redirect_location.query)
        
        expect(redirect_location.host).to eq('example.com')
        expect(redirect_location.path).to eq('/oauth/authorize')
        expect(redirect_params['client_id']).to eq('test_client_id')
        expect(redirect_params['response_type']).to eq('code')
        expect(redirect_params['scope']).to eq('read write')
        expect(redirect_params['state']).to be_present
        expect(redirect_params['redirect_uri']).to include(mcp_oauth_callback_path(mcp_server))
      end

      it 'stores OAuth state in cache' do
        get :authorize, params: { server_id: mcp_server.id }
        
        redirect_location = URI.parse(response.location)
        redirect_params = Rack::Utils.parse_query(redirect_location.query)
        state = redirect_params['state']
        
        cached_data = Rails.cache.read("oauth_state_#{state}")
        expect(cached_data).to include(
          user_id: user.id,
          server_id: mcp_server.id
        )
      end
    end

    context 'with user-specific server' do
      let(:mcp_server) { create(:mcp_server, :user_scoped, user: user, auth_type: :oauth, config: oauth_config) }

      it 'allows access to own server' do
        get :authorize, params: { server_id: mcp_server.id }
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'with user-specific server owned by another user' do
      let(:other_user) { create(:user) }
      let(:mcp_server) { create(:mcp_server, :user_scoped, user: other_user, auth_type: :oauth, config: oauth_config) }

      it 'denies access' do
        get :authorize, params: { server_id: mcp_server.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('Access denied')
      end
    end

    context 'with non-OAuth server' do
      let(:mcp_server) { create(:mcp_server, auth_type: :api_key) }

      it 'redirects with error' do
        get :authorize, params: { server_id: mcp_server.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('does not use OAuth')
      end
    end

    context 'with incomplete OAuth config' do
      let(:incomplete_config) { { 'oauth' => { 'client_id' => 'test' } } }
      let(:mcp_server) { create(:mcp_server, auth_type: :oauth, config: incomplete_config) }

      it 'redirects with error' do
        get :authorize, params: { server_id: mcp_server.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('OAuth configuration is incomplete')
      end
    end
  end

  describe 'GET #callback' do
    let(:mcp_server) { create(:mcp_server, auth_type: :oauth, config: oauth_config) }
    let(:state) { SecureRandom.hex(32) }
    let(:code) { 'test_authorization_code' }

    before do
      Rails.cache.write("oauth_state_#{state}", {
        user_id: user.id,
        server_id: mcp_server.id,
        redirect_to: nil
      })
    end

    context 'with successful authorization' do
      let(:token_response) do
        {
          'access_token' => 'test_access_token',
          'refresh_token' => 'test_refresh_token',
          'token_type' => 'Bearer',
          'expires_in' => 3600,
          'scope' => 'read write'
        }
      end

      before do
        allow_any_instance_of(McpOauthController).to receive(:exchange_code_for_token).and_return(token_response)
        allow_any_instance_of(McpOauthController).to receive(:test_server_connection).and_return({ success: true })
      end

      it 'stores OAuth credentials and updates server status' do
        get :callback, params: { server_id: mcp_server.id, state: state, code: code }
        
        mcp_server.reload
        credentials = mcp_server.credentials
        
        expect(credentials['access_token']).to eq('test_access_token')
        expect(credentials['refresh_token']).to eq('test_refresh_token')
        expect(credentials['token_type']).to eq('Bearer')
        expect(credentials['scope']).to eq('read write')
        expect(mcp_server.status).to eq('active')
        
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to include('OAuth authentication successful')
      end

      it 'schedules tool discovery job' do
        expect(McpToolDiscoveryJob).to receive(:perform_later).with(mcp_server.id, force: true)
        get :callback, params: { server_id: mcp_server.id, state: state, code: code }
      end

      it 'cleans up OAuth state from cache' do
        get :callback, params: { server_id: mcp_server.id, state: state, code: code }
        expect(Rails.cache.read("oauth_state_#{state}")).to be_nil
      end
    end

    context 'with authorization error' do
      it 'handles access_denied error' do
        get :callback, params: { 
          server_id: mcp_server.id, 
          state: state, 
          error: 'access_denied',
          error_description: 'User denied access'
        }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('OAuth access was denied')
      end
    end

    context 'with invalid state' do
      it 'rejects request with error' do
        get :callback, params: { server_id: mcp_server.id, state: 'invalid_state', code: code }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('Invalid OAuth state')
      end
    end

    context 'with missing authorization code' do
      it 'redirects with error' do
        get :callback, params: { server_id: mcp_server.id, state: state }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('OAuth authorization was not completed')
      end
    end

    context 'when connection test fails' do
      let(:token_response) do
        {
          'access_token' => 'test_access_token',
          'refresh_token' => 'test_refresh_token',
          'token_type' => 'Bearer',
          'expires_in' => 3600
        }
      end

      before do
        allow_any_instance_of(McpOauthController).to receive(:exchange_code_for_token).and_return(token_response)
        allow_any_instance_of(McpOauthController).to receive(:test_server_connection).and_return({ 
          success: false, 
          error: 'Connection failed' 
        })
      end

      it 'stores credentials but shows warning' do
        get :callback, params: { server_id: mcp_server.id, state: state, code: code }
        
        mcp_server.reload
        expect(mcp_server.credentials['access_token']).to eq('test_access_token')
        expect(flash[:alert]).to include('OAuth authentication completed but connection test failed')
      end
    end
  end

  describe 'DELETE #disconnect' do
    let(:credentials) do
      {
        'access_token' => 'test_access_token',
        'refresh_token' => 'test_refresh_token',
        'token_type' => 'Bearer',
        'expires_at' => 1.hour.from_now.iso8601,
        'scope' => 'read write'
      }
    end
    let(:mcp_server) { create(:mcp_server, auth_type: :oauth, config: oauth_config, credentials: credentials, status: :active) }

    it 'clears OAuth credentials and deactivates server' do
      allow_any_instance_of(McpOauthController).to receive(:revoke_oauth_token)
      allow(McpConnectionManager.instance).to receive(:release_connection)

      delete :disconnect, params: { server_id: mcp_server.id }
      
      mcp_server.reload
      expect(mcp_server.credentials['access_token']).to be_nil
      expect(mcp_server.credentials['refresh_token']).to be_nil
      expect(mcp_server.status).to eq('inactive')
      
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to include('OAuth authentication has been disconnected')
    end

    it 'releases server connections' do
      expect(McpConnectionManager.instance).to receive(:release_connection).with(mcp_server)
      delete :disconnect, params: { server_id: mcp_server.id }
    end

    context 'with non-OAuth server' do
      let(:mcp_server) { create(:mcp_server, auth_type: :api_key) }

      it 'redirects with error' do
        delete :disconnect, params: { server_id: mcp_server.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('does not use OAuth')
      end
    end
  end
end