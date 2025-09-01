# AI/LLM Integration Guide

This guide documents how to use the AI/LLM services integrated into this Rails application.

## Overview

The application supports multiple AI providers through a unified interface:
- **OpenAI** (GPT-4, GPT-3.5)
- **Anthropic Claude** (Claude 3.5 Sonnet, Claude 3 Opus)
- **Google Gemini** (Gemini 2.5 Pro)

## Configuration

### Environment Variables
Set these in your `.env` file:

```bash
# Primary provider (openai, claude, or gemini)
LLM_PROVIDER=openai

# API Keys
OPENAI_API_KEY=sk-...
CLAUDE_API_KEY=sk-ant-...
GEMINI_API_KEY=...

# Model Selection (optional)
OPENAI_MODEL=gpt-4o-mini
CLAUDE_MODEL=claude-3-5-sonnet-20241022
GEMINI_MODEL=gemini-2.5-pro

# Fallback providers (comma-separated)
LLM_FALLBACK_PROVIDERS=claude,gemini

# Caching (optional)
LLM_CACHE_ENABLED=true
LLM_CACHE_TTL=3600
```

### Testing Configuration
```bash
# Check configuration
rake llm:status

# Test all providers
rake llm:test

# Clear cache
rake llm:clear_cache
```

## Architecture

### Service Layer Structure
```
app/services/llm/
├── adapter_factory.rb       # Creates appropriate adapter
├── base_adapter.rb          # Abstract base class
├── claude_adapter.rb        # Claude implementation
├── gemini_adapter.rb        # Gemini implementation
├── openai_adapter.rb        # OpenAI implementation
├── openai_image_adapter.rb  # Image generation
├── client.rb                # Main client interface
├── configuration.rb         # Config management
└── [feature]_service.rb     # Feature-specific services
```

### Key Components

1. **Client** - Main interface for all LLM operations
2. **Adapters** - Provider-specific implementations
3. **Services** - Business logic for specific features
4. **Configuration** - Centralized config management

## Basic Usage

### Simple Text Generation
```ruby
# Using the default provider
client = Llm::Client.new
response = client.generate(
  prompt: "Write a brief product description for a todo app"
)
puts response.content

# Using a specific provider
client = Llm::Client.new(provider: :claude)
response = client.generate(
  prompt: "Explain Ruby on Rails in simple terms",
  max_tokens: 200
)
```

### Structured Prompts
```ruby
# Using the prompt builder
prompt = Llm::PromptBuilderService.build do |p|
  p.system("You are a helpful coding assistant")
  p.user("Write a Ruby method to calculate fibonacci numbers")
  p.assistant("Here's a Ruby method for calculating Fibonacci numbers:")
  p.user("Now make it more efficient")
end

response = client.generate(prompt: prompt)
```

### Streaming Responses
```ruby
client.generate(
  prompt: "Write a long story about Rails development",
  stream: true
) do |chunk|
  print chunk.content
end
```

## Feature-Specific Services

### PRD Generator Service
Generates Product Requirements Documents:

```ruby
# In controller or job
app_project = AppProject.find(params[:id])
service = Llm::PrdGeneratorService.new(app_project)

# Generate PRD
prd = service.generate

# Access generated content
puts prd.content
puts prd.metadata[:tokens_used]
```

### Task Decomposition Service
Breaks down PRDs into actionable tasks:

```ruby
service = Llm::TaskDecompositionService.new(app_project)
tasks = service.generate

# Returns structured task data
tasks.each do |task|
  puts "#{task[:priority]} - #{task[:title]}"
  puts "  Description: #{task[:description]}"
  puts "  Estimate: #{task[:estimate]}"
end
```

### Claude Context Generator
Creates context files for Claude Code:

```ruby
service = Llm::ClaudeMdGeneratorService.new(app_project)
context = service.generate

# Save to file
File.write("CLAUDE.md", context.content)
```

### Logo Generator Service
Creates logos using DALL-E:

