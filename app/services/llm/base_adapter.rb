# frozen_string_literal: true

module Llm
  class BaseAdapter
    class LlmError < StandardError; end
    class RateLimitError < LlmError; end
    class AuthenticationError < LlmError; end
    class InvalidRequestError < LlmError; end

    def initialize(api_key: nil, **options)
      @api_key = api_key
      @options = options
    end

    def generate(prompt, **options)
      raise NotImplementedError, "Subclasses must implement #generate"
    end

    def chat(messages, **options)
      raise NotImplementedError, "Subclasses must implement #chat"
    end

    def stream(prompt, **options, &block)
      raise NotImplementedError, "Subclasses must implement #stream"
    end

    def available?
      !@api_key.nil? && !@api_key.empty?
    end

    def model_name
      raise NotImplementedError, "Subclasses must implement #model_name"
    end

    private

    attr_reader :api_key, :options

    def handle_http_error(response)
      case response.code
      when 401, 403
        raise AuthenticationError, "Invalid API key or insufficient permissions"
      when 429
        raise RateLimitError, "Rate limit exceeded"
      when 400
        raise InvalidRequestError, "Invalid request: #{response.body}"
      when 500..599
        raise LlmError, "Server error: #{response.code}"
      else
        raise LlmError, "HTTP error: #{response.code} - #{response.body}"
      end
    end

    def validate_messages(messages)
      return unless messages.is_a?(Array)

      messages.each do |message|
        next if message.is_a?(Hash) && message.key?("role") && message.key?("content")

        raise InvalidRequestError, "Invalid message format. Expected hash with 'role' and 'content' keys"
      end
    end
  end
end
