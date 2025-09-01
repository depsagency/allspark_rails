module McpConnection
  class OauthConnection < Base
    TOKEN_REFRESH_BUFFER = 5.minutes

    def initialize(mcp_server)
      super
      @access_token = mcp_server.credentials&.dig('access_token')
      @refresh_token = mcp_server.credentials&.dig('refresh_token')
      @token_expires_at = mcp_server.credentials&.dig('expires_at')&.to_time
      
      raise AuthenticationError, "OAuth tokens not configured" if @access_token.blank?
    end

    def connect
      ensure_valid_token
      @connected = true
      Rails.logger.debug "[MCP] Connected to #{@mcp_server.name} with OAuth authentication"
      true
    end

    def disconnect
      @connected = false
      Rails.logger.debug "[MCP] Disconnected from #{@mcp_server.name}"
      true
    end

    def authenticated?
      @access_token.present? && !token_expired?
    end

    def send_request(payload)
      ensure_valid_token
      
      request = build_authenticated_request(payload)
      
      Timeout.timeout(@timeout) do
        response = http_client.request(request)
        handle_http_response(response)
      end
    rescue Timeout::Error
      raise TimeoutError, "Request timed out after #{@timeout} seconds"
    rescue => e
      raise ConnectionError, "HTTP request failed: #{e.message}"
    end

    def refresh_token!
      return unless @refresh_token.present?
      
      Rails.logger.info "[MCP] Refreshing OAuth token for server #{@mcp_server.id}"
      
      refresh_payload = {
        grant_type: 'refresh_token',
        refresh_token: @refresh_token,
        client_id: @mcp_server.config&.dig('client_id'),
        client_secret: @mcp_server.config&.dig('client_secret')
      }
      
      token_endpoint = @mcp_server.config&.dig('token_endpoint')
      raise AuthenticationError, "Token endpoint not configured" if token_endpoint.blank?
      
      response = post_token_request(token_endpoint, refresh_payload)
      token_data = JSON.parse(response)
      
      update_tokens(token_data)
      
      Rails.logger.info "[MCP] Successfully refreshed OAuth token for server #{@mcp_server.id}"
    rescue => e
      Rails.logger.error "[MCP] Failed to refresh OAuth token for server #{@mcp_server.id}: #{e.message}"
      raise AuthenticationError, "Token refresh failed: #{e.message}"
    end

    def revoke_token!
      return unless @access_token.present?
      
      revoke_endpoint = @mcp_server.config&.dig('revoke_endpoint')
      return unless revoke_endpoint.present?
      
      Rails.logger.info "[MCP] Revoking OAuth token for server #{@mcp_server.id}"
      
      revoke_payload = {
        token: @access_token,
        token_type_hint: 'access_token'
      }
      
      post_token_request(revoke_endpoint, revoke_payload)
      clear_tokens
      
      Rails.logger.info "[MCP] Successfully revoked OAuth token for server #{@mcp_server.id}"
    rescue => e
      Rails.logger.warn "[MCP] Failed to revoke OAuth token for server #{@mcp_server.id}: #{e.message}"
      clear_tokens # Clear tokens anyway
    end

    protected

    def health_check
      super
      
      # Ensure token is valid and make a test request
      ensure_valid_token
      
      test_payload = {
        jsonrpc: "2.0",
        id: SecureRandom.uuid,
        method: "ping",
        params: {}
      }
      
      send_request(test_payload)
      true
    rescue => e
      raise ConnectionError, "Health check failed: #{e.message}"
    end

    private

    def ensure_valid_token
      if token_expired? || token_expires_soon?
        refresh_token!
      end
    end

    def token_expired?
      return false if @token_expires_at.nil?
      
      @token_expires_at <= Time.current
    end

    def token_expires_soon?
      return false if @token_expires_at.nil?
      
      @token_expires_at <= (Time.current + TOKEN_REFRESH_BUFFER)
    end

    def build_authenticated_request(payload)
      path = URI.parse(@mcp_server.endpoint).path.presence || '/'
      request = build_request('POST', path, payload)
      
      request['Authorization'] = "Bearer #{@access_token}"
      
      # Add any additional headers from config
      if @mcp_server.config&.dig('headers').is_a?(Hash)
        @mcp_server.config['headers'].each do |key, value|
          request[key] = value
        end
      end
      
      request
    end

    def handle_http_response(response)
      case response.code.to_i
      when 200..299
        response.body
      when 401
        # Try to refresh token once if we get unauthorized
        if @refresh_token.present? && !@token_refresh_attempted
          @token_refresh_attempted = true
          refresh_token!
          raise AuthenticationError, "Token expired, refresh attempted"
        else
          raise AuthenticationError, "Invalid or expired OAuth token"
        end
      when 403
        raise AuthenticationError, "OAuth token lacks required permissions"
      when 429
        retry_after = response['Retry-After']&.to_i || 60
        raise RateLimitError, "Rate limit exceeded. Retry after #{retry_after} seconds"
      when 408, 504
        raise TimeoutError, "Server timeout"
      when 500..599
        raise ConnectionError, "Server error: #{response.code} #{response.message}"
      else
        raise ConnectionError, "Unexpected response: #{response.code} #{response.message}"
      end
    end

    def post_token_request(endpoint, payload)
      uri = URI.parse(endpoint)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = endpoint.start_with?('https')
      
      request = Net::HTTP::Post.new(uri.path)
      request['Content-Type'] = 'application/x-www-form-urlencoded'
      request.body = URI.encode_www_form(payload)
      
      response = http.request(request)
      
      case response.code.to_i
      when 200..299
        response.body
      when 400
        error_data = JSON.parse(response.body) rescue {}
        raise AuthenticationError, "OAuth error: #{error_data['error_description'] || error_data['error'] || 'Bad request'}"
      when 401
        raise AuthenticationError, "OAuth authentication failed"
      else
        raise ConnectionError, "Token request failed: #{response.code} #{response.message}"
      end
    end

    def update_tokens(token_data)
      credentials = @mcp_server.credentials.dup
      credentials['access_token'] = token_data['access_token']
      credentials['refresh_token'] = token_data['refresh_token'] if token_data['refresh_token']
      
      if token_data['expires_in']
        credentials['expires_at'] = (Time.current + token_data['expires_in'].to_i.seconds).iso8601
      end
      
      @mcp_server.update!(credentials: credentials)
      
      # Update instance variables
      @access_token = credentials['access_token']
      @refresh_token = credentials['refresh_token']
      @token_expires_at = credentials['expires_at']&.to_time
      @token_refresh_attempted = false
    end

    def clear_tokens
      credentials = @mcp_server.credentials.dup
      credentials.delete('access_token')
      credentials.delete('refresh_token')
      credentials.delete('expires_at')
      
      @mcp_server.update!(credentials: credentials)
      
      @access_token = nil
      @refresh_token = nil
      @token_expires_at = nil
    end
  end
end