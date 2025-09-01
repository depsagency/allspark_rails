# frozen_string_literal: true

module Llm
  class LangchainAdapter
    def initialize(client = nil)
      @client = client || Client.with_fallback
    end

    # Convert our LLM client to a LangChain-compatible LLM
    def to_langchain_llm
      # Create a custom LangChain LLM that uses our existing infrastructure
      CustomLangchainLLM.new(client: @client)
    end

    # Custom LangChain LLM that wraps our existing client
    class CustomLangchainLLM
      attr_reader :client

      def initialize(client:, **options)
        @client = client
        @defaults = {
          temperature: 0.7,
          max_tokens: 1000
        }.merge(options)
      end

      # Required method for LangChain LLM
      def chat(messages:, **params)
        response = client.chat(
          messages.map { |m| { role: m[:role].to_s, content: m[:content] } },
          **@defaults.merge(params)
        )
        
        # Return in LangChain expected format
        Langchain::LLM::Response.new(response[:content])
      rescue => e
        Rails.logger.error "LangChain adapter error: #{e.message}"
        raise
      end

      # Required method for LangChain LLM
      def complete(prompt:, **params)
        response = client.generate(prompt, **@defaults.merge(params))
        
        # Return in LangChain expected format
        Langchain::LLM::Response.new(response[:content])
      rescue => e
        Rails.logger.error "LangChain adapter error: #{e.message}"
        raise
      end

      # Support streaming if needed
      def stream(prompt:, **params, &block)
        client.stream(prompt, **@defaults.merge(params), &block)
      end

      # Model information
      def model_name
        client.provider_info[:model]
      end

      def provider
        client.provider_info[:provider]
      end
    end
  end
end