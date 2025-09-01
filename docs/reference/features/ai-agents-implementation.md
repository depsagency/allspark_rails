# AI Agents Implementation Guide

## Analysis Overview

This document outlines the implementation of AI agents in the Rails application using LangChainRB, based on comprehensive research of Ruby AI frameworks and the existing codebase architecture.

## Research Findings

### 1. Ruby AI Framework Landscape

After analyzing the Ruby ecosystem for AI agent frameworks, the key findings are:

- **LangChainRB** is the most mature Ruby equivalent to Python's LangChain
- It provides a complete agent orchestration system with tools, chains, and memory
- The `langchainrb_rails` gem offers deep Rails integration
- Active community with regular updates and good documentation

### 2. Existing Infrastructure Analysis

The codebase already has a robust LLM service layer:

```
app/services/llm/
├── base_adapter.rb          # Abstract adapter interface
├── client.rb               # Unified client with fallback support
├── configuration.rb        # Configuration management
├── adapter_factory.rb      # Factory pattern for providers
├── openai_adapter.rb       # OpenAI integration
├── claude_adapter.rb       # Anthropic Claude integration
├── gemini_adapter.rb       # Google Gemini integration
└── [various service implementations]
```

Key strengths:
- Multi-provider support with automatic fallback
- Caching layer for responses
- Error handling and retry logic
- Clean adapter pattern

### 3. Chat Component Integration Points

The existing chat system provides:
- Real-time messaging via ActionCable
- Thread-based conversations
- Typing indicators and read receipts
- Markdown support
- ViewComponent-based UI

This makes it ideal for AI assistant integration.

### 4. LangChainRB Assistant Architecture

Research revealed that `Langchain::Assistant` provides:
- Built-in tool management and execution
- Conversation thread handling
- Message history management
- Parallel tool calling capabilities
- ReAct (Reasoning + Acting) pattern implementation

## Implementation Strategy

### Core Principles

1. **Leverage Existing Infrastructure**: Adapt our LLM service layer to work with LangChainRB
2. **Direct Integration**: Use `Langchain::Assistant` directly rather than heavy abstraction
3. **Incremental Adoption**: Start simple, add complexity gradually
4. **Rails Best Practices**: Follow Rails conventions and patterns

### Architecture Decisions

1. **LLM Adapter Pattern**: Bridge existing LLM clients with LangChainRB expectations
2. **Tool as Service Objects**: Implement tools following Rails service object patterns
3. **Background Processing**: Use Sidekiq for long-running assistant operations
4. **Real-time Updates**: Leverage ActionCable for streaming responses

## Detailed Task List

### Phase 1: Foundation Setup (Days 1-2)

#### Task 1.1: Add Required Gems ✅ COMPLETED
**File**: `Gemfile`
```ruby
# AI Agent Support
gem 'langchainrb', '~> 0.16.0'  # Updated for compatibility
gem 'langchainrb_rails', '~> 0.1.12'  # Updated version

# Tool Dependencies
gem 'eqn', '~> 1.6'        # For calculator tool
gem 'safe_ruby', '~> 1.0'  # For Ruby code interpreter
gem 'tiktoken_ruby', '~> 0.0.9'  # For token counting

# Optional tool gems
gem 'google_search_results', '~> 2.2'  # For Google search tool
gem 'news-api', '~> 0.2'              # For news retrieval
```

**Actions Completed**:
1. ✅ Added gems to Gemfile with compatible versions
2. ✅ Ran `bundle install`
3. ✅ Verified gem compatibility
4. Document any version conflicts

#### Task 1.2: Run LangChainRB Rails Generator ✅ COMPLETED
**Command**: `rails generate langchainrb_rails:assistant chat_bot --llm=openai`

**Generated/Modified Files**:
- ✅ `app/models/assistant.rb` - Enhanced with UUID support and LLM adapter
- ✅ `app/models/assistant_message.rb` - Renamed from message.rb to avoid conflicts
- ✅ `db/migrate/*_create_assistants.rb` - Modified for UUIDs and added fields
- ✅ `db/migrate/*_create_messages.rb` - Renamed table to assistant_messages
- ✅ `db/migrate/*_rename_model_name_in_assistants.rb` - Fixed reserved word conflict

**Completed Tasks**:
1. ✅ Ran the generator and reviewed files
2. ✅ Modified models with UUID support and validations
3. ✅ Added proper indexes to migrations
4. ✅ Successfully ran migrations
5. ✅ Created test rake task to verify setup

#### Task 1.3: Create LLM Adapter Bridge ✅ COMPLETED
**File**: `app/services/llm/langchain_adapter.rb`

**Implemented Features**:
- ✅ Created adapter that bridges our LLM infrastructure with LangChainRB
- ✅ Implemented CustomLangchainLLM class that works with our existing clients
- ✅ Supports chat, complete, and stream methods
- ✅ Handles response format conversion automatically
- ✅ Includes error handling and logging
- ✅ Tested successfully with rake task

**Key Implementation Details**:
```ruby
# Convert our LLM client to LangChain-compatible LLM
def to_langchain_llm
  CustomLangchainLLM.new(client: @client)
end
```

**Completed Steps**:
1. ✅ Created adapter class in `app/services/llm/langchain_adapter.rb`
2. ✅ Mapped all required method signatures
3. ✅ Implemented response format conversion
4. ✅ Added comprehensive error handling
5. ✅ Verified with test setup rake task

