require 'net/http'
require 'uri'
require 'json'

module McpConnection
  class SseConnection < Base
    RECONNECT_DELAY = 5.seconds
    
    def initialize(mcp_server)
      super
      @connected = false
      @event_buffer = []
      @last_event_id = nil
      @uri = URI.parse(@mcp_server.endpoint)
    end

    def connect
      Rails.logger.info "[MCP SSE] Connecting to #{@mcp_server.endpoint}"
      
      # For SSE, we don't maintain a persistent connection in the traditional sense
      # Each request will establish its own SSE stream
      @connected = true
      
      # Test the connection by making a simple request
      test_sse_endpoint
    rescue => e
      Rails.logger.error "[MCP SSE] Connection failed: #{e.message}"
      raise ConnectionError, "Failed to connect to SSE endpoint: #{e.message}"
    end

    def disconnect
      @connected = false
      @last_event_id = nil
      Rails.logger.info "[MCP SSE] Disconnected from #{@mcp_server.endpoint}"
    end

    def authenticated?
      # SSE connections typically handle auth via URL params or headers
      # For Linear's implementation, auth is likely handled in-band
      @connected
    end

    def send_request(payload)
      raise ConnectionError, "Not connected" unless @connected
      
      method = payload[:method]
      params = payload[:params] || {}
      
      case method
      when "tools/list"
        discover_tools_via_sse
      when "tools/call"
        call_tool_via_sse(params[:name], params[:arguments])
      else
        raise ProtocolError, "Unsupported method for SSE: #{method}"
      end
    end

    private

    def test_sse_endpoint
      # For Linear's SSE endpoint, we should test by sending a simple JSON-RPC request
      # that doesn't require specific permissions
      http = build_http_client
      
      # Try a simple ping or initialize request
      test_payload = {
        jsonrpc: "2.0",
        id: SecureRandom.uuid,
        method: "initialize",
        params: {
          protocolVersion: "1.0",
          capabilities: {},
          clientInfo: {
            name: "AllSpark",
            version: "1.0"
          }
        }
      }
      
      request = build_sse_request('', method: :post, body: test_payload.to_json, headers: { 'Content-Type' => 'application/json' })
      
      response = http.request(request)
      
      unless response.is_a?(Net::HTTPSuccess)
        raise ConnectionError, "SSE endpoint returned #{response.code}: #{response.body}"
      end
      
      # For SSE, we should get a streaming response
      # Just check that we can connect successfully
      true
    end

    def discover_tools_via_sse
      Rails.logger.info "[MCP SSE] Discovering tools via SSE"
      
      # For Linear's MCP implementation, we need to send the JSON-RPC request
      # through the SSE stream and collect the response
      request_id = SecureRandom.uuid
      request_payload = {
        jsonrpc: "2.0",
        id: request_id,
        method: "tools/list",
        params: {}
      }
      
      tools = []
      response_received = false
      
      # Linear expects us to POST the request to the SSE endpoint
      stream_sse_events('', method: :post, body: request_payload.to_json, headers: { 'Content-Type' => 'application/json' }) do |event|
        Rails.logger.debug "[MCP SSE] Received event: #{event[:type]} - #{event[:data]}"
        
        case event[:type]
        when 'message', nil
          # Parse the JSON-RPC response
          begin
            data = JSON.parse(event[:data])
            if data['id'] == request_id
              response_received = true
              if data['result'] && data['result']['tools']
                tools = data['result']['tools']
                break
              elsif data['error']
                raise ProtocolError, "Tool discovery error: #{data['error']['message']}"
              end
            end
          rescue JSON::ParserError
            Rails.logger.warn "[MCP SSE] Non-JSON event data: #{event[:data]}"
          end
        when 'error'
          raise ProtocolError, "Tool discovery error: #{event[:data]}"
        when 'done', 'complete'
          break
        end
      end
      
      Rails.logger.info "[MCP SSE] Discovered #{tools.size} tools"
      { result: { tools: tools } }
    end

    def call_tool_via_sse(tool_name, arguments)
      Rails.logger.info "[MCP SSE] Calling tool #{tool_name} via SSE"
      
      # Similar to tool discovery, send JSON-RPC request through SSE
      request_id = SecureRandom.uuid
      request_payload = {
        jsonrpc: "2.0",
        id: request_id,
        method: "tools/call",
        params: {
          name: tool_name,
          arguments: arguments
        }
      }
      
      result = nil
      error = nil
      
      stream_sse_events('', method: :post, body: request_payload.to_json, headers: { 'Content-Type' => 'application/json' }) do |event|
        Rails.logger.debug "[MCP SSE] Tool call event: #{event[:type]} - #{event[:data]}"
        
        case event[:type]
        when 'message', nil
          begin
            data = JSON.parse(event[:data])
            if data['id'] == request_id
              if data['result']
                result = data['result']
                break
              elsif data['error']
                error = data['error']['message']
                break
              end
            end
          rescue JSON::ParserError
            Rails.logger.warn "[MCP SSE] Non-JSON event data: #{event[:data]}"
          end
        when 'error'
          error = event[:data]
          break
        when 'done', 'complete'
          break
        end
      end
      
      if error
        raise ProtocolError, "Tool execution error: #{error}"
      end
      
      { result: result }
    end

    def stream_sse_events(path, method: :get, body: nil, headers: {})
      http = build_http_client
      request = build_sse_request(path, method: method, body: body, headers: headers)
      
      http.request(request) do |response|
        unless response.is_a?(Net::HTTPSuccess)
          error_body = response.body
          Rails.logger.error "[MCP SSE] Request failed: #{response.code} - #{error_body}"
          
          # Try to parse error as JSON for better error messages
          begin
            error_json = JSON.parse(error_body)
            error_message = error_json['error_description'] || error_json['error'] || error_body
            raise ConnectionError, "SSE request failed: #{response.code} - #{error_message}"
          rescue JSON::ParserError
            raise ConnectionError, "SSE request failed: #{response.code} - #{error_body}"
          end
        end
        
        buffer = ""
        event_data = {}
        
        response.read_body do |chunk|
          buffer += chunk
          Rails.logger.debug "[MCP SSE] Received chunk: #{chunk.inspect}" if chunk.length < 200
          
          while line_end = buffer.index("\n")
            line = buffer[0...line_end]
            buffer = buffer[(line_end + 1)..-1]
            
            if line.empty?
              # Empty line signals end of event
              if event_data[:data]
                yield parse_sse_event(event_data)
                event_data = {}
              end
            elsif line.start_with?('data: ')
              event_data[:data] = line[6..-1]
            elsif line.start_with?('event: ')
              event_data[:type] = line[7..-1]
            elsif line.start_with?('id: ')
              @last_event_id = line[4..-1]
              event_data[:id] = @last_event_id
            elsif line.start_with?('retry: ')
              # Handle retry directive if needed
            elsif line.strip.length > 0
              # Some SSE implementations might not follow the standard format
              Rails.logger.debug "[MCP SSE] Non-standard line: #{line}"
            end
          end
        end
      end
    end

    def build_http_client
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.use_ssl = @uri.scheme == 'https'
      http.read_timeout = @timeout
      http.open_timeout = 10
      http
    end

    def build_sse_request(path, method: :get, body: nil, headers: {})
      # For Linear and other SSE endpoints, the path is already complete
      # Only append path if it's not empty
      full_path = path.empty? ? @uri.path : @uri.path + path
      full_path = '/sse' if full_path.empty? # Default path if none specified
      
      request = case method
      when :get
        Net::HTTP::Get.new(full_path)
      when :post
        Net::HTTP::Post.new(full_path)
      else
        raise ArgumentError, "Unsupported HTTP method: #{method}"
      end
      
      # Set SSE-specific headers
      request['Accept'] = 'text/event-stream'
      request['Cache-Control'] = 'no-cache'
      
      # Add Last-Event-ID if we have one (for resuming streams)
      request['Last-Event-ID'] = @last_event_id if @last_event_id
      
      # Add custom headers
      headers.each { |k, v| request[k] = v }
      
      # Add auth headers if configured
      add_auth_headers(request)
      
      # Set body for POST requests
      request.body = body if body && method == :post
      
      request
    end

    def add_auth_headers(request)
      Rails.logger.debug "[MCP SSE] Adding auth headers for #{@mcp_server.auth_type}"
      
      case @mcp_server.auth_type
      when 'api_key'
        api_key = @mcp_server.credentials['api_key']
        if api_key
          request['Authorization'] = "Bearer #{api_key}"
          Rails.logger.debug "[MCP SSE] Added Bearer token from api_key"
        else
          Rails.logger.warn "[MCP SSE] No api_key found in credentials"
        end
      when 'bearer_token'
        token = @mcp_server.credentials['token'] || @mcp_server.credentials['bearer_token']
        if token
          request['Authorization'] = "Bearer #{token}"
          Rails.logger.debug "[MCP SSE] Added Bearer token"
        else
          Rails.logger.warn "[MCP SSE] No token found in credentials"
        end
      when 'oauth'
        # For OAuth, use the access token
        access_token = @mcp_server.credentials['access_token']
        if access_token
          request['Authorization'] = "Bearer #{access_token}"
          Rails.logger.debug "[MCP SSE] Added OAuth access token"
        else
          Rails.logger.warn "[MCP SSE] No access_token found in credentials"
        end
      end
      
      # Linear-specific: They might expect the token in a different format
      # Check if endpoint contains 'linear' and we have credentials
      if @mcp_server.endpoint.include?('linear') && @mcp_server.credentials.present?
        # Try different credential keys that might be used
        token = @mcp_server.credentials['api_key'] || 
                @mcp_server.credentials['access_token'] || 
                @mcp_server.credentials['token'] ||
                @mcp_server.credentials['linear_api_key'] ||
                @mcp_server.credentials['bearer_token']
        
        if token.present?
          # Ensure we don't double-prefix with Bearer
          token = token.strip
          if token.start_with?('Bearer ')
            request['Authorization'] = token
          else
            request['Authorization'] = "Bearer #{token}"
          end
          Rails.logger.debug "[MCP SSE] Added Linear-specific Bearer token: #{request['Authorization'].sub(/Bearer (.{10}).*/, 'Bearer \1...')}"
        else
          Rails.logger.warn "[MCP SSE] No Linear API key found in credentials: #{@mcp_server.credentials.keys.inspect}"
        end
      end
    end

    def parse_sse_event(event_data)
      {
        type: event_data[:type] || 'message',
        data: event_data[:data],
        id: event_data[:id]
      }
    end

    def parse_tool_event(data)
      tool_data = JSON.parse(data)
      {
        'name' => tool_data['name'],
        'description' => tool_data['description'],
        'inputSchema' => tool_data['inputSchema']
      }
    rescue JSON::ParserError => e
      Rails.logger.error "[MCP SSE] Failed to parse tool data: #{e.message}"
      nil
    end
  end
end