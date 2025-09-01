# frozen_string_literal: true

require "net/http"
require "json"

module Llm
  class GeminiAdapter < BaseAdapter
    API_BASE_URL = "https://generativelanguage.googleapis.com/v1beta"
    DEFAULT_MODEL = "gemini-2.5-pro"

    def initialize(api_key: nil, model: nil, **options)
      super(api_key: api_key, **options)
      @model = model || DEFAULT_MODEL
    end

    def generate(prompt, **options)
      response = make_request("/models/#{@model}:generateContent", {
        contents: [ { parts: [ { text: prompt } ] } ],
        generationConfig: {
          maxOutputTokens: options[:max_tokens] || 1000,
          temperature: options[:temperature] || 0.7
        }
      })

      response.dig("candidates", 0, "content", "parts", 0, "text")
    end

    def chat(messages, **options)
      validate_messages(messages)

      contents = messages.map do |message|
        role = message["role"] == "assistant" ? "model" : "user"
        { role: role, parts: [ { text: message["content"] } ] }
      end

      response = make_request("/models/#{@model}:generateContent", {
        contents: contents,
        generationConfig: {
          maxOutputTokens: options[:max_tokens] || 1000,
          temperature: options[:temperature] || 0.7
        }
      })

      response.dig("candidates", 0, "content", "parts", 0, "text")
    end

    def stream(prompt, **options, &block)
      payload = {
        contents: [ { parts: [ { text: prompt } ] } ],
        generationConfig: {
          maxOutputTokens: options[:max_tokens] || 1000,
          temperature: options[:temperature] || 0.7
        }
      }

      stream_request("/models/#{@model}:streamGenerateContent", payload, &block)
    end

    def model_name
      @model
    end

    private

    def make_request(endpoint, payload)
      uri = URI("#{API_BASE_URL}#{endpoint}?key=#{api_key}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 300  # 5 minutes for Gemini 2.5 Pro
      http.open_timeout = 30   # 30 seconds to establish connection

      request = Net::HTTP::Post.new(uri)
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
      uri = URI("#{API_BASE_URL}#{endpoint}?key=#{api_key}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 300  # 5 minutes for Gemini 2.5 Pro
      http.open_timeout = 30   # 30 seconds to establish connection

      request = Net::HTTP::Post.new(uri)
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
            next if data.empty?

            begin
              json = JSON.parse(data)
              content = json.dig("candidates", 0, "content", "parts", 0, "text")
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
