# frozen_string_literal: true

require "net/http"
require "json"

module Llm
  class ClaudeAdapter < BaseAdapter
    API_BASE_URL = "https://api.anthropic.com/v1"
    DEFAULT_MODEL = "claude-3-5-sonnet-20241022"

    def initialize(api_key: nil, model: nil, **options)
      super(api_key: api_key, **options)
      @model = model || DEFAULT_MODEL
    end

    def generate(prompt, **options)
      response = make_request("/messages", {
        model: @model,
        max_tokens: options[:max_tokens] || 1000,
        messages: [ { role: "user", content: prompt } ]
      })

      response.dig("content", 0, "text")
    end

    def chat(messages, **options)
      validate_messages(messages)

      response = make_request("/messages", {
        model: @model,
        max_tokens: options[:max_tokens] || 1000,
        messages: messages
      })

      response.dig("content", 0, "text")
    end

    def stream(prompt, **options, &block)
      payload = {
        model: @model,
        max_tokens: options[:max_tokens] || 1000,
        messages: [ { role: "user", content: prompt } ],
        stream: true
      }

      stream_request("/messages", payload, &block)
    end

    def model_name
      @model
    end

    private

    def make_request(endpoint, payload)
      uri = URI("#{API_BASE_URL}#{endpoint}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request["x-api-key"] = api_key
      request["anthropic-version"] = "2023-06-01"
      request["Content-Type"] = "application/json"
      request.body = payload.to_json

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

      request = Net::HTTP::Post.new(uri)
      request["x-api-key"] = api_key
      request["anthropic-version"] = "2023-06-01"
      request["Content-Type"] = "application/json"
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
              if json["type"] == "content_block_delta"
                content = json.dig("delta", "text")
                block.call(content) if content
              end
            rescue JSON::ParserError
              # Skip invalid JSON chunks
            end
          end
        end
      end
    end
  end
end
