# frozen_string_literal: true

module Llm
  class Client
    include ActiveSupport::Benchmarkable

    def initialize(provider: nil, **options)
      @config = Configuration.current
      @provider = provider || @config.effective_provider
      @options = @config.to_adapter_options.merge(options)
      @cache = Rails.cache if @config.cache_enabled
    end

    def generate(prompt, **options)
      with_error_handling do
        merged_options = @options.merge(options)

        if @cache && merged_options[:cache] != false
          cache_key = @config.cache_key(prompt, merged_options)
          return @cache.fetch(cache_key, expires_in: @config.cache_ttl) do
            perform_generation(prompt, merged_options)
          end
        end

        perform_generation(prompt, merged_options)
      end
    end

    def chat(messages, **options)
      with_error_handling do
        merged_options = @options.merge(options)

        if @cache && merged_options[:cache] != false
          cache_key = @config.cache_key(messages.to_json, merged_options)
          return @cache.fetch(cache_key, expires_in: @config.cache_ttl) do
            perform_chat(messages, merged_options)
          end
        end

        perform_chat(messages, merged_options)
      end
    end

    def stream(prompt, **options, &block)
      with_error_handling do
        merged_options = @options.merge(options)
        perform_stream(prompt, merged_options, &block)
      end
    end

    def available?
      adapter.available?
    rescue => e
      Rails.logger.error "LLM availability check failed: #{e.message}"
      false
    end

    def provider_info
      {
        provider: @provider,
        model: @config.model_for_provider(@provider),
        available: available?,
        fallback_providers: @config.fallback_providers_available
      }
    end

    def self.with_fallback(**options)
      config = Configuration.current
      primary_client = new(provider: config.provider, **options)

      return primary_client if primary_client.available?

      config.fallback_providers_available.each do |fallback_provider|
        fallback_client = new(provider: fallback_provider, **options)
        return fallback_client if fallback_client.available?
      end

      raise BaseAdapter::LlmError, "No available LLM providers configured"
    end

    private

    attr_reader :config, :cache

    def adapter
      @adapter ||= AdapterFactory.create(@provider, **@options)
    end

    def with_error_handling(&block)
      retries = 0

      begin
        benchmark "LLM request (#{@provider})" do
          yield
        end
      rescue BaseAdapter::RateLimitError => e
        if retries < @config.max_retries
          retries += 1
          wait_time = exponential_backoff(retries)
          Rails.logger.warn "Rate limited, retrying in #{wait_time}s (attempt #{retries}/#{@config.max_retries})"
          sleep(wait_time)
          retry
        end

        raise e
      rescue BaseAdapter::LlmError => e
        Rails.logger.error "LLM request failed: #{e.message}"

        if retries < @config.max_retries && should_retry?(e)
          retries += 1
          Rails.logger.info "Retrying LLM request (attempt #{retries}/#{@config.max_retries})"
          retry
        end

        raise e
      end
    end

    def perform_generation(prompt, options)
      adapter.generate(prompt, **options)
    end

    def perform_chat(messages, options)
      adapter.chat(messages, **options)
    end

    def perform_stream(prompt, options, &block)
      adapter.stream(prompt, **options, &block)
    end

    def should_retry?(error)
      case error
      when BaseAdapter::AuthenticationError
        false
      when BaseAdapter::InvalidRequestError
        false
      else
        true
      end
    end

    def exponential_backoff(attempt)
      [ 2 ** attempt, 30 ].min
    end

    def logger
      @logger ||= Rails.logger
    end

    def benchmark(message, &block)
      if logger.debug?
        result = nil
        elapsed = Benchmark.measure { result = yield }
        logger.debug "#{message} (#{(elapsed.real * 1000).round(2)}ms)"
        result
      else
        yield
      end
    end
  end
end
