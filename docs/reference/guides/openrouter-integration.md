# OpenRouter Integration Guide

## Overview

OpenRouter provides unified access to 100+ AI models through a single API key, dramatically simplifying AI/LLM integration in your Rails application. Instead of managing separate accounts and API keys for OpenAI, Anthropic, and Google, you can use one key to access all providers.

## Why OpenRouter?

### Benefits

1. **Single API Key** - Replace multiple provider API keys with one
2. **100+ Models** - Access models you might not have direct access to
3. **Automatic Fallbacks** - Built-in reliability across providers
4. **Pay-Per-Use** - No monthly subscriptions, pay only for what you use
5. **Unified Interface** - Same API format for all providers
6. **Lower Barrier** - No need to create accounts with multiple providers

### Trade-offs

1. **Cost Premium** - Approximately 10-20% markup over direct API access
2. **Additional Dependency** - Relies on OpenRouter's availability
3. **Privacy Considerations** - API traffic routes through OpenRouter
4. **Feature Limitations** - Can't use provider-specific features

## Quick Start

### 1. Sign Up for OpenRouter

Visit [https://openrouter.ai/](https://openrouter.ai/) and create an account.

### 2. Configure Your Application

```bash
# Edit your .env file
LLM_PROVIDER=openrouter
OPENROUTER_API_KEY=sk-or-v1-your-key-here

# Optional: Choose a specific model (defaults to gpt-4o-mini)
# OPENROUTER_MODEL=anthropic/claude-3.5-sonnet
```

### 3. Test Your Configuration

```bash
# Check if OpenRouter is configured
rake llm:status

# Test OpenRouter connection
rake llm:openrouter_test

# Test all providers
rake llm:test
```

## Usage Examples

### Basic Generation

```ruby
# Create a client (uses OpenRouter by default with new configuration)
client = Llm::Client.new
response = client.generate("Explain Ruby on Rails in one sentence")
puts response
```

### Using Specific Models

```ruby
# Use Claude 3.5 Sonnet
client = Llm::Client.new(model: "anthropic/claude-3.5-sonnet")
response = client.generate("Write a haiku about Ruby")

# Use GPT-4
client = Llm::Client.new(model: "openai/gpt-4o")
response = client.generate("Design a REST API for a todo app")

# Use Gemini Pro
client = Llm::Client.new(model: "google/gemini-pro-1.5")
response = client.generate("What's the weather like?")
```

### Chat Conversations

```ruby
messages = [
  { role: "user", content: "Hello! I'm building a Rails app." },
  { role: "assistant", content: "Great! What kind of app are you building?" },
  { role: "user", content: "A project management tool" }
]

client = Llm::Client.new
response = client.chat(messages)
```

### With Options

```ruby
client = Llm::Client.new
response = client.generate(
  "Write a comprehensive guide to Rails routing",
  max_tokens: 2000,
  temperature: 0.7
)
```

## Available Models

OpenRouter provides access to models from all major providers:

### OpenAI Models
- `openai/gpt-4o` - Most capable, best for complex tasks
- `openai/gpt-4o-mini` - Fast and affordable (default)
- `openai/gpt-4-turbo` - Previous generation, still very capable

### Anthropic Models
- `anthropic/claude-3.5-sonnet` - Best overall quality
- `anthropic/claude-3-opus` - Most capable Claude model
- `anthropic/claude-3-haiku` - Fast and affordable

### Google Models
- `google/gemini-pro-1.5` - Latest Gemini model
- `google/gemini-flash-1.5` - Fast and efficient
- `google/gemini-flash-2.0` - Newest flash model

### Open Source Models
- `meta-llama/llama-3.1-70b` - Open source alternative
- `mistralai/mixtral-8x22b` - Powerful open model
- And many more...

## Configuration Options

### Environment Variables

```bash
# Required
OPENROUTER_API_KEY=sk-or-v1-your-key-here

# Optional
LLM_PROVIDER=openrouter              # Set OpenRouter as default
OPENROUTER_MODEL=openai/gpt-4o-mini  # Default model to use
LLM_FALLBACK_PROVIDERS=openai,claude # Fallback to direct providers
LLM_CACHE_ENABLED=true               # Cache responses
LLM_MAX_RETRIES=3                    # Retry failed requests
LLM_TIMEOUT=30                       # Request timeout in seconds
```

### Runtime Configuration

```ruby
# Use a specific model for one request
client = Llm::Client.new
response = client.generate("Hello", model: "anthropic/claude-3.5-sonnet")

# Create a client with custom settings
client = Llm::Client.new(
  provider: :openrouter,
  model: "openai/gpt-4o",
  max_retries: 5,
  timeout: 60
)
```

## Migration Guide

### From Individual Providers

If you're currently using individual API keys:

1. **Keep existing keys** - They'll continue to work as fallbacks
2. **Add OpenRouter** - Add `OPENROUTER_API_KEY` to your `.env`
3. **Update provider** - Change `LLM_PROVIDER=openrouter`
4. **Test thoroughly** - Run `rake llm:test` to verify

### Gradual Migration

```bash
# Step 1: Add OpenRouter as a fallback
LLM_PROVIDER=openai  # Keep existing
LLM_FALLBACK_PROVIDERS=openrouter
OPENROUTER_API_KEY=sk-or-v1-xxx

# Step 2: Test with OpenRouter
rake llm:openrouter_test

# Step 3: Switch primary provider
LLM_PROVIDER=openrouter
LLM_FALLBACK_PROVIDERS=openai,claude  # Keep direct access as fallback

# Step 4: Remove old keys (optional)
# Once confident, you can remove individual API keys
```

## Cost Considerations

OpenRouter charges a small premium (typically 10-20%) over direct API access:

- **GPT-4o-mini**: ~$0.00018 per 1K tokens (vs $0.00015 direct)
- **Claude 3.5 Sonnet**: ~$0.0036 per 1K tokens (vs $0.003 direct)
- **Gemini Flash**: ~$0.00012 per 1K tokens (vs $0.0001 direct)

For most applications, the convenience outweighs the small cost increase.

## Troubleshooting

### Common Issues

1. **"Invalid API key"**
   - Verify your key starts with `sk-or-v1-`
   - Check for trailing spaces in `.env`
   - Ensure the key is active on OpenRouter dashboard

2. **"Model not found"**
   - Use the exact model name from OpenRouter docs
   - Some models require special access or payment

3. **"Rate limit exceeded"**
   - OpenRouter has its own rate limits
   - Consider implementing request queuing
   - Check your usage on OpenRouter dashboard

### Debug Mode

```ruby
# Enable debug logging
ENV['DEBUG'] = 'true'
client = Llm::Client.new
client.generate("Test")  # Will log full request/response
```

## Best Practices

1. **Model Selection**
   - Use `gpt-4o-mini` for most tasks (fast & cheap)
   - Use `claude-3.5-sonnet` for quality writing
   - Use `gpt-4o` for complex reasoning
   - Use open models for privacy-sensitive data

2. **Error Handling**
   ```ruby
   begin
     response = client.generate(prompt)
   rescue Llm::RateLimitError => e
     # Handle rate limits
     sleep(60) and retry
   rescue Llm::AuthenticationError => e
     # Handle auth errors
     Rails.logger.error("OpenRouter auth failed: #{e.message}")
   end
   ```

3. **Caching**
   - Enable caching for repeated queries
   - Set appropriate TTL based on your use case
   - Clear cache when switching models

4. **Monitoring**
   - Track usage on OpenRouter dashboard
   - Set up billing alerts
   - Monitor response times and errors

## Advanced Features

### Streaming Responses

```ruby
client = Llm::Client.new
client.stream("Write a long story") do |chunk|
  print chunk  # Print as it's generated
end
```

### Custom Headers

OpenRouter uses HTTP headers for additional context:

```ruby
# The adapter automatically sets these headers:
# - HTTP-Referer: Your app URL
# - X-Title: Your app name
```

### Provider-Specific Features

While OpenRouter standardizes the API, you can still access provider-specific models and their unique capabilities through the unified interface.

## Security Considerations

1. **API Key Storage**
   - Never commit API keys to git
   - Use environment variables
   - Rotate keys regularly

2. **Request Validation**
   - Sanitize user input before sending to AI
   - Implement rate limiting in your app
   - Log requests for audit purposes

3. **Response Handling**
   - Don't execute AI-generated code directly
   - Validate AI responses before using
   - Consider content filtering for user-facing features

## Support and Resources

- **OpenRouter Documentation**: https://openrouter.ai/docs
- **Model Pricing**: https://openrouter.ai/models
- **Status Page**: https://status.openrouter.ai/
- **Community Discord**: Available through OpenRouter site

## Conclusion

OpenRouter integration simplifies AI/LLM usage in your Rails application by providing a single, unified interface to multiple providers. While there's a small cost premium, the benefits of simplified setup, automatic fallbacks, and access to 100+ models make it an excellent choice for most applications.

For applications requiring direct provider access or specific provider features, the template still supports traditional individual API key configuration.