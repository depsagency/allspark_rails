# frozen_string_literal: true

namespace :llm do
  desc "Check LLM configuration and provider availability"
  task status: :environment do
    puts "\n🤖 LLM Configuration Status"
    puts "=" * 50

    config = Llm::Configuration.current

    puts "Primary Provider: #{config.provider}"
    puts "Available Providers: #{config.available_providers.join(', ')}"
    puts "Fallback Providers: #{config.fallback_providers_available.join(', ')}"
    puts "Effective Provider: #{config.effective_provider}"
    puts ""

    # Test each provider
    %w[openrouter openai claude gemini].each do |provider|
      test_provider(provider.to_sym, config)
    end

    puts "\nCache: #{config.cache_enabled ? 'Enabled' : 'Disabled'}"
    puts "Max Retries: #{config.max_retries}"
    puts "Timeout: #{config.timeout}s"
  end

  desc "Test LLM providers with a simple prompt"
  task test: :environment do
    puts "\n🧪 Testing LLM Providers"
    puts "=" * 50

    test_prompt = "What is 2+2? Respond with just the number."

    Llm::Configuration.current.available_providers.each do |provider|
      test_provider_generation(provider, test_prompt)
    end
  end

  desc "Clear LLM cache"
  task clear_cache: :environment do
    if Rails.cache.respond_to?(:clear)
      Rails.cache.clear
      puts "✅ LLM cache cleared"
    else
      puts "⚠️  Cache clearing not supported by current cache store"
    end
  end

  desc "Show LLM configuration help"
  task help: :environment do
    puts <<~HELP
      🤖 LLM Configuration Help
      ========================

      Environment Variables:
      ----------------------
      LLM_PROVIDER              Primary provider (openrouter, openai, claude, gemini)
      LLM_FALLBACK_PROVIDERS    Comma-separated fallback providers
      LLM_MAX_RETRIES          Maximum retry attempts (default: 3)
      LLM_TIMEOUT              Request timeout in seconds (default: 30)
      LLM_CACHE_ENABLED        Enable response caching (default: true)
      LLM_CACHE_TTL            Cache time-to-live in seconds (default: 3600)

      Provider API Keys:
      ------------------
      OPENROUTER_API_KEY       OpenRouter API key (recommended)
      OPENAI_API_KEY           OpenAI API key
      CLAUDE_API_KEY           Anthropic Claude API key
      GEMINI_API_KEY           Google Gemini API key

      Model Selection:
      ----------------
      OPENROUTER_MODEL         OpenRouter model (default: openai/gpt-4o-mini)
      OPENAI_MODEL             OpenAI model (default: gpt-4o-mini)
      CLAUDE_MODEL             Claude model (default: claude-3-5-sonnet-20241022)
      GEMINI_MODEL             Gemini model (default: gemini-1.5-flash)

      Generation Parameters:
      ----------------------
      LLM_DEFAULT_MAX_TOKENS   Default max tokens (default: 1000)
      LLM_DEFAULT_TEMPERATURE  Default temperature (default: 0.7)

      Usage Examples:
      ---------------
      # Basic usage
      client = Llm::Client.new
      response = client.generate("Hello, AI!")

      # With specific provider
      client = Llm::Client.new(provider: :claude)
      response = client.generate("Hello, Claude!")

      # With automatic fallback
      client = Llm::Client.with_fallback
      response = client.generate("Hello!")

      # Chat mode
      messages = [
        { role: "user", content: "Hello!" },
        { role: "assistant", content: "Hi there!" },
        { role: "user", content: "How are you?" }
      ]
      response = client.chat(messages)

      Available Rake Tasks:
      ---------------------
      rake llm:status          Show configuration status
      rake llm:test            Test all providers
      rake llm:clear_cache     Clear LLM response cache
      rake llm:help            Show this help
      rake llm:openrouter_test Test OpenRouter connection
      rake llm:migrate_to_openrouter  Migration guide to OpenRouter
    HELP
  end

  desc "Test OpenRouter connection and show available models"
  task openrouter_test: :environment do
    unless ENV["OPENROUTER_API_KEY"].present?
      puts "❌ OPENROUTER_API_KEY not set"
      puts "Sign up at https://openrouter.ai/ and add your key to .env"
      exit 1
    end

    client = Llm::Client.new(provider: :openrouter)

    if client.available?
      puts "✅ OpenRouter connection successful!"
      puts "\nTesting generation..."

      response = client.generate("Say 'Hello from OpenRouter!' in a cheerful way.")
      puts "Response: #{response}"

      puts "\n💡 Tip: You can change models by setting OPENROUTER_MODEL in .env"
      puts "Popular options:"
      puts "  - openai/gpt-4o-mini (default, fast & cheap)"
      puts "  - anthropic/claude-3.5-sonnet (best quality)"
      puts "  - google/gemini-flash-1.5 (good balance)"
    else
      puts "❌ OpenRouter connection failed"
      puts "Check your API key and internet connection"
    end
  end

  desc "Migrate from individual providers to OpenRouter"
  task migrate_to_openrouter: :environment do
    if ENV["OPENROUTER_API_KEY"].present?
      puts "✅ OpenRouter already configured!"
      exit 0
    end

    puts "🔄 OpenRouter Migration Assistant"
    puts "================================="
    puts "\nOpenRouter provides access to all major LLMs with a single API key."
    puts "Benefits:"
    puts "  - One API key instead of three"
    puts "  - Access to 100+ models"
    puts "  - Automatic fallbacks"
    puts "  - Pay-per-use pricing"
    puts "\nTo migrate:"
    puts "1. Sign up at https://openrouter.ai/"
    puts "2. Add OPENROUTER_API_KEY to your .env file"
    puts "3. Set LLM_PROVIDER=openrouter"
    puts "4. Remove old provider API keys (optional)"
    puts "\nYour existing provider keys will continue to work if you prefer."
  end

  private

  def test_provider(provider, config)
    print "#{provider.to_s.capitalize.ljust(8)}: "

    begin
      adapter = Llm::AdapterFactory.create(provider)

      if adapter.available?
        model = config.model_for_provider(provider)
        puts "✅ Available (#{model})"
      else
        puts "❌ API key missing"
      end
    rescue => e
      puts "❌ Error: #{e.message}"
    end
  end

  def test_provider_generation(provider, prompt)
    print "Testing #{provider.to_s.capitalize}... "

    begin
      client = Llm::Client.new(provider: provider)

      start_time = Time.current
      response = client.generate(prompt, max_tokens: 10)
      duration = ((Time.current - start_time) * 1000).round(2)

      if response&.strip&.include?("4")
        puts "✅ Success (#{duration}ms) - Response: #{response.strip}"
      else
        puts "⚠️  Unexpected response (#{duration}ms) - Response: #{response&.strip}"
      end
    rescue => e
      puts "❌ Failed - #{e.message}"
    end
  end
end