```ruby
service = Llm::LogoGeneratorService.new(app_project)
logo_url = service.generate(
  style: "minimalist",
  colors: ["blue", "white"]
)

# Download and attach to model
app_project.logo.attach(
  io: URI.open(logo_url),
  filename: "logo.png"
)
```

### Marketing Page Generator
Generates marketing copy:

```ruby
service = Llm::MarketingPageGeneratorService.new(app_project)
marketing_content = service.generate

# Returns HTML-formatted content
app_project.update!(marketing_content: marketing_content)
```

## Advanced Features

### Custom Parameters
```ruby
response = client.generate(
  prompt: "Complex technical question",
  model: "gpt-4",           # Override default model
  temperature: 0.7,         # Creativity (0-1)
  max_tokens: 1000,         # Response length
  top_p: 0.9,              # Nucleus sampling
  frequency_penalty: 0.5,   # Reduce repetition
  presence_penalty: 0.5,    # Encourage new topics
  response_format: { type: "json_object" }  # JSON mode
)
```

### Error Handling
```ruby
begin
  response = client.generate(prompt: "Hello")
rescue Llm::RateLimitError => e
  # Handle rate limiting
  retry_after = e.retry_after
  Rails.logger.warn "Rate limited, retry after #{retry_after}s"
  
rescue Llm::AuthenticationError => e
  # Handle auth errors
  Rails.logger.error "Authentication failed: #{e.message}"
  
rescue Llm::APIError => e
  # Handle general API errors
  Rails.logger.error "API error: #{e.message}"
end
```

### Fallback Providers
```ruby
# Automatic fallback on failure
client = Llm::Client.new(
  fallback_providers: [:claude, :gemini]
)

# Will try OpenAI first, then Claude, then Gemini
response = client.generate(prompt: "Hello")
puts "Used provider: #{response.metadata[:provider]}"
```

### Response Caching
```ruby
# Enable caching for repeated queries
client = Llm::Client.new(cache_enabled: true)

# First call hits API
response1 = client.generate(prompt: "What is Rails?")

# Second call uses cache
response2 = client.generate(prompt: "What is Rails?")

# Force fresh response
response3 = client.generate(
  prompt: "What is Rails?",
  cache: false
)
```

## Creating Custom Services

### Service Template
```ruby
# app/services/llm/custom_feature_service.rb
module Llm
  class CustomFeatureService
    def initialize(model)
      @model = model
      @client = Llm::Client.new
    end
    
    def generate
      prompt = build_prompt
      response = @client.generate(
        prompt: prompt,
        temperature: 0.7,
        max_tokens: 500
      )
      
      process_response(response)
    end
    
    private
    
    def build_prompt
      <<~PROMPT
        Based on the following information:
        #{@model.to_json}
        
        Please generate...
      PROMPT
    end
    
    def process_response(response)
      # Parse and structure the response
      {
        content: response.content,
        metadata: response.metadata
      }
    end
  end
end
```

### Using in Background Jobs
```ruby
class AiGenerationJob < ApplicationJob
  def perform(app_project_id)
    app_project = AppProject.find(app_project_id)
    
    # Update status
    app_project.update!(status: 'generating')
    
    # Generate content
    prd_service = Llm::PrdGeneratorService.new(app_project)
    prd = prd_service.generate
    
    # Save results
    app_project.update!(
      prd_content: prd.content,
      status: 'completed'
    )
    
  rescue => e
    app_project.update!(
      status: 'failed',
      error_message: e.message
    )
    raise
  end
end
```

## Best Practices

### 1. Prompt Engineering
```ruby
# Be specific and structured
prompt = <<~PROMPT
  Role: You are an expert Ruby on Rails developer.
  
  Task: Review the following code and suggest improvements.
  
  Code:
  ```ruby
  #{code}
  ```
  
  Requirements:
  1. Focus on performance improvements
  2. Maintain backwards compatibility
  3. Follow Rails best practices
  
  Output format: Markdown with code examples
PROMPT
```

### 2. Token Management
```ruby
# Monitor token usage
response = client.generate(prompt: prompt)
tokens_used = response.metadata[:usage][:total_tokens]

# Log high usage
if tokens_used > 1000
  Rails.logger.warn "High token usage: #{tokens_used}"
end
```