#### Task 1.4: Extend Assistant Model
**File**: `app/models/assistant.rb`

```ruby
class Assistant < ApplicationRecord
  # Associations
  has_many :assistant_threads
  has_many :assistant_messages, through: :assistant_threads
  belongs_to :owner, polymorphic: true, optional: true
  
  # Validations
  validates :name, presence: true
  validates :instructions, presence: true
  validates :llm_provider, inclusion: { in: %w[custom openai anthropic] }
  
  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :for_user, ->(user) { where(owner: user).or(where(public: true)) }
  
  # Instance methods
  def build_langchain_assistant
    Langchain::Assistant.new(
      llm: build_llm_adapter,
      instructions: instructions,
      tools: build_tools,
      thread: thread_config
    )
  end
  
  private
  
  def build_llm_adapter
    case llm_provider
    when 'custom'
      LlmLangchainAdapter.new(Llm::Client.with_fallback(llm_options))
    when 'openai'
      Langchain::LLM::OpenAI.new(api_key: ENV['OPENAI_API_KEY'])
    when 'anthropic'
      Langchain::LLM::Anthropic.new(api_key: ENV['ANTHROPIC_API_KEY'])
    end
  end
  
  def build_tools
    # Tool instantiation logic
  end
end
```

**Tasks**:
1. Add associations and validations
2. Implement builder methods
3. Add configuration options
4. Create factory for testing

### Phase 2: Basic Chat Bot Implementation (Days 3-5)

#### Task 2.1: Create Base Tool Class
**File**: `app/tools/base_tool.rb`

```ruby
module Tools
  class BaseTool < Langchain::Tool::Base
    include Rails.application.routes.url_helpers
    
    attr_reader :user, :context
    
    def initialize(user: nil, context: nil, **options)
      @user = user
      @context = context
      @options = options
      super()
    end
    
    protected
    
    def authorize!(action, resource)
      return true unless user
      
      policy = Pundit.policy(user, resource)
      return true if policy.public_send("#{action}?")
      
      raise Pundit::NotAuthorizedError
    end
    
    def log_usage(input, output)
      ToolUsageLog.create!(
        tool_name: self.class::NAME,
        user: user,
        input: input,
        output: output,
        context: context
      )
    end
  end
end
```

**Implementation**:
1. Create base class with common functionality
2. Add authorization helpers
3. Implement usage logging
4. Add error handling wrapper

#### Task 2.2: Implement Chat Integration Tool
**File**: `app/tools/chat_integration_tool.rb`

```ruby
module Tools
  class ChatIntegrationTool < BaseTool
    NAME = "send_chat_message"
    DESCRIPTION = "Send a message to the current chat thread"
    
    def initialize(chat_thread:, **options)
      @chat_thread = chat_thread
      super(**options)
    end
    
    def execute(input:)
      # Parse input
      message_content = input["message"]
      message_type = input["type"] || "text"
      
      # Validate
      return error_response("Message cannot be blank") if message_content.blank?
      
      # Create message
      message = @chat_thread.messages.create!(
        user: assistant_user,
        content: message_content,
        metadata: { type: message_type, assistant_generated: true }
      )
      
      # Log usage
      log_usage(input, { message_id: message.id })
      
      # Return success
      {
        success: true,
        message_id: message.id,
        timestamp: message.created_at
      }
    rescue => e
      error_response(e.message)
    end
    
    private
    
    def assistant_user
      @assistant_user ||= User.find_by(email: 'assistant@system.local') ||
                          User.create!(
                            email: 'assistant@system.local',
                            name: 'AI Assistant',
                            password: SecureRandom.hex(32)
                          )
    end
    
    def error_response(message)
      { success: false, error: message }
    end
  end
end
```

**Steps**:
1. Implement tool class
2. Add input validation
3. Integrate with chat system
4. Handle errors gracefully
5. Test with real chat threads

#### Task 2.3: Create Calculator Tool
**File**: `app/tools/calculator_tool.rb`

```ruby
module Tools
  class CalculatorTool < BaseTool
    NAME = "calculator"
    DESCRIPTION = "Perform mathematical calculations"
    
    def execute(input:)
      expression = input["expression"] || input
      
      # Sanitize input
      sanitized = sanitize_expression(expression)
      
      # Evaluate
      result = Eqn::Calculator.calc(sanitized)
      
      # Log and return
      log_usage(input, { result: result })
      
      {
        expression: expression,
        result: result,
        formatted: format_number(result)
      }
    rescue => e
      { error: "Invalid expression: #{e.message}" }
    end
    
    private
    
    def sanitize_expression(expr)
      # Remove potentially dangerous characters
      expr.to_s.gsub(/[^0-9+\-*\/().\s]/, '')
    end
    
    def format_number(num)
      # Format with appropriate precision
      num.to_f.round(10).to_s.sub(/\.0+$/, '')
    end
  end
end
```

#### Task 2.4: Create Database Query Tool
**File**: `app/tools/database_query_tool.rb`

