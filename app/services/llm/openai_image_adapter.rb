# frozen_string_literal: true

require "net/http"
require "json"
require "open-uri"

module Llm
  class OpenaiImageAdapter < BaseAdapter
    API_BASE_URL = "https://api.openai.com/v1"
    DEFAULT_MODEL = "dall-e-2"

    # DALL-E models and their capabilities
    MODELS = {
      "dall-e-2" => {
        sizes: [ "256x256", "512x512", "1024x1024" ],
        max_prompt_length: 1000,
        cost_per_image: 0.020 # $0.020 for 1024x1024
      },
      "dall-e-3" => {
        sizes: [ "1024x1024", "1024x1792", "1792x1024" ],
        max_prompt_length: 4000,
        cost_per_image: 0.040 # $0.040 for 1024x1024
      },
      "gpt-image-1" => {
        sizes: [ "1024x1024", "1024x1536", "1536x1024" ],
        max_prompt_length: 4000,
        cost_per_image: 0.040 # Estimated cost
      }
    }.freeze

    def initialize(api_key: nil, model: nil, **options)
      super(api_key: api_key, **options)
      @model = model || DEFAULT_MODEL
    end

    def generate_image(prompt, **options)
      validate_prompt(prompt)

      size = options[:size] || default_size
      validate_size(size)

      # Build request payload based on model capabilities
      payload = {
        model: @model,
        prompt: prompt.truncate(max_prompt_length),
        size: size,
        n: 1
      }

      # Add response_format for models that support it (not gpt-image-1)
      unless @model == "gpt-image-1"
        payload[:response_format] = "url"
      end

      # Add quality parameter for models that support it
      if @model == "dall-e-3"
        payload[:quality] = options[:quality] || "standard"
      elsif @model == "gpt-image-1"
        # gpt-image-1 uses different quality values: low, medium, high, auto
        payload[:quality] = options[:quality] || "high"
      end

      response = make_request("/images/generations", payload)

      Rails.logger.debug "Image generation response: #{response.inspect}"

      image_data = response.dig("data", 0)
      unless image_data
        Rails.logger.error "No image data in response: #{response.inspect}"
        return nil
      end

      # Extract URL - gpt-image-1 might use different response structure
      url = image_data["url"] || image_data["b64_json"]

      unless url
        Rails.logger.error "No URL found in image data: #{image_data.inspect}"
        return nil
      end

      {
        url: url,
        revised_prompt: image_data["revised_prompt"],
        size: size,
        model: @model,
        cost: calculate_cost(size),
        prompt_used: prompt.truncate(max_prompt_length)
      }
    end

    def download_image(url, filename = nil)
      return nil unless url.present?

      begin
        # Check if it's base64 data (either with data: prefix or raw base64)
        if url.start_with?("data:image")
          # Handle base64 encoded image with data URL prefix
          require "base64"

          # Extract base64 data from data URL
          base64_data = url.split(",")[1]
          image_data = Base64.decode64(base64_data)

          # Create a temporary file
          temp_file = Tempfile.new([ filename || "image", ".png" ])
          temp_file.binmode
          temp_file.write(image_data)
          temp_file.rewind
          temp_file
        elsif url.start_with?("iVBOR") || (!url.start_with?("http://") && !url.start_with?("https://"))
          # Handle raw base64 data (PNG images often start with iVBOR)
          # If it's not a data URL and not an HTTP(S) URL, assume it's base64
          require "base64"
          Rails.logger.info "Detected raw base64 image data"

          image_data = Base64.decode64(url)

          # Create a temporary file
          temp_file = Tempfile.new([ filename || "image", ".png" ])
          temp_file.binmode
          temp_file.write(image_data)
          temp_file.rewind
          temp_file
        else
          # Handle regular URL
          downloaded_file = URI.open(url)

          if filename
            # Create a temporary file with the specified filename
            temp_file = Tempfile.new([ filename, ".png" ])
            temp_file.binmode
            temp_file.write(downloaded_file.read)
            temp_file.rewind
            temp_file
          else
            downloaded_file
          end
        end
      rescue => e
        Rails.logger.error "Failed to download image from #{url[0..100]}: #{e.message}"
        nil
      end
    end

    def model_name
      @model
    end

    private

    def validate_prompt(prompt)
      raise ArgumentError, "Prompt cannot be blank" if prompt.blank?
      raise ArgumentError, "Prompt too long for #{@model}" if prompt.length > max_prompt_length
    end

    def validate_size(size)
      valid_sizes = MODELS[@model][:sizes]
      unless valid_sizes.include?(size)
        raise ArgumentError, "Invalid size #{size} for #{@model}. Valid sizes: #{valid_sizes.join(', ')}"
      end
    end

    def default_size
      case @model
      when "dall-e-2"
        "1024x1024"
      when "dall-e-3"
        "1024x1024"
      when "gpt-image-1"
        "1024x1024"
      else
        "1024x1024"
      end
    end

    def max_prompt_length
      MODELS[@model][:max_prompt_length]
    end

    def calculate_cost(size)
      # Base cost for the model
      base_cost = MODELS[@model][:cost_per_image]

      # DALL-E 3 has different pricing for different sizes
      if @model == "dall-e-3"
        case size
        when "1024x1024"
          0.040
        when "1024x1792", "1792x1024"
          0.080
        else
          base_cost
        end
      elsif @model == "gpt-image-1"
        # GPT-image-1 pricing (estimated)
        case size
        when "1024x1024"
          0.040
        when "1024x1536", "1536x1024"
          0.060
        else
          base_cost
        end
      else
        # DALL-E 2 pricing is consistent
        case size
        when "256x256"
          0.016
        when "512x512"
          0.018
        when "1024x1024"
          0.020
        else
          base_cost
        end
      end
    end

    def make_request(endpoint, payload)
      retries = 0
      max_retries = 2

      begin
        uri = URI("#{API_BASE_URL}#{endpoint}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 120  # Image generation can take longer
        http.open_timeout = 30

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
      rescue Net::ReadTimeout => e
        raise LlmError, "Request timeout during image generation: #{e.message}"
      rescue LlmError => e
        # Retry on server errors (5xx) but not on client errors (4xx)
        if e.message.include?("server error") && retries < max_retries
          retries += 1
          Rails.logger.warn "OpenAI server error, retrying (#{retries}/#{max_retries}): #{e.message}"
          sleep(2 ** retries) # Exponential backoff: 2s, 4s
          retry
        else
          raise e
        end
      end
    end

    def handle_http_error(response)
      error_body = JSON.parse(response.body) rescue {}
      error_message = error_body.dig("error", "message") || "HTTP #{response.code}: #{response.message}"

      case response.code.to_i
      when 400
        if error_message.include?("content_policy_violation")
          raise LlmError, "Content policy violation: The prompt may contain inappropriate content"
        else
          raise LlmError, "Bad request: #{error_message}"
        end
      when 401
        raise LlmError, "Authentication failed: Invalid API key"
      when 429
        raise LlmError, "Rate limit exceeded: #{error_message}"
      when 500..599
        raise LlmError, "OpenAI server error: #{error_message}"
      else
        raise LlmError, "Image generation failed: #{error_message}"
      end
    end
  end
end
