# frozen_string_literal: true

module Llm
  class AdapterFactory
    ADAPTERS = {
      openrouter: "Llm::OpenrouterAdapter",
      openai: "Llm::OpenaiAdapter",
      claude: "Llm::ClaudeAdapter",
      gemini: "Llm::GeminiAdapter"
    }.freeze

    class << self
      def create(provider = nil, **options)
        provider ||= Rails.application.config.llm.provider
        adapter_class = find_adapter_class(provider)

        api_key = options[:api_key] || default_api_key(provider)
        adapter_class.new(api_key: api_key, **options)
      end

      def available_providers
        ADAPTERS.keys.select do |provider|
          default_api_key(provider).present?
        end
      end

      def provider_available?(provider)
        default_api_key(provider).present?
      end

      private

      def find_adapter_class(provider)
        provider_sym = provider.to_sym

        unless ADAPTERS.key?(provider_sym)
          raise ArgumentError, "Unknown LLM provider: #{provider}. Available: #{ADAPTERS.keys.join(', ')}"
        end

        adapter_class_name = ADAPTERS[provider_sym]
        adapter_class_name.constantize
      rescue NameError
        raise ArgumentError, "Adapter class #{adapter_class_name} not found for provider: #{provider}"
      end

      def default_api_key(provider)
        case provider.to_sym
        when :openrouter
          ENV["OPENROUTER_API_KEY"]
        when :openai
          ENV["OPENAI_API_KEY"]
        when :claude
          ENV["CLAUDE_API_KEY"]
        when :gemini
          ENV["GEMINI_API_KEY"]
        else
          nil
        end
      end
    end
  end
end
