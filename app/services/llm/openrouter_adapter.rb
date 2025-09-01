# frozen_string_literal: true

require "net/http"
require "json"

module Llm
  class OpenrouterAdapter < BaseAdapter
    class PaymentRequiredError < LlmError; end
    class ServiceError < LlmError; end
    
    API_BASE_URL = "https://openrouter.ai/api/v1"
    DEFAULT_MODEL = "google/gemini-2.5-pro"

    # Model name mapping for backward compatibility
    MODEL_MAPPINGS = {
      "gpt-4o-mini" => "openai/gpt-4o-mini",
      "gpt-4o" => "openai/gpt-4o",
      "gpt-4-turbo" => "openai/gpt-4-turbo",
      "claude-3-5-sonnet-20241022" => "anthropic/claude-3.5-sonnet",
      "claude-3-opus" => "anthropic/claude-3-opus",
      "gemini-1.5-flash" => "google/gemini-flash-1.5",
      "gemini-1.5-pro" => "google/gemini-pro-1.5",
      "gemini-2.0-flash" => "google/gemini-flash-2.0",
      "gemini-2.5-pro" => "google/gemini-2.5-pro"
    }.freeze

    def initialize(api_key: nil, model: nil, **options)
      super(api_key: api_key, **options)
      @model = normalize_model_name(model || ENV["OPENROUTER_MODEL"] || DEFAULT_MODEL)
      @app_url = options[:app_url] || Rails.application.config.app_url || "http://localhost:3000"
      @app_name = options[:app_name] || Rails.application.config.app_name || "Allspark Rails App"
    end

    def generate(prompt, **options)
      messages = [ { "role" => "user", "content" => prompt } ]
      chat(messages, **options)
    end

    def chat(messages, **options)
      validate_messages(messages)

      response = make_request("/chat/completions", {
        model: @model,
        messages: messages,
        max_tokens: options[:max_tokens] || 1000,
        temperature: options[:temperature] || 0.7
      })

      response.dig("choices", 0, "message", "content")
    end

    def stream(prompt, **options, &block)
      messages = [ { "role" => "user", "content" => prompt } ]

      payload = {
        model: @model,
        messages: messages,
        max_tokens: options[:max_tokens] || 1000,
        temperature: options[:temperature] || 0.7,
        stream: true
      }

      stream_request("/chat/completions", payload, &block)
    end

    def available?
      return false unless @api_key.present?

      # Test with a minimal request to models endpoint
      response = make_request("/models", nil, method: :get)
      response["data"].is_a?(Array)
    rescue => e
      Rails.logger.error "OpenRouter availability check failed: #{e.message}"
      false
    end

    def model_name
      @model
    end

    private

    def normalize_model_name(model)
      # If already in OpenRouter format, return as-is
      return model if model.include?("/")

      # Otherwise, try to map it
      MODEL_MAPPINGS[model] || "openai/#{model}"
    end

    def build_headers
      {
        "Authorization" => "Bearer #{@api_key}",
        "Content-Type" => "application/json",
        "HTTP-Referer" => @app_url,
        "X-Title" => @app_name
      }
    end

    def make_request(endpoint, payload, method: :post)
      uri = URI("#{API_BASE_URL}#{endpoint}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = @timeout || 30
      http.open_timeout = @timeout || 30

      request = case method
      when :get
                  Net::HTTP::Get.new(uri)
      when :post
                  Net::HTTP::Post.new(uri)
      else
                  raise ArgumentError, "Unsupported method: #{method}"
      end

      build_headers.each { |k, v| request[k] = v }
      request.body = payload.to_json if payload && method == :post

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        handle_http_error(response)
      end

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise LlmError, "Invalid JSON response: #{e.message}"
    end

    def stream_request(endpoint, payload, &block)
      uri = URI("#{API_BASE_URL}#{endpoint}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = @timeout || 30
      http.open_timeout = @timeout || 30

      request = Net::HTTP::Post.new(uri)
      build_headers.each { |k, v| request[k] = v }
      request.body = payload.to_json

      http.request(request) do |response|
        unless response.is_a?(Net::HTTPSuccess)
          handle_http_error(response)
        end

        response.read_body do |chunk|
          chunk.split("\n").each do |line|
            next unless line.start_with?("data: ")

            data = line[6..]
            next if data == "[DONE]"

            begin
              json = JSON.parse(data)
              content = json.dig("choices", 0, "delta", "content")
              block.call(content) if content
            rescue JSON::ParserError
              # Skip invalid JSON chunks
            end
          end
        end
      end
    end

    def handle_http_error(response)
      error_body = JSON.parse(response.body) rescue { "error" => { "message" => response.body } }
      error_message = error_body.dig("error", "message") || "Unknown error"

      case response.code.to_i
      when 401
        raise AuthenticationError, "Invalid API key: #{error_message}"
      when 402
        raise PaymentRequiredError, "Insufficient credits: #{error_message}"
      when 429
        raise RateLimitError, "Rate limit exceeded: #{error_message}"
      when 500..599
        raise ServiceError, "OpenRouter service error: #{error_message}"
      else
        raise LlmError, "HTTP #{response.code}: #{error_message}"
      end
    end
  end
end
