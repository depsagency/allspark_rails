module McpConnection
  class Base
    DEFAULT_TIMEOUT = 30.seconds
    MAX_RETRIES = 3
    INITIAL_BACKOFF = 1.second
    
    # Custom exception classes
    class ConnectionError < StandardError; end
    class AuthenticationError < StandardError; end
    class RateLimitError < StandardError; end
    class TimeoutError < StandardError; end
    class ProtocolError < StandardError; end

    def initialize(mcp_server)
      @mcp_server = mcp_server
      @timeout = (mcp_server.config&.dig('timeout') || DEFAULT_TIMEOUT).to_i
      @max_retries = (mcp_server.config&.dig('max_retries') || MAX_RETRIES).to_i
      @backoff = INITIAL_BACKOFF
    end

    # Interface methods that must be implemented by subclasses
    def connect
      raise NotImplementedError, "Subclasses must implement #connect"
    end

    def disconnect
      raise NotImplementedError, "Subclasses must implement #disconnect"
    end

    def authenticated?
      raise NotImplementedError, "Subclasses must implement #authenticated?"
    end

    def send_request(payload)
      raise NotImplementedError, "Subclasses must implement #send_request"
    end

    # Common connection methods
    def test_connection
      with_retry do
        result = connect
        health_check
        result
      end
    ensure
      disconnect
    end

    def call_tool(tool_name, args = {})
      with_retry do
        connect unless connected?
        
        payload = build_tool_payload(tool_name, args)
        response = send_request(payload)
        
        parse_response(response)
      end
    rescue => e
      handle_error(e)
    ensure
      # Keep connection alive for connection pooling
      # disconnect will be called by connection manager
    end

    def discover_tools
      with_retry do
        connect unless connected?
        
        payload = build_discovery_payload
        response = send_request(payload)
        
        parse_tools_response(response)
      end
    rescue => e
      handle_error(e)
    end

    protected

    def connected?
      @connected ||= false
    end

    def with_retry
      retries = 0
      
      begin
        yield
      rescue RateLimitError => e
        if retries < @max_retries
          retries += 1
          delay = calculate_backoff(retries)
          Rails.logger.warn "Rate limited, retrying in #{delay}s (attempt #{retries}/#{@max_retries})"
          sleep delay
          retry
        else
          raise e
        end
      rescue TimeoutError, ConnectionError => e
        if retries < @max_retries
          retries += 1
          delay = calculate_backoff(retries)
          Rails.logger.warn "Connection error, retrying in #{delay}s (attempt #{retries}/#{@max_retries}): #{e.message}"
          sleep delay
          retry
        else
          raise e
        end
      rescue => e
        # Don't retry authentication errors or protocol errors
        raise e
      end
    end

    def calculate_backoff(attempt)
      [@backoff * (2 ** (attempt - 1)), 30.seconds].min
    end

    def health_check
      # Basic health check - can be overridden by subclasses
      return true if authenticated?
      
      raise ConnectionError, "Health check failed: not authenticated"
    end

    def build_tool_payload(tool_name, args)
      {
        jsonrpc: "2.0",
        id: SecureRandom.uuid,
        method: "tools/call",
        params: {
          name: tool_name,
          arguments: args
        }
      }
    end

    def build_discovery_payload
      {
        jsonrpc: "2.0",
        id: SecureRandom.uuid,
        method: "tools/list",
        params: {}
      }
    end

    def parse_response(response)
      data = JSON.parse(response)
      
      if data['error']
        handle_rpc_error(data['error'])
      else
        data['result']
      end
    rescue JSON::ParserError => e
      raise ProtocolError, "Invalid JSON response: #{e.message}"
    end

    def parse_tools_response(response)
      result = parse_response(response)
      
      if result.is_a?(Hash) && result['tools'].is_a?(Array)
        result['tools']
      else
        raise ProtocolError, "Invalid tools list response format"
      end
    end

    def handle_rpc_error(error)
      case error['code']
      when -32600
        raise ProtocolError, "Invalid Request: #{error['message']}"
      when -32601
        raise ProtocolError, "Method not found: #{error['message']}"
      when -32602
        raise ProtocolError, "Invalid params: #{error['message']}"
      when -32603
        raise ProtocolError, "Internal error: #{error['message']}"
      when 401, 403
        raise AuthenticationError, error['message']
      when 429
        raise RateLimitError, error['message']
      when 408, 504
        raise TimeoutError, error['message']
      else
        raise ConnectionError, "RPC Error #{error['code']}: #{error['message']}"
      end
    end

    def handle_error(error)
      log_error(error)
      
      case error
      when AuthenticationError
        @mcp_server.update(status: :error)
        { error: "Authentication failed: #{error.message}" }
      when RateLimitError
        { error: "Rate limit exceeded: #{error.message}" }
      when TimeoutError
        { error: "Request timed out: #{error.message}" }
      when ConnectionError
        @mcp_server.update(status: :error)
        { error: "Connection failed: #{error.message}" }
      when ProtocolError
        { error: "Protocol error: #{error.message}" }
      else
        @mcp_server.update(status: :error)
        { error: "Unexpected error: #{error.message}" }
      end
    end

    def log_error(error)
      Rails.logger.error "[MCP] #{self.class.name} error for server #{@mcp_server.id}: #{error.class} - #{error.message}"
      Rails.logger.debug error.backtrace.join("\n") if Rails.env.development?
    end

    # HTTP helper methods for subclasses
    def http_client
      @http_client ||= Net::HTTP.new(@mcp_server.endpoint.split('/')[2], 443).tap do |http|
        http.use_ssl = @mcp_server.endpoint.start_with?('https')
        http.read_timeout = @timeout
        http.open_timeout = @timeout
      end
    end

    def build_request(method, path, payload = nil)
      case method.to_s.upcase
      when 'GET'
        Net::HTTP::Get.new(path)
      when 'POST'
        Net::HTTP::Post.new(path).tap do |req|
          req['Content-Type'] = 'application/json'
          req.body = payload.to_json if payload
        end
      when 'PUT'
        Net::HTTP::Put.new(path).tap do |req|
          req['Content-Type'] = 'application/json'
          req.body = payload.to_json if payload
        end
      when 'DELETE'
        Net::HTTP::Delete.new(path)
      else
        raise ArgumentError, "Unsupported HTTP method: #{method}"
      end
    end

    private

    attr_reader :mcp_server
  end
end