# frozen_string_literal: true

# Custom exceptions for MCP Bridge operations
module McpBridgeErrors
  # Base error class for all MCP Bridge errors
  class McpBridgeError < StandardError
    attr_reader :configuration_id, :user_id, :details

    def initialize(message, configuration_id: nil, user_id: nil, details: {})
      super(message)
      @configuration_id = configuration_id
      @user_id = user_id
      @details = details
    end

    def to_h
      {
        error: message,
        configuration_id: configuration_id,
        user_id: user_id,
        details: details
      }.compact
    end
  end

  # Raised when MCP configuration is invalid
  class ConfigurationError < McpBridgeError; end

  # Raised when MCP server process fails to spawn
  class ProcessSpawnError < McpBridgeError; end

  # Raised when MCP server process crashes
  class ProcessCrashError < McpBridgeError
    attr_reader :exit_status

    def initialize(message, exit_status: nil, **kwargs)
      super(message, **kwargs)
      @exit_status = exit_status
    end
  end

  # Raised when MCP communication times out
  class CommunicationTimeoutError < McpBridgeError
    attr_reader :timeout_seconds

    def initialize(message = "MCP communication timed out", timeout_seconds: 30, **kwargs)
      super(message, **kwargs)
      @timeout_seconds = timeout_seconds
    end
  end

  # Raised when MCP protocol initialization fails
  class ProtocolInitializationError < McpBridgeError; end

  # Raised when MCP tool execution fails
  class ToolExecutionError < McpBridgeError
    attr_reader :tool_name, :error_code

    def initialize(message, tool_name: nil, error_code: nil, **kwargs)
      super(message, **kwargs)
      @tool_name = tool_name
      @error_code = error_code
    end
  end

  # Raised when authorization fails
  class AuthorizationError < McpBridgeError; end

  # Raised when rate limit is exceeded
  class RateLimitError < McpBridgeError
    attr_reader :retry_after

    def initialize(message = "Rate limit exceeded", retry_after: nil, **kwargs)
      super(message, **kwargs)
      @retry_after = retry_after
    end
  end

  # Raised when circuit breaker is open
  class CircuitOpenError < McpBridgeError
    attr_reader :retry_after, :failure_count

    def initialize(message = "Circuit breaker is open", retry_after: nil, failure_count: nil, **kwargs)
      super(message, **kwargs)
      @retry_after = retry_after
      @failure_count = failure_count
    end
  end

  # Raised when tool discovery fails
  class ToolDiscoveryError < McpBridgeError; end
end