```ruby
module Tools
  class DatabaseQueryTool < BaseTool
    NAME = "query_database"
    DESCRIPTION = "Query application database for information"
    
    ALLOWED_MODELS = %w[User ChatThread ChatMessage].freeze
    
    def execute(input:)
      model_name = input["model"]
      action = input["action"]
      conditions = input["conditions"] || {}
      
      # Validate model
      return error_response("Invalid model") unless ALLOWED_MODELS.include?(model_name)
      
      # Get model class
      model_class = model_name.constantize
      
      # Authorize
      authorize!(:read, model_class)
      
      # Execute query
      result = case action
      when "count"
        execute_count(model_class, conditions)
      when "find"
        execute_find(model_class, conditions)
      when "search"
        execute_search(model_class, conditions)
      else
        error_response("Invalid action")
      end
      
      log_usage(input, result)
      result
    rescue => e
      error_response(e.message)
    end
    
    private
    
    def execute_count(model_class, conditions)
      scope = build_scope(model_class, conditions)
      { count: scope.count }
    end
    
    def execute_find(model_class, conditions)
      scope = build_scope(model_class, conditions)
      records = scope.limit(10).map do |record|
        serialize_record(record)
      end
      { records: records, total: scope.count }
    end
    
    def build_scope(model_class, conditions)
      scope = model_class.all
      
      # Apply safe conditions
      conditions.each do |key, value|
        next unless model_class.column_names.include?(key.to_s)
        scope = scope.where(key => value)
      end
      
      scope
    end
    
    def serialize_record(record)
      # Safely serialize attributes
      record.attributes.slice("id", "name", "created_at", "updated_at")
    end
  end
end
```

#### Task 2.5: Create Assistant Chat Channel
**File**: `app/channels/assistant_chat_channel.rb`

```ruby
class AssistantChatChannel < ApplicationCable::Channel
  def subscribed
    @thread = ChatThread.find(params[:thread_id])
    @assistant_thread = find_or_create_assistant_thread
    
    stream_from channel_name
    stream_from "#{channel_name}_status"
  end
  
  def send_message(data)
    # Create user message
    user_message = @thread.messages.create!(
      user: current_user,
      content: data["message"]
    )
    
    # Broadcast user message immediately
    broadcast_message(user_message)
    
    # Process with assistant in background
    AssistantProcessorJob.perform_later(
      assistant_thread_id: @assistant_thread.id,
      message: data["message"],
      chat_thread_id: @thread.id,
      user_id: current_user.id
    )
    
    # Send typing indicator
    broadcast_typing_status(true)
  end
  
  def unsubscribed
    # Cleanup if needed
  end
  
  private
  
  def find_or_create_assistant_thread
    @thread.assistant_thread || create_assistant_thread
  end
  
  def create_assistant_thread
    assistant = Assistant.active.first # Or based on configuration
    assistant.assistant_threads.create!(
      user: current_user,
      metadata: { chat_thread_id: @thread.id }
    )
  end
  
  def channel_name
    "assistant_chat_#{@thread.id}"
  end
  
  def broadcast_message(message)
    ActionCable.server.broadcast(
      channel_name,
      {
        type: 'message',
        message: ChatMessageSerializer.new(message).serializable_hash
      }
    )
  end
  
  def broadcast_typing_status(typing)
    ActionCable.server.broadcast(
      "#{channel_name}_status",
      {
        type: 'typing',
        typing: typing,
        user: 'AI Assistant'
      }
    )
  end
end
```

#### Task 2.6: Create Assistant Processor Job
**File**: `app/jobs/assistant_processor_job.rb`

```ruby
class AssistantProcessorJob < ApplicationJob
  queue_as :ai_assistant
  
  def perform(assistant_thread_id:, message:, chat_thread_id:, user_id:)
    @assistant_thread = AssistantThread.find(assistant_thread_id)
    @chat_thread = ChatThread.find(chat_thread_id)
    @user = User.find(user_id)
    
    # Build assistant
    assistant = build_assistant
    
    # Process message
    response = assistant.add_message_and_run!(
      content: message,
      role: "user"
    )
    
    # Handle response
    handle_response(response)
    
  rescue => e
    handle_error(e)
  ensure
    # Clear typing indicator
    broadcast_typing_status(false)
  end
  
  private
  
  def build_assistant
    @assistant_thread.assistant.build_langchain_assistant
  end
  
  def handle_response(response)
    # Create assistant message
    assistant_message = @chat_thread.messages.create!(
      user: assistant_user,
      content: response.content,
      metadata: { 
        assistant_thread_id: @assistant_thread.id,
        tool_calls: response.tool_calls
      }
    )
    
    # Broadcast to channel
    broadcast_message(assistant_message)
    
    # Save to assistant thread
    @assistant_thread.assistant_messages.create!(
      role: 'assistant',
      content: response.content,
      tool_calls: response.tool_calls
    )
  end
  
  def handle_error(error)
    Rails.logger.error "Assistant processing error: #{error.message}"
    
    error_message = @chat_thread.messages.create!(
      user: assistant_user,
      content: "I apologize, but I encountered an error processing your request. Please try again.",
      metadata: { error: error.message }
    )
    
    broadcast_message(error_message)
  end
  
  def broadcast_message(message)
    ActionCable.server.broadcast(
      "assistant_chat_#{@chat_thread.id}",
      {
        type: 'message',
        message: ChatMessageSerializer.new(message).serializable_hash
      }
    )
  end
  
  def broadcast_typing_status(typing)
    ActionCable.server.broadcast(
      "assistant_chat_#{@chat_thread.id}_status",
      {
        type: 'typing',
        typing: typing,
        user: 'AI Assistant'
      }
    )
  end
  
  def assistant_user
    @assistant_user ||= User.find_by(email: 'assistant@system.local')
  end
end
```

