# frozen_string_literal: true

require 'langchain'

class Assistant < ApplicationRecord
  # Associations
  belongs_to :user, optional: true
  has_many :assistant_messages, dependent: :destroy
  has_many :agent_runs, dependent: :destroy
  has_many :knowledge_documents, dependent: :destroy
  has_many :workflow_tasks, dependent: :nullify
  
  # Validations
  validates :name, presence: true
  validates :tool_choice, inclusion: { in: %w[auto none required] }
  
  # MCP Configuration Support
  def available_mcp_configurations
    configs = []
    
    # Get user's configurations
    if user
      configs += user.mcp_configurations.active
    end
    
    
    configs.uniq(&:id)
  end
  
  # Scopes
  scope :active, -> { where(active: true) }
  
  
  public
  
  # Use Langchain's built-in LLM classes directly for now
  def llm
    @llm ||= begin
      model = llm_model_name.presence || ENV['OPENAI_MODEL'] || 'gpt-4o-mini'
      
      # Check model provider first, then fall back to detection
      provider = self.model_provider.presence
      
      # Auto-detect provider from model name if not explicitly set
      if provider.blank?
        provider = if model.downcase.include?('gemini')
          'google'
        elsif model.downcase.include?('claude')
          'anthropic'
        elsif ENV['LLM_PROVIDER'] == 'openrouter' || ENV['OPENROUTER_API_KEY'].present?
          'openrouter'
        else
          'openai'
        end
      end
      
      # Use the appropriate LLM based on provider
      case provider
      when 'openrouter'
        # Use OpenRouter for all models
        api_key = ENV['OPENROUTER_API_KEY']
        raise "OpenRouter API key not configured" unless api_key
        
        # Format model name for OpenRouter if needed
        openrouter_model = case model.downcase
        when /gemini/
          model.start_with?('google/') ? model : "google/#{model}"
        when /claude/
          model.start_with?('anthropic/') ? model : "anthropic/#{model}"
        else
          model
        end
        
        Langchain::LLM::OpenAI.new(
          api_key: api_key,
          llm_options: {
            uri_base: 'https://openrouter.ai/api/v1'
          },
          default_options: {
            model: openrouter_model,
            temperature: 0.7
          }
        )
      when 'google'
        # Use Google Gemini directly
        api_key = ENV['GEMINI_API_KEY'] || ENV['GOOGLE_GEMINI_API_KEY']
        raise "Gemini API key not configured" unless api_key
        
        Langchain::LLM::GoogleGemini.new(
          api_key: api_key,
          default_options: {
            model: model,
            temperature: 0.7
          }
        )
      when 'anthropic'
        # Use Anthropic Claude directly
        api_key = ENV['CLAUDE_API_KEY'] || ENV['ANTHROPIC_API_KEY']
        raise "Claude API key not configured" unless api_key
        
        Langchain::LLM::Anthropic.new(
          api_key: api_key,
          default_options: {
            model: model,
            temperature: 0.7
          }
        )
      when 'openai'
        # Use OpenAI directly
        api_key = ENV['OPENAI_API_KEY']
        raise "OpenAI API key not configured" unless api_key
        
        Langchain::LLM::OpenAI.new(
          api_key: api_key,
          default_options: {
            model: model,
            temperature: 0.7
          }
        )
      else
        # Fallback to OpenAI for any unrecognized provider
        api_key = ENV['OPENAI_API_KEY']
        raise "No API keys configured for provider: #{provider}" unless api_key
        
        Langchain::LLM::OpenAI.new(
          api_key: api_key,
          default_options: {
            model: model,
            temperature: 0.7
          }
        )
      end
    end
  end
  
  # Create a LangChain assistant instance
  def langchain_assistant
    # Don't memoize if we have a current user context that differs from the assistant's user
    if @current_user && @current_user != self.user
      # Cache tools for this user context to ensure consistent tool instances
      @current_user_tools = configured_tools
      Langchain::Assistant.new(
        llm: llm,
        instructions: instructions,
        tools: @current_user_tools,
        tool_choice: tool_choice
      )
    else
      @langchain_assistant ||= Langchain::Assistant.new(
        llm: llm,
        instructions: instructions,
        tools: configured_tools,
        tool_choice: tool_choice
      )
    end
  end
  
  # Run the assistant with a new message
  def run(content:, user: nil, run_id: nil)
    run_id ||= SecureRandom.uuid
    
    # Store the current user for tool context
    @current_user = user || self.user
    
    # Create or find the run
    agent_run = agent_runs.find_or_create_by!(run_id: run_id) do |r|
      r.user = user
    end
    
    begin
      agent_run.start!
      
      # Add user message
      message = assistant_messages.create!(
        role: 'user',
        content: content,
        run_id: run_id,
        metadata: { user_id: user&.id }
      )
      
      # Get assistant response
      messages = langchain_assistant.add_message_and_run(content: content)
      
      # The last message should be the final assistant response after tool execution
      # But if it has tool calls, we need to execute them
      last_message = messages.last
      
      # Track all tools used during execution
      all_tools_used = []
      
      # Check if we need to execute tools
      while last_message.tool_calls.present? && last_message.tool_calls.any?
        # Execute each tool call
        tool_results = []
        
        last_message.tool_calls.each do |tool_call|
          tool_name = tool_call.dig('function', 'name')
          tool_args = JSON.parse(tool_call.dig('function', 'arguments') || '{}')
          tool_id = tool_call['id']
          
          # Track this tool as used
          all_tools_used << tool_name
          
          # Find and execute the tool - use cached tools if available to maintain user context
          tools_to_search = @current_user_tools || configured_tools
          tool = tools_to_search.find do |t|
            # First try the tool's actual name (for MCP tools with custom names)
            if t.respond_to?(:name) && t.name == tool_name
              true
            # Try class-based naming for tools (including unique MCP tool classes)
            elsif t.class.name.underscore.gsub('/', '_') + "__execute" == tool_name
              true
            else
              false
            end
          end
          
          if tool
            result = tool.execute(**tool_args.symbolize_keys)
            tool_results << {
              tool_call_id: tool_id,
              output: result.to_json
            }
          else
            tool_results << {
              tool_call_id: tool_id,
              output: { error: "Tool not found: #{tool_name}" }.to_json
            }
          end
        end
        
        # Submit tool outputs back to the assistant
        tool_results.each do |tool_result|
          langchain_assistant.submit_tool_output(
            tool_call_id: tool_result[:tool_call_id],
            output: tool_result[:output]
          )
        end
        
        # Run again to get the final response
        messages = langchain_assistant.run
        last_message = messages.last
      end
      
      response_content = last_message.content || ""
      tool_calls = last_message.tool_calls || []
      
      # Save assistant message
      assistant_messages.create!(
        role: 'assistant',
        content: response_content,
        tool_calls: tool_calls,
        run_id: run_id
      )
      
      # Track all tools that were actually used during execution
      agent_run.complete!(tools: all_tools_used.uniq)
      
      last_message
    rescue => e
      agent_run.fail!(e.message) if agent_run
      raise
    end
  end
  
  # Get conversation history for a run
  def conversation_for_run(run_id)
    assistant_messages.where(run_id: run_id).order(:created_at)
  end
  
  # Clear conversation history
  def clear_history!
    langchain_assistant.clear_messages! if @langchain_assistant
    assistant_messages.destroy_all
  end
  
  # Execute a workflow task
  def execute_workflow_task(task)
    return false unless task.assistant_id == id
    
    Rails.logger.info "Assistant #{name} executing workflow task #{task.id}"
    
    begin
      # Run the task instructions with the workflow execution user
      Rails.logger.info "[ASSISTANT] About to run task with instructions: #{task.instructions || task.title}"
      Rails.logger.info "[ASSISTANT] Task user: #{task.workflow_execution.user&.email}"
      
      start_time = Time.current
      result = run(
        content: task.instructions || "Execute task: #{task.title}",
        run_id: "workflow-task-#{task.id}",
        user: task.workflow_execution.user
      )
      elapsed = Time.current - start_time
      Rails.logger.info "[ASSISTANT] Run method completed in #{elapsed.round(2)} seconds"
      
      Rails.logger.info "[ASSISTANT] Run method returned result class: #{result.class.name}"
      Rails.logger.info "[ASSISTANT] Result inspect: #{result.inspect[0..500]}"
      
      # Extract the response content
      response_content = result.content || ""
      Rails.logger.info "[ASSISTANT] Extracted response content of #{response_content.length} characters"
      Rails.logger.info "[ASSISTANT] Response preview: #{response_content[0..200]}"
      
      # Ensure task is reloaded before marking complete
      task.reload
      
      # Only try to mark complete if still running
      if task.running?
        # Mark task as complete with the result
        success = task.mark_complete(
          output: response_content,
          metadata: {
            tool_calls: result.tool_calls,
            run_id: "workflow-task-#{task.id}"
          }
        )
        
        if success
          Rails.logger.info "Task #{task.id} marked as complete successfully"
          return true
        else
          Rails.logger.error "Failed to mark task #{task.id} as complete"
          # Try one more time with a simpler approach
          task.reload
          if task.running?
            if task.update(status: 'completed', completed_at: Time.current, result_data: { output: response_content })
              Rails.logger.info "Task #{task.id} marked as complete on second attempt"
              task.broadcast_status_update
              task.trigger_next_tasks
              return true
            end
          end
          return false
        end
      else
        Rails.logger.warn "Task #{task.id} is no longer in running state (status: #{task.status})"
        return task.completed?
      end
    rescue => e
      Rails.logger.error "Error in execute_workflow_task: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      task.reload
      task.mark_failed(e.message) if task.running?
      false
    end
  end
  
  def available_mcp_servers
    current_user = @current_user || self.user
    
    servers = []
    
    # Add system-wide servers
    servers.concat(McpServer.system_wide.active)
    
    # Add user-specific servers (which includes system-wide and user's own servers)
    if current_user
      servers.concat(McpServer.available_to_user(current_user).active)
    end
    
    servers.uniq
  end

  def refresh_mcp_tools
    # Clear any cached tools and reload
    @mcp_tools = nil
    @langchain_assistant = nil
    
    # Trigger discovery for all accessible servers
    available_mcp_servers.each(&:trigger_tool_discovery)
  end
  
  private
  
  def configured_tools
    return [] if tools.blank?
    
    all_tools = []
    
    # Load regular tools
    regular_tools = tools.map do |tool_config|
      case tool_config['type']
      when 'calculator'
        Agents::Tools::CalculatorTool.new
      when 'ruby_code_interpreter', 'ruby_code'
        Agents::Tools::RubyCodeTool.new
      when 'google_search', 'web_search'
        # Use DuckDuckGo if Google Search is not configured
        if ENV['GOOGLE_SEARCH_API_KEY'].present? && ENV['GOOGLE_SEARCH_ENGINE_ID'].present?
          Agents::Tools::WebSearchTool.new
        else
          Agents::Tools::DdgSearchTool.new
        end
      when 'chat'
        Agents::Tools::ChatTool.new(thread_id: tool_config['thread_id'])
      when 'knowledge_search', 'rag'
        Agents::Tools::RagTool.new(assistant: self)
      when 'mcp_tools'
        # MCP tools are loaded separately
        nil
      else
        # Custom tool loading
        load_custom_tool(tool_config)
      end
    end.compact
    
    all_tools.concat(regular_tools)
    
    # Load MCP tools if enabled
    if tools.any? { |t| t['type'] == 'mcp_tools' }
      mcp_tools = load_mcp_tools
      all_tools.concat(mcp_tools)
    end
    
    all_tools
  end
  
  def load_custom_tool(config)
    return nil unless config['class_name'].present?
    
    config['class_name'].constantize.new(config['options'] || {})
  rescue NameError
    Rails.logger.error "Failed to load tool: #{config['class_name']}"
    nil
  end

  def load_mcp_tools
    # Use new tool resolver for hybrid approach
    resolver = AssistantToolResolver.new(self)
    mcp_tools = []
    
    # Set assistant context for MCP tools
    Thread.current[:current_assistant] = self
    
    # Get all MCP tools through resolver
    resolved_tools = resolver.resolve_mcp_tools
    
    resolved_tools.each do |tool_info|
      next unless tool_info[:available]
      
      begin
        # Create MCP tool from the new tool info format
        if tool_info[:server_id].present?
          # Try to find MCP configuration first (new system)
          config = McpConfiguration.find_by(id: tool_info[:server_id])
          
          if config
            # Use compatibility layer to create server facade
            server_facade = McpCompatibilityLayer.configuration_to_server(config)
            
            # Create tool definition in expected format
            tool_definition = {
              'name' => tool_info[:mcp_tool_name] || tool_info[:name],
              'description' => tool_info[:description],
              'inputSchema' => tool_info[:input_schema] || {}
            }
            
            mcp_tool = Agents::Tools::McpTool.create_from_mcp_tool(
              server_facade,
              tool_definition,
              user: @current_user || self.user
            )
            
            mcp_tools << mcp_tool
          else
            # Fall back to legacy MCP server
            mcp_server = McpServer.find_by(id: tool_info[:server_id])
            
            if mcp_server&.active?
              tool_definition = {
                'name' => tool_info[:mcp_tool_name] || tool_info[:name],
                'description' => tool_info[:description],
                'inputSchema' => tool_info[:input_schema] || {}
              }
              
              mcp_tool = Agents::Tools::McpTool.create_from_mcp_tool(
                mcp_server,
                tool_definition,
                user: @current_user || self.user
              )
              
              mcp_tools << mcp_tool
            end
          end
        end
      rescue => e
        Rails.logger.error "Failed to create MCP tool #{tool_info[:name]}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        # Continue with other tools
      end
    end
    
    Rails.logger.info "Loaded #{mcp_tools.size} MCP tools for assistant #{name}"
    mcp_tools
  ensure
    Thread.current[:current_assistant] = nil
  end

  def get_mcp_tool_configuration
    # Get MCP-specific configuration from tools array
    mcp_tool_config = tools.find { |t| t['type'] == 'mcp_tools' }
    return {} unless mcp_tool_config
    
    {
      enabled_servers: mcp_tool_config['enabled_servers'] || [],
      enabled_tools: mcp_tool_config['enabled_tools'] || [],
      disabled_tools: mcp_tool_config['disabled_tools'] || [],
      tool_filters: mcp_tool_config['tool_filters'] || {}
    }
  end

  def tool_enabled?(tool_definition, mcp_config)
    tool_name = tool_definition['name']
    server_id = tool_definition['_server_id']
    
    # Check if tool is explicitly disabled
    return false if mcp_config[:disabled_tools].include?(tool_name)
    
    # Check if server is enabled (if server filter is specified)
    if mcp_config[:enabled_servers].any?
      return false unless mcp_config[:enabled_servers].include?(server_id.to_s)
    end
    
    # Check if tool is explicitly enabled (if tool filter is specified)
    if mcp_config[:enabled_tools].any?
      return mcp_config[:enabled_tools].include?(tool_name)
    end
    
    # Apply additional filters
    apply_tool_filters(tool_definition, mcp_config[:tool_filters])
  end

  def apply_tool_filters(tool_definition, filters)
    return true if filters.empty?
    
    # Category filter
    if filters['categories']
      registry = McpToolRegistry.instance
      tool_category = registry.send(:categorize_tool, tool_definition)
      return false unless filters['categories'].include?(tool_category)
    end
    
    # Name pattern filter
    if filters['name_pattern']
      pattern = Regexp.new(filters['name_pattern'], Regexp::IGNORECASE)
      return false unless tool_definition['name'].match?(pattern)
    end
    
    # Description filter
    if filters['description_contains']
      keywords = filters['description_contains']
      description = tool_definition['description'].downcase
      return false unless keywords.any? { |keyword| description.include?(keyword.downcase) }
    end
    
    true
  end
end