### 3. Rate Limiting
```ruby
# Implement client-side rate limiting
class RateLimitedClient
  def initialize
    @client = Llm::Client.new
    @limiter = Throttle.new(calls: 10, period: 60)
  end
  
  def generate(prompt:)
    @limiter.throttle do
      @client.generate(prompt: prompt)
    end
  end
end
```

### 4. Response Validation
```ruby
# Validate AI responses
def validate_response(response)
  # Check for completeness
  return false if response.content.blank?
  
  # Check for errors
  return false if response.content.include?("I cannot")
  
  # Validate format if expecting JSON
  if expecting_json?
    begin
      JSON.parse(response.content)
      true
    rescue JSON::ParserError
      false
    end
  else
    true
  end
end
```

## Testing

### Mocking in Tests
```ruby
# spec/services/llm/prd_generator_service_spec.rb
RSpec.describe Llm::PrdGeneratorService do
  let(:app_project) { create(:app_project) }
  let(:service) { described_class.new(app_project) }
  
  before do
    # Mock the LLM client
    allow_any_instance_of(Llm::Client).to receive(:generate)
      .and_return(
        OpenStruct.new(
          content: "Generated PRD content",
          metadata: { tokens_used: 100 }
        )
      )
  end
  
  it "generates a PRD" do
    result = service.generate
    expect(result.content).to include("Generated PRD")
  end
end
```

### VCR for Integration Tests
```ruby
# spec/support/vcr.rb
VCR.configure do |config|
  config.filter_sensitive_data('<OPENAI_API_KEY>') { ENV['OPENAI_API_KEY'] }
  config.filter_sensitive_data('<CLAUDE_API_KEY>') { ENV['CLAUDE_API_KEY'] }
end

# In tests
it "generates real content", :vcr do
  response = client.generate(prompt: "Hello")
  expect(response.content).to be_present
end
```

## Monitoring

### Performance Tracking
```ruby
# Track generation time
start_time = Time.current
response = client.generate(prompt: prompt)
duration = Time.current - start_time

Rails.logger.info "LLM generation took #{duration}s"
```

### Cost Tracking
```ruby
# Track API costs
class CostTracker
  COSTS = {
    'gpt-4' => { input: 0.03, output: 0.06 },
    'gpt-3.5-turbo' => { input: 0.001, output: 0.002 },
    'claude-3-5-sonnet' => { input: 0.003, output: 0.015 }
  }
  
  def self.calculate(model, usage)
    costs = COSTS[model]
    return 0 unless costs
    
    input_cost = (usage[:prompt_tokens] / 1000.0) * costs[:input]
    output_cost = (usage[:completion_tokens] / 1000.0) * costs[:output]
    
    input_cost + output_cost
  end
end
```

## Troubleshooting

### Common Issues

1. **API Key Issues**
   ```bash
   # Check if keys are set
   rake llm:status
   
   # Test specific provider
   rails console
   > Llm::Client.new(provider: :openai).generate(prompt: "test")
   ```

2. **Model Not Available**
   ```ruby
   # Use available models
   client = Llm::Client.new
   response = client.generate(
     prompt: "Hello",
     model: "gpt-3.5-turbo"  # Fallback to cheaper model
   )
   ```

3. **Timeout Issues**
   ```ruby
   # Increase timeout for long operations
   client = Llm::Client.new(timeout: 120)  # 2 minutes
   ```

4. **Memory Issues with Streaming**
   ```ruby
   # Process chunks immediately
   File.open("output.txt", "w") do |file|
     client.generate(prompt: prompt, stream: true) do |chunk|
       file.write(chunk.content)
       file.flush  # Don't buffer in memory
     end
   end
   ```

## Security Considerations

1. **Never log sensitive prompts**
2. **Sanitize user input before sending to AI**
3. **Store API keys securely (use Rails credentials)**
4. **Implement rate limiting for user-facing features**
5. **Monitor for prompt injection attempts**
6. **Use content filtering for public-facing generations**