### Phase 3: External Integration Agent (Days 6-8)

#### Task 3.1: Create External Service Base
**File**: `app/services/external_services/base_service.rb`

```ruby
module ExternalServices
  class BaseService
    include HTTParty
    
    class ServiceError < StandardError; end
    class AuthenticationError < ServiceError; end
    class RateLimitError < ServiceError; end
    
    def initialize(user:)
      @user = user
      @credentials = user.external_credentials.find_by(service: service_name)
    end
    
    protected
    
    def service_name
      self.class.name.demodulize.underscore.gsub('_service', '')
    end
    
    def access_token
      @credentials&.access_token
    end
    
    def refresh_token_if_needed
      return unless @credentials&.expired?
      
      @credentials.refresh!
    end
    
    def handle_response(response)
      case response.code
      when 200..299
        response.parsed_response
      when 401
        raise AuthenticationError
      when 429
        raise RateLimitError
      else
        raise ServiceError, "HTTP #{response.code}: #{response.body}"
      end
    end
  end
end
```

#### Task 3.2: Implement Todoist Service
**File**: `app/services/external_services/todoist_service.rb`

```ruby
module ExternalServices
  class TodoistService < BaseService
    base_uri 'https://api.todoist.com/rest/v2'
    
    def tasks(filter = nil)
      refresh_token_if_needed
      
      options = {
        headers: authorization_header
      }
      options[:query] = { filter: filter } if filter
      
      response = self.class.get('/tasks', options)
      handle_response(response)
    end
    
    def create_task(content:, **attributes)
      refresh_token_if_needed
      
      response = self.class.post('/tasks',
        headers: authorization_header.merge('Content-Type' => 'application/json'),
        body: { content: content, **attributes }.to_json
      )
      
      handle_response(response)
    end
    
    def complete_task(task_id)
      refresh_token_if_needed
      
      response = self.class.post("/tasks/#{task_id}/close",
        headers: authorization_header
      )
      
      handle_response(response)
    end
    
    private
    
    def authorization_header
      { 'Authorization' => "Bearer #{access_token}" }
    end
  end
end
```

#### Task 3.3: Create Todoist Tool
**File**: `app/tools/todoist_tool.rb`

```ruby
module Tools
  class TodoistTool < BaseTool
    NAME = "todoist"
    DESCRIPTION = "Interact with Todoist tasks"
    
    def execute(input:)
      action = input["action"]
      
      # Ensure user has Todoist connected
      return error_response("Todoist not connected") unless todoist_connected?
      
      case action
      when "get_tasks"
        get_tasks(input["filter"])
      when "create_task"
        create_task(input["content"], input["attributes"] || {})
      when "complete_task"
        complete_task(input["task_id"])
      when "analyze_tasks"
        analyze_tasks
      else
        error_response("Unknown action: #{action}")
      end
    rescue ExternalServices::ServiceError => e
      error_response("Todoist error: #{e.message}")
    end
    
    private
    
    def get_tasks(filter = "today | overdue")
      tasks = todoist_service.tasks(filter)
      
      {
        tasks: tasks.map { |t| serialize_task(t) },
        count: tasks.size
      }
    end
    
    def create_task(content, attributes)
      task = todoist_service.create_task(content: content, **attributes)
      
      {
        success: true,
        task: serialize_task(task)
      }
    end
    
    def analyze_tasks
      today_tasks = todoist_service.tasks("today")
      
      analysis = {
        total: today_tasks.size,
        by_priority: group_by_priority(today_tasks),
        by_project: group_by_project(today_tasks),
        overdue: today_tasks.count { |t| t["due"] && Date.parse(t["due"]["date"]) < Date.current }
      }
      
      { analysis: analysis }
    end
    
    def todoist_service
      @todoist_service ||= ExternalServices::TodoistService.new(user: user)
    end
    
    def todoist_connected?
      user.external_credentials.exists?(service: 'todoist', status: 'active')
    end
    
    def serialize_task(task)
      {
        id: task["id"],
        content: task["content"],
        completed: task["is_completed"],
        priority: task["priority"],
        due: task["due"],
        labels: task["labels"]
      }
    end
    
    def group_by_priority(tasks)
      tasks.group_by { |t| t["priority"] }.transform_values(&:count)
    end
    
    def group_by_project(tasks)
      tasks.group_by { |t| t["project_id"] }.transform_values(&:count)
    end
  end
end
```

#### Task 3.4: Create Task Monitor Job
**File**: `app/jobs/task_monitor_job.rb`

