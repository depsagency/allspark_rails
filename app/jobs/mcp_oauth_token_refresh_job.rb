# frozen_string_literal: true

class McpOauthTokenRefreshJob < ApplicationJob
  queue_as :default

  # Retry with exponential backoff for temporary failures
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(server_id)
    server = McpServer.find(server_id)
    
    unless server.auth_type == 'oauth'
      Rails.logger.warn "[MCP OAuth Refresh] Server #{server_id} is not configured for OAuth"
      return
    end

    credentials = server.credentials || {}
    refresh_token = credentials['refresh_token']
    
    unless refresh_token.present?
      Rails.logger.error "[MCP OAuth Refresh] No refresh token available for server #{server_id}"
      # Mark server as requiring re-authentication
      server.update!(status: 'error')
      return
    end

    # Check if token needs refresh (expires within next 5 minutes)
    expires_at = credentials['expires_at']
    if expires_at && Time.parse(expires_at) > 5.minutes.from_now
      Rails.logger.info "[MCP OAuth Refresh] Token for server #{server_id} does not need refresh yet"
      return
    end

    begin
      new_credentials = refresh_access_token(server, refresh_token)
      
      if new_credentials
        # Update server with new credentials
        updated_credentials = credentials.merge(new_credentials)
        server.update!(
          credentials: updated_credentials,
          status: 'active'
        )
        
        # Test connection with new token
        test_result = test_connection(server)
        
        if test_result[:success]
          Rails.logger.info "[MCP OAuth Refresh] Successfully refreshed token for server #{server_id}"
          
          # Schedule tool discovery to ensure tools are up to date
          McpToolDiscoveryJob.perform_later(server_id)
          
          # Schedule next refresh
          schedule_next_refresh(server, updated_credentials)
        else
          Rails.logger.error "[MCP OAuth Refresh] Connection test failed after token refresh for server #{server_id}: #{test_result[:error]}"
          server.update!(status: 'error')
        end
      else
        Rails.logger.error "[MCP OAuth Refresh] Failed to refresh token for server #{server_id}"
        server.update!(status: 'error')
      end
      
    rescue => e
      Rails.logger.error "[MCP OAuth Refresh] Error refreshing token for server #{server_id}: #{e.message}"
      server.update!(status: 'error')
      raise e
    end
  end

  private

  def refresh_access_token(server, refresh_token)
    oauth_config = server.config&.dig('oauth') || {}
    
    unless oauth_config['token_endpoint'].present? && oauth_config['client_id'].present?
      Rails.logger.error "[MCP OAuth Refresh] Missing OAuth configuration for server #{server.id}"
      return nil
    end

    refresh_params = {
      grant_type: 'refresh_token',
      refresh_token: refresh_token,
      client_id: oauth_config['client_id']
    }

    # Add client secret if configured
    if oauth_config['client_secret'].present?
      refresh_params[:client_secret] = oauth_config['client_secret']
    end

    response = HTTP.timeout(30)
                  .headers('Accept' => 'application/json', 'Content-Type' => 'application/x-www-form-urlencoded')
                  .post(oauth_config['token_endpoint'], form: refresh_params)

    if response.status.success?
      token_data = JSON.parse(response.body.to_s)
      
      {
        access_token: token_data['access_token'],
        refresh_token: token_data['refresh_token'] || refresh_token, # Some providers don't return new refresh token
        token_type: token_data['token_type'] || 'Bearer',
        expires_at: calculate_expires_at(token_data['expires_in']),
        scope: token_data['scope']
      }.compact
    else
      Rails.logger.error "[MCP OAuth Refresh] Token refresh failed: #{response.status} - #{response.body}"
      nil
    end
  end

  def test_connection(server)
    begin
      client = McpClient.new(server)
      client.test_connection
      { success: true }
    rescue => e
      { success: false, error: e.message }
    end
  end

  def calculate_expires_at(expires_in)
    return nil unless expires_in

    Time.current + expires_in.to_i.seconds
  end

  def schedule_next_refresh(server, credentials)
    expires_at = credentials['expires_at']
    return unless expires_at

    # Schedule refresh 10 minutes before expiration
    refresh_at = Time.parse(expires_at) - 10.minutes
    
    # Don't schedule if it's in the past or too soon
    return if refresh_at <= Time.current

    McpOauthTokenRefreshJob.set(wait_until: refresh_at).perform_later(server.id)
  end
end