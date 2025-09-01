# frozen_string_literal: true

module Llm
  class Configuration
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :provider, :string, default: "openai"
    attribute :fallback_providers, default: -> { [] }
    attribute :max_retries, :integer, default: 3
    attribute :timeout, :integer, default: 30
    attribute :cache_enabled, :boolean, default: true
    attribute :cache_ttl, :integer, default: 3600

    # Provider-specific configurations
    attribute :openrouter_model, :string, default: "openai/gpt-4o-mini"
    attribute :openai_model, :string, default: "gpt-4o-mini"
    attribute :claude_model, :string, default: "claude-3-5-sonnet-20241022"
    attribute :gemini_model, :string, default: "gemini-1.5-flash"

    # Generation parameters
    attribute :default_max_tokens, :integer, default: 1000
    attribute :default_temperature, :float, default: 0.7

    validates :provider, inclusion: { in: %w[openrouter openai claude gemini] }
    validates :max_retries, numericality: { greater_than: 0, less_than: 10 }
    validates :timeout, numericality: { greater_than: 0, less_than: 300 }
    validates :default_temperature, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 2 }

    def self.current
      @current ||= new(load_from_config)
    end

    def self.reload!
      @current = nil
      current
    end

    def available_providers
      @available_providers ||= Llm::AdapterFactory.available_providers
    end

    def provider_available?(provider_name)
      available_providers.include?(provider_name.to_sym)
    end

    def primary_provider_available?
      provider_available?(provider)
    end

    def fallback_providers_available
      fallback_providers.select { |p| provider_available?(p) }
    end

    def effective_provider
      return provider if provider_available?(provider)

      fallback_providers_available.first || available_providers.first
    end

    def model_for_provider(provider_name = nil)
      provider_name ||= effective_provider

      case provider_name.to_s
      when "openrouter"
        openrouter_model
      when "openai"
        openai_model
      when "claude"
        claude_model
      when "gemini"
        gemini_model
      else
        raise ArgumentError, "Unknown provider: #{provider_name}"
      end
    end

    def cache_key(prompt, options = {})
      return nil unless cache_enabled

      content = {
        prompt: prompt,
        provider: effective_provider,
        model: model_for_provider,
        options: options.slice(:max_tokens, :temperature)
      }

      Digest::SHA256.hexdigest(content.to_json)
    end

    def to_adapter_options
      {
        model: model_for_provider,
        max_tokens: default_max_tokens,
        temperature: default_temperature,
        timeout: timeout
      }
    end

    private

    def self.load_from_config
      config = Rails.application.config.llm

      {
        provider: config.provider,
        fallback_providers: ENV.fetch("LLM_FALLBACK_PROVIDERS", "").split(",").map(&:strip).reject(&:empty?),
        max_retries: ENV.fetch("LLM_MAX_RETRIES", "3").to_i,
        timeout: ENV.fetch("LLM_TIMEOUT", "30").to_i,
        cache_enabled: ENV.fetch("LLM_CACHE_ENABLED", "true") == "true",
        cache_ttl: ENV.fetch("LLM_CACHE_TTL", "3600").to_i,
        openrouter_model: ENV.fetch("OPENROUTER_MODEL", "openai/gpt-4o-mini"),
        openai_model: ENV.fetch("OPENAI_MODEL", "gpt-4o-mini"),
        claude_model: ENV.fetch("CLAUDE_MODEL", "claude-3-5-sonnet-20241022"),
        gemini_model: ENV.fetch("GEMINI_MODEL", "gemini-1.5-flash"),
        default_max_tokens: ENV.fetch("LLM_DEFAULT_MAX_TOKENS", "1000").to_i,
        default_temperature: ENV.fetch("LLM_DEFAULT_TEMPERATURE", "0.7").to_f
      }
    end
  end
end
