# frozen_string_literal: true

require_relative 'mcp_bridge_errors'
require 'timeout'

# Bridge manager for MCP server integration
# Handles process lifecycle and tool execution for stdio-based MCP servers
class McpBridgeManager
  include McpBridgeErrors
  def initialize
    @process_pool = McpProcessPoolService.instance
    @active_processes = {}
    @restart_attempts = {}
    @circuit_breakers = {}
    @warm_up_status = {}
  end

  # List available tools for a user's MCP configuration
  # @param user [User] The user requesting tools
  # @param configuration_id [Integer] The MCP configuration ID
  # @return [Array<Hash>] List of available tools
  def list_tools(user, configuration_id)
    configuration = find_configuration(user, configuration_id)
    process = ensure_process_running(user, configuration)
    
    tools = process.tools || []
    Rails.logger.info "[MCP Bridge] Listed #{tools.size} tools for configuration #{configuration_id} (user: #{user.id})"
    
    tools
  end

  # Execute a tool from an MCP server
  # @param user [User] The user executing the tool
  # @param configuration_id [Integer] The MCP configuration ID
  # @param tool_name [String] The name of the tool to execute
  # @param arguments [Hash] Arguments to pass to the tool
  # @return [Hash] Tool execution result
  def execute_tool(user, configuration_id, tool_name, arguments, assistant = nil)
    configuration = find_configuration(user, configuration_id)
    process = ensure_process_running(user, configuration)
    
    start_time = Time.current
    Rails.logger.info "[MCP Bridge] Executing tool '#{tool_name}' for user #{user.id}"
    
    # Add timeout for tool execution
    begin
      Timeout.timeout(45) do  # 45 second timeout for tool execution
        result = @process_pool.call_tool(process, tool_name, arguments)
        process.last_activity = Time.current
        
        execution_time = Time.current - start_time
        response_time_ms = (execution_time * 1000).round
        Rails.logger.info "[MCP Bridge] Tool '#{tool_name}' completed in #{execution_time.round(3)}s"
        
        formatted_result = format_tool_result(result)
        formatted_result[:execution_time] = execution_time.round(3)
        
        # Log audit trail
        begin
          # Get assistant from thread context if not provided
          assistant ||= Thread.current[:current_assistant]
          
          McpAuditLog.create!(
            user: user,
            mcp_configuration: configuration,
            assistant: assistant,
            tool_name: tool_name,
            request_data: arguments,
            response_data: formatted_result,
            executed_at: start_time,
            status: formatted_result[:success] ? :successful : :failed,
            response_time_ms: response_time_ms
          )
        rescue => e
          Rails.logger.error "[MCP Bridge] Failed to create audit log: #{e.message}"
        end
        
        formatted_result
      end
    rescue Timeout::Error
      execution_time = Time.current - start_time
      response_time_ms = (execution_time * 1000).round
      Rails.logger.error "[MCP Bridge] Tool '#{tool_name}' timed out after #{execution_time.round(3)}s"
      
      error_result = {
        success: false,
        error: {
          code: -32603,
          message: "Tool execution timed out after #{execution_time.round(1)}s. This may happen with tools that fetch large amounts of data. Try using search tools with filters for faster results."
        },
        execution_time: execution_time.round(3)
      }
      
      # Log timeout in audit trail
      begin
        assistant ||= Thread.current[:current_assistant]
        
        McpAuditLog.create!(
          user: user,
          mcp_configuration: configuration,
          assistant: assistant,
          tool_name: tool_name,
          request_data: arguments,
          response_data: error_result,
          executed_at: start_time,
          status: :timeout,
          response_time_ms: response_time_ms
        )
      rescue => e
        Rails.logger.error "[MCP Bridge] Failed to create timeout audit log: #{e.message}"
      end
      
      error_result
    end
  end

  # Get the status of an MCP server
  # @param user [User] The user checking status
  # @param configuration_id [Integer] The MCP configuration ID
  # @return [Hash] Server status information
  def server_status(user, configuration_id)
    configuration = find_configuration(user, configuration_id)
    process_key = process_key_for(user, configuration)
    
    process = @active_processes[process_key]
    
    if process
      {
        status: process.status,
        last_activity: process.last_activity,
        tools_count: process.tools&.size || 0
      }
    else
      {
        status: 'stopped',
        last_activity: nil,
        tools_count: 0
      }
    end
  end

  # Discover available tools for a configuration
  # @param user [User] The user context for discovery
  # @param configuration_id [Integer] The MCP configuration ID
  # @return [Array<Hash>] List of discovered tools
  def discover_tools(user, configuration_id)
    configuration = find_configuration(user, configuration_id)
    
    Rails.logger.info "[MCP Bridge] Discovering tools for configuration #{configuration_id} (user: #{user.id})"
    
    begin
      # Ensure process is running to get tools
      process = ensure_process_running(user, configuration)
      
      # Get tools from the process
      tools = process.tools || []
      
      # If no tools cached, try to refresh by listing tools from the server
      if tools.empty?
        Rails.logger.info "[MCP Bridge] No cached tools found, attempting fresh discovery"
        
        # Force a fresh tool discovery by calling list_tools
        fresh_tools = @process_pool.list_tools(process)
        
        if fresh_tools && fresh_tools.any?
          # Update process with discovered tools
          process.tools = fresh_tools
          process.save!
          tools = fresh_tools
        end
      end
      
      Rails.logger.info "[MCP Bridge] Discovered #{tools.size} tools for configuration #{configuration_id}"
      
      # Format tools for consistency
      tools.map do |tool|
        {
          'name' => tool['name'] || tool[:name],
          'description' => tool['description'] || tool[:description],
          'inputSchema' => tool['inputSchema'] || tool[:inputSchema] || {},
          'outputSchema' => tool['outputSchema'] || tool[:outputSchema] || {}
        }
      end
    rescue => e
      Rails.logger.error "[MCP Bridge] Failed to discover tools for configuration #{configuration_id}: #{e.message}"
      raise ToolDiscoveryError.new(
        "Failed to discover tools: #{e.message}",
        configuration_id: configuration_id,
        user_id: user.id
      )
    end
  end

  private

  # Find and validate MCP configuration
  # @param user [User] The user who owns the configuration
  # @param configuration_id [Integer] The configuration ID
  # @return [McpConfiguration] The configuration
  # @raise [ActiveRecord::RecordNotFound] If configuration not found
  # @raise [StandardError] If configuration is disabled
  def find_configuration(user, configuration_id)
    configuration = user.mcp_configurations.find(configuration_id)
    
    unless configuration.enabled?
      raise ConfigurationError.new(
        "MCP configuration is disabled",
        configuration_id: configuration_id,
        user_id: user.id
      )
    end
    
    configuration
  end

  # Ensure an MCP server process is running
  # @param user [User] The user who owns the process
  # @param configuration [McpConfiguration] The configuration to use
  # @return [McpServerProcess] The running process
  def ensure_process_running(user, configuration)
    # Validate configuration before spawning
    validate_configuration(configuration)
    
    process_key = process_key_for(user, configuration)
    process = @active_processes[process_key]
    
    # Check if process exists and is ready
    if process
      # Check if process crashed
      if process.error? || !process.process_alive?
        Rails.logger.warn "[MCP Bridge] Process crashed for configuration #{configuration.id}, restarting..."
        @active_processes.delete(process_key)
        process = nil
      elsif process.ready?
        return process
      end
    end
    
    # Check circuit breaker
    check_circuit_breaker(process_key)
    
    # Spawn new process if needed
    Rails.logger.info "[MCP Bridge] Spawning new process for configuration #{configuration.id}"
    
    begin
      process = spawn_with_retry(configuration, user, process_key)
      @active_processes[process_key] = process
      
      # Reset restart attempts on success
      @restart_attempts.delete(process_key)
      reset_circuit_breaker(process_key)
      
      # Warm up process on first request
      warm_up_process(process) unless @warm_up_status[process_key]
      
      process
    rescue => e
      # Record failure for circuit breaker
      record_circuit_breaker_failure(process_key)
      
      Rails.logger.error "[MCP Bridge] Failed to spawn process for configuration #{configuration.id}: #{e.message}"
      raise ProcessSpawnError.new(
        "Failed to start MCP server: #{e.message}",
        configuration_id: configuration.id,
        user_id: user.id,
        details: { error_class: e.class.name }
      )
    end
  end

  # Generate a unique key for process tracking
  # @param user [User] The user
  # @param configuration [McpConfiguration] The configuration
  # @return [String] Unique process key
  def process_key_for(user, configuration)
    user_id = user.is_a?(String) ? user : user.id
    config_id = configuration.is_a?(String) ? configuration : configuration.id
    "user_#{user_id}_config_#{config_id}"
  end

  # Format tool execution result
  # @param result [Hash] Raw result from MCP server
  # @return [Hash] Formatted result
  def format_tool_result(result)
    if result[:error]
      {
        success: false,
        error: {
          code: result[:error][:code],
          message: result[:error][:message]
        }
      }
    else
      content = result[:result][:content]
      
      # Handle different content types
      formatted_content = if content.is_a?(Array)
        content.map { |item| item[:text] || item[:content] || item }.join("\n")
      elsif content.is_a?(Hash)
        content[:text] || content[:content] || content.to_json
      else
        content.to_s
      end
      
      {
        success: true,
        content: formatted_content
      }
    end
  end
  
  # Validate MCP configuration for security and correctness
  # @param configuration [McpConfiguration] The configuration to validate
  # @raise [StandardError] If configuration is invalid
  def validate_configuration(configuration)
    server_config = configuration.server_config
    
    # Check server type
    unless configuration.server_type == 'stdio'
      raise ConfigurationError.new(
        "McpBridgeManager only supports stdio server type, got: #{configuration.server_type}",
        configuration_id: configuration.id
      )
    end
    
    # Validate command
    command = server_config['command']
    if command.blank?
      raise ConfigurationError.new(
        "Command is required for stdio MCP server",
        configuration_id: configuration.id
      )
    end
    
    # Security: Check for dangerous commands
    blocklist = %w[rm dd mkfs fdisk shutdown reboot systemctl kill pkill]
    blocklist_pattern = /\b(#{blocklist.join('|')})\b/i
    
    if command.match?(blocklist_pattern)
      raise StandardError, "Command '#{command}' is not allowed for security reasons"
    end
    
    # Security: Check for shell operators that could lead to command injection
    if command.match?(/[;&|><\$`]/)
      raise StandardError, "Command contains potentially dangerous shell operators"
    end
    
    # Validate args
    args = server_config['args']
    unless args.nil? || args.is_a?(Array)
      raise StandardError, "Args must be an array or nil, got: #{args.class}"
    end
    
    # Validate env
    env = server_config['env']
    unless env.nil? || env.is_a?(Hash)
      raise StandardError, "Env must be a hash or nil, got: #{env.class}"
    end
    
    # Check for required environment variables based on command
    if command.include?('linear') && env
      required_vars = ['LINEAR_API_KEY']
      missing_vars = required_vars.select { |var| env[var].blank? }
      
      unless missing_vars.empty?
        raise StandardError, "Missing required environment variables: #{missing_vars.join(', ')}"
      end
    end
    
    Rails.logger.info "[MCP Bridge] Configuration validated for #{configuration.name}"
  end
  
  # Spawn process with exponential backoff retry
  def spawn_with_retry(configuration, user, process_key)
    max_attempts = 3
    base_delay = 1.0 # seconds
    
    attempt = @restart_attempts[process_key] || 0
    
    if attempt > 0
      # Exponential backoff: 1s, 2s, 4s
      delay = base_delay * (2 ** (attempt - 1))
      Rails.logger.info "[MCP Bridge] Retry attempt #{attempt} after #{delay}s delay"
      sleep(delay)
    end
    
    begin
      @restart_attempts[process_key] = attempt + 1
      @process_pool.spawn_mcp_server(configuration)
    rescue => e
      if attempt < max_attempts - 1
        # Try again
        return spawn_with_retry(configuration, user, process_key)
      else
        # Max attempts reached
        raise e
      end
    end
  end
  
  # Circuit breaker implementation
  def check_circuit_breaker(process_key)
    breaker = @circuit_breakers[process_key]
    return unless breaker
    
    if breaker[:state] == :open
      # Check if cooldown period has passed
      if Time.current > breaker[:retry_after]
        Rails.logger.info "[MCP Bridge] Circuit breaker half-open for #{process_key}"
        breaker[:state] = :half_open
      else
        time_left = (breaker[:retry_after] - Time.current).round
        raise CircuitOpenError.new(
          "Circuit breaker is open. Too many failures.",
          retry_after: breaker[:retry_after],
          failure_count: breaker[:failure_count],
          details: { time_left_seconds: time_left }
        )
      end
    end
  end
  
  def record_circuit_breaker_failure(process_key)
    @circuit_breakers[process_key] ||= { state: :closed, failure_count: 0 }
    breaker = @circuit_breakers[process_key]
    
    breaker[:failure_count] += 1
    breaker[:last_failure] = Time.current
    
    # Open circuit after 5 failures
    if breaker[:failure_count] >= 5
      breaker[:state] = :open
      breaker[:retry_after] = Time.current + 60 # 1 minute cooldown
      Rails.logger.error "[MCP Bridge] Circuit breaker opened for #{process_key} after #{breaker[:failure_count]} failures"
    end
  end
  
  def reset_circuit_breaker(process_key)
    @circuit_breakers.delete(process_key)
  end
  
  # Warm up a process by pre-loading tools
  def warm_up_process(process)
    Thread.new do
      begin
        Rails.logger.info "[MCP Bridge] Warming up process #{process.id}"
        
        # Tools are already discovered during initialization
        # Just mark as warmed up
        @warm_up_status[process_key_for(process.user_id, process.configuration_id)] = true
        
        Rails.logger.info "[MCP Bridge] Process #{process.id} warmed up with #{process.tools&.size || 0} tools"
      rescue => e
        Rails.logger.error "[MCP Bridge] Warm-up failed for process #{process.id}: #{e.message}"
      end
    end
  end

  
end