```ruby
class TaskMonitorJob < ApplicationJob
  queue_as :low
  
  def perform(user_id:)
    user = User.find(user_id)
    return unless user.external_credentials.exists?(service: 'todoist', status: 'active')
    
    # Get AI-enabled assistant for user
    assistant = user.assistants.task_automation.first
    return unless assistant
    
    # Build Todoist tool
    todoist_tool = Tools::TodoistTool.new(user: user)
    
    # Get tasks marked for AI preparation
    tasks_response = todoist_tool.execute(
      input: { action: "get_tasks", filter: "@ai_prep" }
    )
    
    return if tasks_response[:tasks].blank?
    
    # Process each task
    tasks_response[:tasks].each do |task|
      process_task_with_ai(task, assistant, user)
    end
  end
  
  private
  
  def process_task_with_ai(task, assistant, user)
    # Create preparation prompt
    prompt = build_task_prep_prompt(task)
    
    # Get AI analysis
    langchain_assistant = assistant.build_langchain_assistant
    response = langchain_assistant.add_message_and_run!(
      content: prompt,
      role: "user"
    )
    
    # Create preparation document
    prep_doc = TaskPreparation.create!(
      user: user,
      external_task_id: task[:id],
      task_content: task[:content],
      ai_analysis: response.content,
      status: 'ready'
    )
    
    # Notify user
    notify_user(user, task, prep_doc)
    
  rescue => e
    Rails.logger.error "Task preparation error: #{e.message}"
  end
  
  def build_task_prep_prompt(task)
    <<~PROMPT
      Please help me prepare for this task: "#{task[:content]}"
      
      Provide:
      1. A breakdown of steps needed
      2. Any information I should gather beforehand
      3. Potential challenges or considerations
      4. Time estimate
      
      Context: This is due #{task[:due] ? "on #{task[:due]['date']}" : "with no specific deadline"}
    PROMPT
  end
  
  def notify_user(user, task, prep_doc)
    # Send notification via preferred channel
    if user.notification_preferences.chat?
      send_chat_notification(user, task, prep_doc)
    end
    
    if user.notification_preferences.email?
      TaskPrepMailer.task_ready(user, prep_doc).deliver_later
    end
  end
  
  def send_chat_notification(user, task, prep_doc)
    # Find or create AI notification thread
    thread = user.chat_threads.find_or_create_by(
      name: "AI Task Notifications",
      context_type: "TaskAutomation"
    )
    
    thread.messages.create!(
      user: assistant_user,
      content: format_notification_message(task, prep_doc)
    )
  end
  
  def format_notification_message(task, prep_doc)
    <<~MESSAGE
      📋 **Task Preparation Ready**
      
      I've prepared an analysis for your task: "#{task[:content]}"
      
      [View Full Preparation](/task_preparations/#{prep_doc.id})
      
      **Summary:**
      #{prep_doc.ai_analysis.split("\n").first(3).join("\n")}
    MESSAGE
  end
  
  def assistant_user
    @assistant_user ||= User.find_by(email: 'assistant@system.local')
  end
end
```

#### Task 3.5: OAuth Integration Controller
**File**: `app/controllers/oauth_controller.rb`

```ruby
class OauthController < ApplicationController
  before_action :authenticate_user!
  
  def authorize
    service = params[:service]
    
    case service
    when 'todoist'
      redirect_to todoist_auth_url
    when 'github'
      redirect_to github_auth_url
    else
      redirect_to dashboard_path, alert: "Unknown service: #{service}"
    end
  end
  
  def callback
    service = params[:service]
    
    case service
    when 'todoist'
      handle_todoist_callback
    when 'github'
      handle_github_callback
    else
      redirect_to dashboard_path, alert: "Unknown service: #{service}"
    end
  end
  
  private
  
  def todoist_auth_url
    params = {
      client_id: ENV['TODOIST_CLIENT_ID'],
      scope: 'data:read_write',
      state: generate_state_token,
      redirect_uri: oauth_callback_url(service: 'todoist')
    }
    
    "https://todoist.com/oauth/authorize?#{params.to_query}"
  end
  
  def handle_todoist_callback
    # Exchange code for token
    response = exchange_todoist_token(params[:code])
    
    # Save credentials
    current_user.external_credentials.create_or_update!(
      service: 'todoist',
      access_token: response['access_token'],
      refresh_token: response['refresh_token'],
      expires_at: Time.current + response['expires_in'].seconds,
      status: 'active'
    )
    
    # Schedule initial sync
    TaskMonitorJob.perform_later(user_id: current_user.id)
    
    redirect_to integrations_path, notice: "Todoist connected successfully!"
  rescue => e
    redirect_to integrations_path, alert: "Failed to connect Todoist: #{e.message}"
  end
  
  def exchange_todoist_token(code)
    response = HTTParty.post('https://todoist.com/oauth/access_token',
      body: {
        client_id: ENV['TODOIST_CLIENT_ID'],
        client_secret: ENV['TODOIST_CLIENT_SECRET'],
        code: code,
        redirect_uri: oauth_callback_url(service: 'todoist')
      }
    )
    
    raise "Token exchange failed" unless response.success?
    response.parsed_response
  end
  
  def generate_state_token
    SecureRandom.hex(16)
  end
end
```

### Phase 4: Advanced Features (Days 9-10)

#### Task 4.1: Implement RAG Support
**File**: `app/services/rag/document_processor.rb`

