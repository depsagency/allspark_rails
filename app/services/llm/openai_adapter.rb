# frozen_string_literal: true

require "net/http"
require "json"

module Llm
  class OpenaiAdapter < BaseAdapter
    API_BASE_URL = "https://api.openai.com/v1"
    DEFAULT_MODEL = "gpt-4o-mini"

    def initialize(api_key: nil, model: nil, **options)
      super(api_key: api_key, **options)
      @model = model || DEFAULT_MODEL
    end

    def generate(prompt, **options)
      messages = [ { role: "user", content: prompt } ]
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
      messages = [ { role: "user", content: prompt } ]

      payload = {
        model: @model,
        messages: messages,
        max_tokens: options[:max_tokens] || 1000,
        temperature: options[:temperature] || 0.7,
        stream: true
      }

      stream_request("/chat/completions", payload, &block)
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
      request["Authorization"] = "Bearer #{api_key}"
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
      request["Authorization"] = "Bearer #{api_key}"
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
              content = json.dig("choices", 0, "delta", "content")
              block.call(content) if content
            rescue JSON::ParserError
              # Skip invalid JSON chunks
            end
          end
        end
      end
    end
  end
end
