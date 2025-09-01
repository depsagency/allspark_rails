# frozen_string_literal: true

# Helper class for creating and parsing JSON-RPC 2.0 messages
# Used for communication with MCP servers
class JsonRpcMessage
  # Create a JSON-RPC 2.0 request message
  # @param method [String] The method name to call
  # @param params [Hash, nil] Optional parameters for the method
  # @param id [String, Integer, nil] Optional request ID (will generate UUID if not provided)
  # @return [Hash] JSON-RPC 2.0 formatted request
  def self.request(method:, params: nil, id: nil)
    raise ArgumentError, "Method name is required" if method.nil? || method.empty?
    raise ArgumentError, "Method must be a string" unless method.is_a?(String)
    
    {
      jsonrpc: "2.0",
      method: method,
      params: params,
      id: id || SecureRandom.uuid
    }.compact
  end
  
  # Create a JSON-RPC 2.0 response message
  # @param result [Object, nil] The result of the method call (mutually exclusive with error)
  # @param error [Hash, nil] Error information (mutually exclusive with result)
  # @param id [String, Integer] The ID from the request
  # @return [Hash] JSON-RPC 2.0 formatted response
  def self.response(result: nil, error: nil, id:)
    raise ArgumentError, "ID is required for response" if id.nil?
    raise ArgumentError, "Cannot have both result and error" if !result.nil? && !error.nil?
    raise ArgumentError, "Must have either result or error" if result.nil? && error.nil?
    
    response = {
      jsonrpc: "2.0",
      id: id
    }
    
    if error
      # Validate error structure
      raise ArgumentError, "Error must be a hash" unless error.is_a?(Hash)
      raise ArgumentError, "Error must have a message" unless error[:message]
      
      response[:error] = {
        code: error[:code] || -1,
        message: error[:message] || 'Unknown error',
        data: error[:data]
      }.compact
    else
      response[:result] = result
    end
    
    response
  end

  # Validate if a message is a valid JSON-RPC 2.0 request
  # @param message [Hash] The message to validate
  # @return [Boolean] true if valid, false otherwise
  def self.valid_request?(message)
    return false unless message.is_a?(Hash)
    return false unless message[:jsonrpc] == "2.0"
    return false unless message[:method].is_a?(String) && !message[:method].empty?
    return false if message.key?(:params) && ![Hash, Array].include?(message[:params].class)
    
    true
  end

  # Validate if a message is a valid JSON-RPC 2.0 response
  # @param message [Hash] The message to validate
  # @return [Boolean] true if valid, false otherwise
  def self.valid_response?(message)
    return false unless message.is_a?(Hash)
    return false unless message[:jsonrpc] == "2.0"
    return false unless message.key?(:id)
    return false unless message.key?(:result) || message.key?(:error)
    return false if message.key?(:result) && message.key?(:error)
    
    if message.key?(:error)
      error = message[:error]
      return false unless error.is_a?(Hash)
      return false unless error.key?(:code) && error.key?(:message)
      return false unless error[:code].is_a?(Integer)
      return false unless error[:message].is_a?(String)
    end
    
    true
  end

  # Parse an error from a JSON-RPC response
  # @param response [Hash] The response containing an error
  # @return [Hash, nil] The error information or nil if no error
  def self.parse_error(response)
    return nil unless response.is_a?(Hash) && response[:error]
    
    response[:error]
  end

  # Extract the result from a JSON-RPC response
  # @param response [Hash] The response containing a result
  # @return [Object, nil] The result or nil if no result
  def self.parse_result(response)
    return nil unless response.is_a?(Hash) && response.key?(:result)
    
    response[:result]
  end
end