```ruby
module Rag
  class DocumentProcessor
    def initialize(vector_store: nil)
      @vector_store = vector_store || default_vector_store
    end
    
    def process_document(document)
      # Extract text
      text = extract_text(document)
      
      # Split into chunks
      chunks = split_into_chunks(text)
      
      # Generate embeddings and store
      chunks.each_with_index do |chunk, index|
        embedding = generate_embedding(chunk)
        
        @vector_store.add(
          id: "#{document.id}_chunk_#{index}",
          embedding: embedding,
          metadata: {
            document_id: document.id,
            chunk_index: index,
            content: chunk
          }
        )
      end
    end
    
    def search(query, limit: 5)
      # Generate query embedding
      query_embedding = generate_embedding(query)
      
      # Search vector store
      results = @vector_store.similarity_search(
        embedding: query_embedding,
        limit: limit
      )
      
      # Format results
      results.map do |result|
        {
          content: result[:metadata][:content],
          document_id: result[:metadata][:document_id],
          similarity: result[:similarity]
        }
      end
    end
    
    private
    
    def extract_text(document)
      case document.content_type
      when 'text/plain'
        document.blob.download
      when 'application/pdf'
        extract_pdf_text(document)
      else
        raise "Unsupported document type: #{document.content_type}"
      end
    end
    
    def split_into_chunks(text, chunk_size: 1000, overlap: 200)
      chunks = []
      position = 0
      
      while position < text.length
        chunk = text[position, chunk_size + overlap]
        chunks << chunk
        position += chunk_size
      end
      
      chunks
    end
    
    def generate_embedding(text)
      llm_client = Llm::Client.with_fallback
      response = llm_client.embed(text)
      response[:embedding]
    end
    
    def default_vector_store
      # Use configured vector store (Pinecone, Qdrant, etc.)
      VectorStore.default
    end
  end
end
```

#### Task 4.2: Create Knowledge Base Tool
**File**: `app/tools/knowledge_base_tool.rb`

```ruby
module Tools
  class KnowledgeBaseTool < BaseTool
    NAME = "search_knowledge"
    DESCRIPTION = "Search internal knowledge base and documentation"
    
    def execute(input:)
      query = input["query"]
      limit = input["limit"] || 5
      
      # Search using RAG
      results = search_knowledge_base(query, limit)
      
      # Format response
      {
        query: query,
        results: results,
        sources: extract_sources(results)
      }
    end
    
    private
    
    def search_knowledge_base(query, limit)
      processor = Rag::DocumentProcessor.new
      processor.search(query, limit: limit)
    end
    
    def extract_sources(results)
      document_ids = results.map { |r| r[:document_id] }.uniq
      
      Document.where(id: document_ids).map do |doc|
        {
          id: doc.id,
          title: doc.title,
          type: doc.document_type,
          url: document_url(doc)
        }
      end
    end
    
    def document_url(document)
      Rails.application.routes.url_helpers.document_url(document)
    end
  end
end
```

#### Task 4.3: Multi-Agent Coordinator
**File**: `app/services/agents/coordinator.rb`

```ruby
module Agents
  class Coordinator
    attr_reader :agents, :objective
    
    def initialize(objective:, agents: [])
      @objective = objective
      @agents = agents
      @messages = []
    end
    
    def run
      # Initial planning
      plan = create_execution_plan
      
      # Execute plan
      results = execute_plan(plan)
      
      # Synthesize results
      synthesize_results(results)
    end
    
    private
    
    def create_execution_plan
      planner = agents.find { |a| a.capabilities.include?('planning') }
      
      planner.add_message_and_run!(
        content: "Create a plan to achieve: #{objective}",
        role: "user"
      )
    end
    
    def execute_plan(plan)
      results = {}
      
      plan.steps.each do |step|
        agent = select_agent_for_step(step)
        result = execute_step(agent, step)
        results[step.id] = result
        
        # Check if we need to adjust plan
        if result.requires_adjustment?
          plan = adjust_plan(plan, step, result)
        end
      end
      
      results
    end
    
    def select_agent_for_step(step)
      agents.find do |agent|
        (agent.capabilities & step.required_capabilities).any?
      end
    end
    
    def execute_step(agent, step)
      agent.add_message_and_run!(
        content: step.instruction,
        role: "user",
        context: {
          step_id: step.id,
          previous_results: get_relevant_context(step)
        }
      )
    end
    
    def synthesize_results(results)
      synthesizer = agents.find { |a| a.capabilities.include?('synthesis') }
      
      synthesizer.add_message_and_run!(
        content: "Synthesize these results into a final answer for: #{objective}",
        role: "user",
        context: results
      )
    end
  end
end
```

#### Task 4.4: Agent UI Components
**File**: `app/components/agent/chat_interface_component.rb`

```ruby
module Agent
  class ChatInterfaceComponent < BaseComponent
    def initialize(assistant:, thread: nil, user:)
      @assistant = assistant
      @thread = thread || create_new_thread(user)
      @user = user
    end
    
    private
    
    attr_reader :assistant, :thread, :user
    
    def create_new_thread(user)
      assistant.assistant_threads.create!(user: user)
    end
    
    def available_tools
      @available_tools ||= assistant.tools.map do |tool_name|
        {
          name: tool_name,
          description: tool_description(tool_name),
          icon: tool_icon(tool_name)
        }
      end
    end
    
    def tool_description(tool_name)
      # Load from tool class or configuration
      tool_class = "Tools::#{tool_name.camelize}Tool".constantize
      tool_class::DESCRIPTION
    rescue
      tool_name.humanize
    end
    
    def tool_icon(tool_name)
      case tool_name
      when 'calculator'
        'calculator'
      when 'todoist'
        'check-square'
      when 'database_query'
        'database'
      else
        'tool'
      end
    end
  end
end
```

**Template**: `app/components/agent/chat_interface_component.html.erb`

