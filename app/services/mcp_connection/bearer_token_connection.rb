module McpConnection
  class BearerTokenConnection < Base
    def initialize(mcp_server)
      super
      @token = mcp_server.credentials&.dig('token')
      
      raise AuthenticationError, "Bearer token not configured" if @token.blank?
    end

    def connect
      @connected = true
      Rails.logger.debug "[MCP] Connected to #{@mcp_server.name} with Bearer token authentication"
      true
    end

    def disconnect
      @connected = false
      Rails.logger.debug "[MCP] Disconnected from #{@mcp_server.name}"
      true
    end

    def authenticated?
      @token.present?
    end

    def send_request(payload)
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

    protected

    def health_check
      super
      
      # Test bearer token validity with a simple request
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

    def build_authenticated_request(payload)
      path = URI.parse(@mcp_server.endpoint).path.presence || '/'
      request = build_request('POST', path, payload)
      
      request['Authorization'] = "Bearer #{@token}"
      
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
        raise AuthenticationError, "Invalid or expired bearer token"
      when 403
        raise AuthenticationError, "Bearer token lacks required permissions"
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
  end
end