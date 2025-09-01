module AssistantsHelper
  def llm_providers_and_models
    {
      'openai' => {
        name: 'OpenAI',
        models: [
          { value: 'gpt-4o', name: 'GPT-4o (Latest)', description: 'Most capable, multimodal' },
          { value: 'gpt-4o-mini', name: 'GPT-4o Mini', description: 'Affordable, intelligent small model' },
          { value: 'gpt-4-turbo', name: 'GPT-4 Turbo', description: 'High intelligence, 128k context' },
          { value: 'gpt-4', name: 'GPT-4', description: 'High intelligence, 8k context' },
          { value: 'gpt-3.5-turbo', name: 'GPT-3.5 Turbo', description: 'Fast and affordable' }
        ]
      },
      'anthropic' => {
        name: 'Anthropic',
        models: [
          { value: 'claude-3-5-sonnet-20241022', name: 'Claude 3.5 Sonnet', description: 'Most intelligent Claude model' },
          { value: 'claude-3-5-haiku-20241022', name: 'Claude 3.5 Haiku', description: 'Fast and affordable' },
          { value: 'claude-3-opus-20240229', name: 'Claude 3 Opus', description: 'Powerful model for complex tasks' },
          { value: 'claude-3-sonnet-20240229', name: 'Claude 3 Sonnet', description: 'Balanced performance' },
          { value: 'claude-3-haiku-20240307', name: 'Claude 3 Haiku', description: 'Fastest Claude model' }
        ]
      },
      'google' => {
        name: 'Google',
        models: [
          { value: 'gemini-2.0-flash-exp', name: 'Gemini 2.0 Flash (Experimental)', description: 'Latest experimental model' },
          { value: 'gemini-2.5-pro', name: 'Gemini 2.5 Pro', description: 'Most advanced Gemini model' },
          { value: 'gemini-1.5-pro', name: 'Gemini 1.5 Pro', description: 'Advanced reasoning, 2M context' },
          { value: 'gemini-1.5-flash', name: 'Gemini 1.5 Flash', description: 'Fast and versatile' },
          { value: 'gemini-1.5-flash-8b', name: 'Gemini 1.5 Flash-8B', description: 'Efficient small model' }
        ]
      },
      'openrouter' => {
        name: 'OpenRouter',
        models: [
          # Google Models
          { value: 'google/gemini-2.5-pro', name: 'Gemini 2.5 Pro', description: 'Latest Google model, multimodal' },
          { value: 'google/gemini-pro-1.5', name: 'Gemini 1.5 Pro', description: 'Advanced reasoning, 2M context' },
          { value: 'google/gemini-flash-1.5', name: 'Gemini 1.5 Flash', description: 'Fast and efficient' },
          
          # Anthropic Models
          { value: 'anthropic/claude-3.5-sonnet', name: 'Claude 3.5 Sonnet', description: 'Most intelligent Claude model' },
          { value: 'anthropic/claude-3-opus', name: 'Claude 3 Opus', description: 'Powerful for complex tasks' },
          { value: 'anthropic/claude-3-haiku', name: 'Claude 3 Haiku', description: 'Fast and affordable Claude' },
          
          # OpenAI Models
          { value: 'openai/gpt-4o', name: 'GPT-4o', description: 'Latest multimodal GPT-4' },
          { value: 'openai/gpt-4o-mini', name: 'GPT-4o Mini', description: 'Affordable GPT-4 variant' },
          { value: 'openai/gpt-4-turbo', name: 'GPT-4 Turbo', description: '128k context window' },
          { value: 'openai/gpt-3.5-turbo', name: 'GPT-3.5 Turbo', description: 'Fast and cost-effective' },
          
          # Meta Llama Models
          { value: 'meta-llama/llama-3.1-405b-instruct', name: 'Llama 3.1 405B', description: 'Largest open model' },
          { value: 'meta-llama/llama-3.1-70b-instruct', name: 'Llama 3.1 70B', description: 'Powerful open model' },
          { value: 'meta-llama/llama-3.1-8b-instruct', name: 'Llama 3.1 8B', description: 'Efficient open model' },
          
          # xAI Grok
          { value: 'x-ai/grok-2', name: 'Grok 2', description: 'xAI\'s latest model' },
          { value: 'x-ai/grok-2-mini', name: 'Grok 2 Mini', description: 'Smaller, faster Grok' },
          
          # Other Popular Models
          { value: 'mistralai/mistral-large', name: 'Mistral Large', description: 'European AI model' },
          { value: 'deepseek/deepseek-chat', name: 'DeepSeek Chat', description: 'Chinese AI model' },
          { value: 'cohere/command-r-plus', name: 'Command R+', description: 'Cohere\'s flagship model' }
        ]
      }
    }
  end

  def provider_configured?(provider)
    case provider
    when 'openai'
      ENV['OPENAI_API_KEY'].present?
    when 'anthropic'
      ENV['CLAUDE_API_KEY'].present? || ENV['ANTHROPIC_API_KEY'].present?
    when 'google'
      ENV['GEMINI_API_KEY'].present? || ENV['GOOGLE_GEMINI_API_KEY'].present?
    when 'openrouter'
      ENV['OPENROUTER_API_KEY'].present?
    else
      false
    end
  end

  def default_provider
    if ENV['LLM_PROVIDER'] == 'openrouter' && provider_configured?('openrouter')
      'openrouter'
    elsif provider_configured?('openai')
      'openai'
    elsif provider_configured?('anthropic')
      'anthropic'
    elsif provider_configured?('google')
      'google'
    else
      llm_providers_and_models.keys.first
    end
  end

  def default_model_for_provider(provider)
    providers = llm_providers_and_models
    providers.dig(provider, :models, 0, :value) || ''
  end
end