```erb
<div class="agent-chat-interface" 
     data-controller="agent-chat"
     data-agent-chat-assistant-id-value="<%= assistant.id %>"
     data-agent-chat-thread-id-value="<%= thread.id %>">
  
  <!-- Header -->
  <div class="chat-header p-4 border-b bg-base-100">
    <div class="flex items-center justify-between">
      <div>
        <h3 class="text-lg font-semibold"><%= assistant.name %></h3>
        <p class="text-sm text-base-content/70"><%= assistant.description %></p>
      </div>
      <div class="dropdown dropdown-end">
        <label tabindex="0" class="btn btn-ghost btn-sm">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4"></path>
          </svg>
        </label>
        <ul tabindex="0" class="dropdown-content menu p-2 shadow bg-base-100 rounded-box w-52">
          <li><a data-action="click->agent-chat#clearHistory">Clear History</a></li>
          <li><a data-action="click->agent-chat#exportChat">Export Chat</a></li>
          <li class="menu-title">
            <span>Available Tools</span>
          </li>
          <% available_tools.each do |tool| %>
            <li>
              <a class="pointer-events-none">
                <i class="fas fa-<%= tool[:icon] %>"></i>
                <%= tool[:name].humanize %>
              </a>
            </li>
          <% end %>
        </ul>
      </div>
    </div>
  </div>
  
  <!-- Messages -->
  <div class="flex-1 overflow-y-auto p-4 space-y-4" 
       data-agent-chat-target="messages"
       style="max-height: 600px;">
    <% thread.messages.each do |message| %>
      <%= render Agent::MessageComponent.new(message: message, current_user: user) %>
    <% end %>
    
    <!-- Typing Indicator -->
    <div class="hidden" data-agent-chat-target="typingIndicator">
      <div class="chat chat-start">
        <div class="chat-bubble">
          <span class="loading loading-dots loading-sm"></span>
        </div>
      </div>
    </div>
  </div>
  
  <!-- Input -->
  <div class="border-t p-4">
    <form data-action="submit->agent-chat#sendMessage" class="flex gap-2">
      <input type="text" 
             placeholder="Ask <%= assistant.name %>..."
             class="input input-bordered flex-1"
             data-agent-chat-target="input"
             autocomplete="off">
      <button type="submit" class="btn btn-primary">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"></path>
        </svg>
      </button>
    </form>
    
    <!-- Quick Actions -->
    <div class="flex gap-2 mt-2">
      <% assistant.quick_actions.each do |action| %>
        <button class="btn btn-xs" 
                data-action="click->agent-chat#quickAction"
                data-action-text="<%= action %>">
          <%= action %>
        </button>
      <% end %>
    </div>
  </div>
</div>
```

#### Task 4.5: Agent Monitoring Dashboard
**File**: `app/controllers/agent_dashboard_controller.rb`

```ruby
class AgentDashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_agent_access
  
  def index
    @assistants = current_user.assistants.includes(:assistant_threads)
    @metrics = gather_metrics
    @recent_activity = recent_activity
  end
  
  def show
    @assistant = current_user.assistants.find(params[:id])
    @threads = @assistant.assistant_threads.recent.includes(:messages)
    @tool_usage = @assistant.tool_usage_stats
    @performance_metrics = @assistant.performance_metrics
  end
  
  private
  
  def authorize_agent_access
    authorize :agent_dashboard, :index?
  end
  
  def gather_metrics
    {
      total_assistants: @assistants.count,
      active_threads: AssistantThread.active.where(assistant: @assistants).count,
      messages_today: AssistantMessage.where(
        assistant_thread: AssistantThread.where(assistant: @assistants),
        created_at: Date.current.all_day
      ).count,
      tool_calls_today: ToolUsageLog.where(
        created_at: Date.current.all_day,
        user: current_user
      ).count
    }
  end
  
  def recent_activity
    AssistantMessage
      .joins(:assistant_thread)
      .where(assistant_threads: { assistant: @assistants })
      .recent
      .limit(10)
      .includes(:assistant_thread)
  end
end
```

### Testing Strategy

#### Task T.1: Assistant Model Tests
**File**: `spec/models/assistant_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe Assistant, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:instructions) }
    it { should validate_inclusion_of(:llm_provider).in_array(%w[custom openai anthropic]) }
  end
  
  describe 'associations' do
    it { should have_many(:assistant_threads) }
    it { should have_many(:assistant_messages).through(:assistant_threads) }
    it { should belong_to(:owner).optional }
  end
  
  describe '#build_langchain_assistant' do
    let(:assistant) { create(:assistant, :with_tools) }
    
    it 'returns configured Langchain::Assistant instance' do
      langchain_assistant = assistant.build_langchain_assistant
      
      expect(langchain_assistant).to be_a(Langchain::Assistant)
      expect(langchain_assistant.instructions).to eq(assistant.instructions)
    end
    
    it 'includes configured tools' do
      langchain_assistant = assistant.build_langchain_assistant
      tool_names = langchain_assistant.tools.map(&:name)
      
      expect(tool_names).to include('calculator', 'database_query')
    end
  end
end
```

