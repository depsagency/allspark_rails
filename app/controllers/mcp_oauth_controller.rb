# frozen_string_literal: true

class McpOauthController < ApplicationController
  before_action :authenticate_user!
  before_action :set_mcp_server, only: [:authorize, :callback, :disconnect]
  before_action :ensure_server_access, only: [:authorize, :callback, :disconnect]

  # GET /mcp_oauth/:server_id/authorize
  def authorize
    unless @mcp_server.auth_type == 'oauth'
      redirect_to redirect_path, alert: 'This server does not use OAuth authentication.'
      return
    end

    # Generate and store OAuth state
    state = SecureRandom.hex(32)
    Rails.cache.write("oauth_state_#{state}", {
      user_id: current_user.id,
      server_id: @mcp_server.id,
      redirect_to: params[:redirect_to]
    }, expires_in: 10.minutes)

    # Build OAuth authorization URL
    auth_url = build_authorization_url(state)
    
    if auth_url
      redirect_to auth_url, allow_other_host: true
    else
      redirect_to redirect_path, alert: 'OAuth configuration is incomplete for this server.'
    end
  end

  # GET /mcp_oauth/:server_id/callback
  def callback
    # Validate state parameter
    state = params[:state]
    state_data = Rails.cache.read("oauth_state_#{state}")
    
    unless state_data && state_data[:user_id] == current_user.id && state_data[:server_id] == @mcp_server.id
      redirect_to redirect_path, alert: 'Invalid OAuth state. Please try again.'
      return
    end

    # Clean up state
    Rails.cache.delete("oauth_state_#{state}")

    # Handle authorization response
    if params[:error]
      handle_oauth_error(params[:error], params[:error_description])
      return
    end

    unless params[:code]
      redirect_to redirect_path, alert: 'OAuth authorization was not completed successfully.'
      return
    end

    # Exchange code for token
    begin
      token_response = exchange_code_for_token(params[:code])
      
      if token_response && token_response['access_token']
        # Store OAuth credentials
        oauth_credentials = {
          access_token: token_response['access_token'],
          refresh_token: token_response['refresh_token'],
          token_type: token_response['token_type'] || 'Bearer',
          expires_at: calculate_expires_at(token_response['expires_in']),
          scope: token_response['scope']
        }

        @mcp_server.update!(
          credentials: @mcp_server.credentials.merge(oauth_credentials),
          status: 'active'
        )

        # Test the connection with new credentials
        test_result = test_server_connection
        
        if test_result[:success]
          # Schedule tool discovery
          McpToolDiscoveryJob.perform_later(@mcp_server.id, force: true)
          
          redirect_to redirect_path(state_data[:redirect_to]), 
                     notice: 'OAuth authentication successful! Server is now connected.'
        else
          redirect_to redirect_path(state_data[:redirect_to]), 
                     alert: "OAuth authentication completed but connection test failed: #{test_result[:error]}"
        end
      else
        redirect_to redirect_path(state_data[:redirect_to]), 
                   alert: 'Failed to obtain access token from OAuth provider.'
      end
    rescue => e
      Rails.logger.error "[MCP OAuth] Token exchange failed for server #{@mcp_server.id}: #{e.message}"
      redirect_to redirect_path(state_data[:redirect_to]), 
                 alert: 'OAuth token exchange failed. Please try again.'
    end
  end

  # DELETE /mcp_oauth/:server_id/disconnect
  def disconnect
    unless @mcp_server.auth_type == 'oauth'
      redirect_to redirect_path, alert: 'This server does not use OAuth authentication.'
      return
    end

    # Revoke OAuth token if possible
    begin
      revoke_oauth_token if @mcp_server.credentials&.dig('access_token')
    rescue => e
      Rails.logger.warn "[MCP OAuth] Token revocation failed for server #{@mcp_server.id}: #{e.message}"
    end

    # Clear OAuth credentials
    @mcp_server.update!(
      credentials: @mcp_server.credentials.except('access_token', 'refresh_token', 'token_type', 'expires_at', 'scope'),
      status: 'inactive'
    )

    # Clean up connections
    McpConnectionManager.instance.release_connection(@mcp_server)

    redirect_to redirect_path, notice: 'OAuth authentication has been disconnected.'
  end

  private

  def set_mcp_server
    @mcp_server = McpServer.find(params[:server_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: 'MCP server not found.'
  end

  def ensure_server_access
    # Check if user has access to this server
    case @mcp_server.scope
    when 'system'
      # System servers are accessible to all users
      return true
    when 'instance'
      # Instance servers are accessible to instance members
      unless @mcp_server.instance && current_user.instance_users.exists?(instance: @mcp_server.instance)
        redirect_to root_path, alert: 'Access denied to this MCP server.'
        return false
      end
    when 'user'
      # User servers are only accessible to the owner
      unless @mcp_server.user_id == current_user.id
        redirect_to root_path, alert: 'Access denied to this MCP server.'
        return false
      end
    end
    
    true
  end

  def build_authorization_url(state)
    oauth_config = @mcp_server.config&.dig('oauth') || {}
    
    required_fields = %w[client_id authorization_endpoint]
    return nil unless required_fields.all? { |field| oauth_config[field].present? }

    params = {
      client_id: oauth_config['client_id'],
      redirect_uri: mcp_oauth_callback_url(@mcp_server),
      response_type: 'code',
      state: state,
      scope: oauth_config['scope'] || 'read'
    }

    uri = URI(oauth_config['authorization_endpoint'])
    uri.query = params.to_query
    uri.to_s
  end

  def exchange_code_for_token(code)
    oauth_config = @mcp_server.config&.dig('oauth') || {}
    
    return nil unless oauth_config['token_endpoint'].present? && oauth_config['client_id'].present?

    token_params = {
      grant_type: 'authorization_code',
      code: code,
      redirect_uri: mcp_oauth_callback_url(@mcp_server),
      client_id: oauth_config['client_id']
    }

    # Add client secret if configured
    if oauth_config['client_secret'].present?
      token_params[:client_secret] = oauth_config['client_secret']
    end

    response = HTTP.timeout(30)
                  .headers('Accept' => 'application/json', 'Content-Type' => 'application/x-www-form-urlencoded')
                  .post(oauth_config['token_endpoint'], form: token_params)

    if response.status.success?
      JSON.parse(response.body.to_s)
    else
      Rails.logger.error "[MCP OAuth] Token exchange failed: #{response.status} - #{response.body}"
      nil
    end
  end

  def revoke_oauth_token
    oauth_config = @mcp_server.config&.dig('oauth') || {}
    access_token = @mcp_server.credentials&.dig('access_token')
    
    return unless oauth_config['revocation_endpoint'].present? && access_token

    revoke_params = {
      token: access_token,
      token_type_hint: 'access_token'
    }

    # Add client credentials if configured
    if oauth_config['client_id'].present?
      revoke_params[:client_id] = oauth_config['client_id']
      revoke_params[:client_secret] = oauth_config['client_secret'] if oauth_config['client_secret'].present?
    end

    HTTP.timeout(30)
        .headers('Content-Type' => 'application/x-www-form-urlencoded')
        .post(oauth_config['revocation_endpoint'], form: revoke_params)
  end

  def calculate_expires_at(expires_in)
    return nil unless expires_in

    Time.current + expires_in.to_i.seconds
  end

  def test_server_connection
    begin
      client = McpClient.new(@mcp_server)
      client.test_connection
      { success: true }
    rescue => e
      { success: false, error: e.message }
    end
  end

  def handle_oauth_error(error, description)
    error_message = case error
    when 'access_denied'
      'OAuth access was denied. Please authorize the application to continue.'
    when 'invalid_request'
      'Invalid OAuth request. Please try again.'
    when 'unsupported_response_type'
      'Unsupported OAuth response type. Please contact support.'
    when 'invalid_scope'
      'Invalid OAuth scope requested. Please contact support.'
    when 'server_error'
      'OAuth server error. Please try again later.'
    when 'temporarily_unavailable'
      'OAuth service is temporarily unavailable. Please try again later.'
    else
      "OAuth error: #{error}#{description ? " - #{description}" : ''}"
    end

    redirect_to redirect_path, alert: error_message
  end

  def redirect_path(custom_path = nil)
    return custom_path if custom_path.present?

    case @mcp_server&.scope
    when 'system'
      admin_mcp_servers_path
    when 'instance'
      mcp_servers_instance_settings_path(@mcp_server.instance)
    when 'user'
      mcp_servers_user_path(@mcp_server.user)
    else
      root_path
    end
  end
end