#### Task T.2: Tool Integration Tests
**File**: `spec/tools/calculator_tool_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe Tools::CalculatorTool do
  let(:user) { create(:user) }
  let(:tool) { described_class.new(user: user) }
  
  describe '#execute' do
    it 'performs basic arithmetic' do
      result = tool.execute(input: { "expression" => "2 + 2" })
      
      expect(result[:result]).to eq(4)
      expect(result[:formatted]).to eq("4")
    end
    
    it 'handles complex expressions' do
      result = tool.execute(input: { "expression" => "(10 + 5) * 2" })
      
      expect(result[:result]).to eq(30)
    end
    
    it 'sanitizes dangerous input' do
      result = tool.execute(input: { "expression" => "2 + 2; system('rm -rf /')" })
      
      expect(result[:result]).to eq(4)
    end
    
    it 'returns error for invalid expressions' do
      result = tool.execute(input: { "expression" => "invalid" })
      
      expect(result[:error]).to include("Invalid expression")
    end
  end
end
```

#### Task T.3: Channel Integration Tests
**File**: `spec/channels/assistant_chat_channel_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe AssistantChatChannel, type: :channel do
  let(:user) { create(:user) }
  let(:chat_thread) { create(:chat_thread, users: [user]) }
  let(:assistant) { create(:assistant) }
  
  before do
    stub_connection(current_user: user)
  end
  
  describe '#subscribed' do
    it 'subscribes to assistant chat stream' do
      subscribe(thread_id: chat_thread.id)
      
      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from("assistant_chat_#{chat_thread.id}")
    end
    
    it 'creates assistant thread if needed' do
      expect {
        subscribe(thread_id: chat_thread.id)
      }.to change { AssistantThread.count }.by(1)
    end
  end
  
  describe '#send_message' do
    before { subscribe(thread_id: chat_thread.id) }
    
    it 'creates user message' do
      expect {
        perform(:send_message, message: "Hello AI")
      }.to change { chat_thread.messages.count }.by(1)
    end
    
    it 'enqueues assistant processing job' do
      expect {
        perform(:send_message, message: "Hello AI")
      }.to have_enqueued_job(AssistantProcessorJob)
    end
    
    it 'broadcasts typing indicator' do
      expect {
        perform(:send_message, message: "Hello AI")
      }.to have_broadcasted_to("assistant_chat_#{chat_thread.id}_status")
        .with(hash_including(type: 'typing', typing: true))
    end
  end
end
```

### Deployment Considerations

#### Task D.1: Environment Configuration
**File**: `.env.example`

```bash
# AI Assistant Configuration
LANGCHAIN_TRACING_V2=true
LANGCHAIN_API_KEY=your_langsmith_api_key
LANGCHAIN_PROJECT=your_project_name

# Tool API Keys
TAVILY_API_KEY=your_tavily_key
NEWS_API_KEY=your_news_api_key
SERP_API_KEY=your_serp_api_key

# External Service OAuth
TODOIST_CLIENT_ID=your_todoist_client_id
TODOIST_CLIENT_SECRET=your_todoist_client_secret
GITHUB_CLIENT_ID=your_github_client_id
GITHUB_CLIENT_SECRET=your_github_client_secret

# Vector Database (if using)
PINECONE_API_KEY=your_pinecone_key
PINECONE_ENVIRONMENT=your_pinecone_env
```

#### Task D.2: Background Job Configuration
**File**: `config/sidekiq.yml`

```yaml
:queues:
  - critical
  - default
  - ai_assistant
  - external_sync
  - low

:schedule:
  task_monitor:
    every: "30m"
    class: "TaskMonitorScheduler"
    description: "Monitor external tasks for AI preparation"
  
  assistant_cleanup:
    every: "1h"
    class: "AssistantCleanupJob"
    description: "Clean up inactive assistant threads"
```

#### Task D.3: Performance Monitoring
**File**: `config/initializers/assistant_instrumentation.rb`

```ruby
# Monitor AI assistant performance
ActiveSupport::Notifications.subscribe("assistant.process") do |name, start, finish, id, payload|
  duration = finish - start
  
  Rails.logger.info "[Assistant] Processed in #{duration}s"
  
  # Track metrics
  AssistantMetric.create!(
    assistant_id: payload[:assistant_id],
    duration: duration,
    token_usage: payload[:token_usage],
    tool_calls: payload[:tool_calls],
    success: payload[:success]
  )
end

# Monitor tool usage
ActiveSupport::Notifications.subscribe("tool.execute") do |name, start, finish, id, payload|
  duration = finish - start
  
  ToolMetric.create!(
    tool_name: payload[:tool_name],
    user_id: payload[:user_id],
    duration: duration,
    success: payload[:success],
    error: payload[:error]
  )
end
```

## Success Criteria

1. **Basic Chat Bot Working**
   - Users can chat with AI assistant
   - Assistant can use tools (calculator, weather, database)
   - Responses stream in real-time
   - Chat history is preserved

2. **External Integration Functional**
   - OAuth flow works for Todoist
   - Tasks are monitored and prepared
   - Notifications reach users

3. **Performance Acceptable**
   - Response time < 3 seconds for simple queries
   - Tool execution < 1 second
   - Background jobs process within 5 minutes

4. **Security Maintained**
   - All tools respect user permissions
   - External credentials are encrypted
   - Rate limiting prevents abuse

5. **User Experience Polished**
   - Clear typing indicators
   - Error messages are helpful
   - Tool usage is transparent

## Conclusion

This implementation plan provides a comprehensive path to adding AI agent capabilities to the Rails application. By leveraging LangChainRB and the existing infrastructure, we can build powerful, flexible agents that enhance user productivity while maintaining security and performance.

The phased approach allows for iterative development and testing, ensuring each component is solid before moving to the next. The detailed task list provides clear implementation steps that can be followed systematically.