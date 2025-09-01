# frozen_string_literal: true

require 'singleton'
require 'open3'
require 'timeout'
require 'json'

# Use Oj for faster JSON parsing if available
begin
  require 'oj'
  JSON_PARSER = Oj
rescue LoadError
  JSON_PARSER = JSON
end

# Service for managing MCP server process lifecycle
# Handles spawning, communication, and cleanup of MCP server processes
class McpProcessPoolService
  include Singleton

  def initialize
    @processes = {}
    @process_pool = {}
    @mutex = Mutex.new
    @tool_cache = {}
    @cache_mutex = Mutex.new
    
    Rails.logger.info "[MCP Bridge] McpProcessPoolService initialized"
    
    # Register shutdown hook
    at_exit { shutdown_all_processes }
  end

  def spawn_mcp_server(configuration)
    @mutex.synchronize do
      command = configuration.server_config['command']
      args = configuration.server_config['args'] || []
      env = configuration.server_config['env'] || {}
      
      # Spawn process using Open3
      stdin, stdout, stderr, wait_thr = Open3.popen3(env, command, *args)
      
      mcp_process = McpServerProcess.new(configuration)
      mcp_process.process_id = wait_thr.pid
      mcp_process.stdin = stdin
      mcp_process.stdout = stdout
      mcp_process.stderr = stderr
      mcp_process.wait_thread = wait_thr
      
      # Register process
      @processes[mcp_process.id] = mcp_process
      @process_pool[mcp_process.id] = {
        stdin: stdin,
        stdout: stdout,
        stderr: stderr,
        wait_thread: wait_thr
      }
      
      # Start stderr reader thread to capture debug output
      Thread.new do
        begin
          while (line = stderr.gets)
            Rails.logger.debug "[MCP Process #{mcp_process.id} stderr] #{line.chomp}"
          end
        rescue => e
          Rails.logger.error "[MCP Process #{mcp_process.id}] stderr reader error: #{e.message}"
        end
      end
      
      # Initialize MCP protocol
      initialize_mcp_protocol(mcp_process)
      
      mcp_process
    end
  end

  def initialize_mcp_protocol(mcp_process)
    init_request = JsonRpcMessage.request(
      method: "initialize",
      params: {
        protocolVersion: "2024-11-05",
        capabilities: { tools: {} },
        clientInfo: {
          name: "allspark-mcp-bridge",
          version: "1.0.0"
        }
      },
      id: 1
    )

    begin
      response = send_message(mcp_process, init_request)
      
      if response[:error]
        error_msg = "MCP initialization failed: #{response[:error][:message]}"
        Rails.logger.error "[MCP Process #{mcp_process.id}] #{error_msg}"
        mcp_process.update_status('error')
        raise error_msg
      end
      
      mcp_process.capabilities = response[:result][:capabilities]
      mcp_process.update_status('ready')

      # Discover available tools
      discover_tools(mcp_process)
    rescue => e
      Rails.logger.error "[MCP Process #{mcp_process.id}] Initialization error: #{e.message}"
      mcp_process.update_status('error') if mcp_process.status != 'error'
      cleanup_process_internal(mcp_process)
      raise
    end
  end

  def discover_tools(mcp_process)
    # Check cache first
    cache_key = "tools_#{mcp_process.configuration_id}"
    cached_tools = get_cached_tools(cache_key)
    
    if cached_tools
      Rails.logger.info "[MCP Process #{mcp_process.id}] Using cached tools (#{cached_tools.size} tools)"
      mcp_process.tools = cached_tools
      return
    end
    
    tools_request = JsonRpcMessage.request(
      method: "tools/list",
      id: 2
    )

    begin
      response = send_message(mcp_process, tools_request)
      
      if response[:error]
        Rails.logger.warn "[MCP Process #{mcp_process.id}] Tool discovery error: #{response[:error][:message]}"
        mcp_process.tools = []
        return
      end
      
      tools = response[:result][:tools] || []
      # Convert symbol keys to string keys for consistency
      tools = tools.map { |tool| tool.deep_stringify_keys }
      mcp_process.tools = tools
      
      # Cache the tools for 5 minutes
      cache_tools(cache_key, tools, ttl: 300)
      
      if tools.empty?
        Rails.logger.info "[MCP Process #{mcp_process.id}] No tools available from MCP server"
      else
        Rails.logger.info "[MCP Process #{mcp_process.id}] Discovered #{tools.size} tools"
      end
    rescue => e
      Rails.logger.error "[MCP Process #{mcp_process.id}] Tool discovery failed: #{e.message}"
      mcp_process.tools = []
    end
  end

  def call_tool(mcp_process, tool_name, arguments)
    call_request = JsonRpcMessage.request(
      method: "tools/call",
      params: {
        name: tool_name,
        arguments: arguments
      },
      id: SecureRandom.uuid
    )

    begin
      response = send_message(mcp_process, call_request)
      
      if response[:error]
        Rails.logger.error "[MCP Process #{mcp_process.id}] Tool execution error for '#{tool_name}': #{response[:error][:message]}"
        return response
      end
      
      Rails.logger.info "[MCP Process #{mcp_process.id}] Tool '#{tool_name}' executed successfully"
      response
    rescue => e
      Rails.logger.error "[MCP Process #{mcp_process.id}] Tool execution failed for '#{tool_name}': #{e.message}"
      {
        jsonrpc: "2.0",
        id: call_request[:id],
        error: {
          code: -32603,
          message: "Internal error: #{e.message}"
        }
      }
    end
  end

  private

  def send_message(mcp_process, message)
    process_io = @process_pool[mcp_process.id]
    raise "Process #{mcp_process.id} not found" unless process_io

    # Send message
    process_io[:stdin].puts(JSON_PARSER.dump(message))
    
    # Wait for response with timeout
    Timeout.timeout(30) do
      # Read lines until we get valid JSON (skip debug output)
      response = nil
      max_attempts = 10
      attempts = 0
      
      while response.nil? && attempts < max_attempts
        response_line = process_io[:stdout].readline
        attempts += 1
        
        # Skip empty lines and obvious debug output
        next if response_line.strip.empty?
        next unless response_line.strip.start_with?('{')
        
        # Parse JSON with error handling
        begin
          if defined?(Oj) && JSON_PARSER == Oj
            response = Oj.load(response_line, symbol_keys: true)
          else
            response = JSON.parse(response_line, symbolize_names: true)
          end
        rescue JSON::ParserError, Oj::ParseError => parse_error
          # Log but don't fail immediately - might be debug output
          Rails.logger.warn "[MCP Process] Skipping non-JSON line: #{response_line.inspect}"
          response = nil
          next
        end
      end
      
      if response.nil?
        Rails.logger.error "[MCP Process] Failed to get valid JSON response after #{max_attempts} attempts"
        raise "No valid JSON response from MCP server after #{max_attempts} attempts"
      end
      
      # Ensure response is a hash
      unless response.is_a?(Hash)
        Rails.logger.error "[MCP Process] Invalid response type: #{response.class}, raw response: #{response_line.inspect}"
        raise "MCP server returned invalid response type: #{response.class}"
      end
      
      if response[:id] == message[:id]
        return response
      else
        raise "Message ID mismatch: expected #{message[:id]}, got #{response[:id]}"
      end
    end
  rescue Timeout::Error
    raise "MCP request timeout"
  end

  def cleanup_process(mcp_process)
    # Remove from tracking hashes
    @mutex.synchronize do
      cleanup_process_internal(mcp_process)
    end
  end
  
  def cleanup_process_internal(mcp_process)
    # Internal cleanup without mutex (for use when already synchronized)
    @processes.delete(mcp_process.id)
    process_io = @process_pool.delete(mcp_process.id)
    
    # Close IO streams
    if process_io
      mcp_process.close_io_streams
      
      # Terminate the process if still running
      if mcp_process.process_alive?
        begin
          Process.kill('TERM', mcp_process.process_id)
          mcp_process.wait_for_exit(5) # Wait up to 5 seconds
          
          # Force kill if still alive
          if mcp_process.process_alive?
            Process.kill('KILL', mcp_process.process_id)
          end
        rescue Errno::ESRCH
          # Process already dead
        end
      end
    end
    
    Rails.logger.info "[MCP Process #{mcp_process.id}] Cleaned up"
  end
  
  # Shutdown all processes gracefully
  def shutdown_all_processes
    Rails.logger.info "[MCP Bridge] Shutting down all MCP processes"
    
    @mutex.synchronize do
      @processes.each do |process_id, process|
        begin
          Rails.logger.info "[MCP Bridge] Shutting down process #{process_id}"
          
          # Update status
          process.update_status('stopping') if process.running?
          
          # Send termination signal
          if process.process_alive?
            Process.kill('TERM', process.process_id)
            
            # Wait briefly for graceful shutdown
            process.wait_for_exit(3)
            
            # Force kill if needed
            if process.process_alive?
              Process.kill('KILL', process.process_id)
            end
          end
          
          # Close IO streams
          process.close_io_streams
        rescue => e
          Rails.logger.error "[MCP Bridge] Error shutting down process #{process_id}: #{e.message}"
        end
      end
      
      # Clear all tracking
      @processes.clear
      @process_pool.clear
    end
    
    Rails.logger.info "[MCP Bridge] All MCP processes shut down"
  end
  
  public :shutdown_all_processes
  
  # Cache management methods
  def get_cached_tools(cache_key)
    @cache_mutex.synchronize do
      entry = @tool_cache[cache_key]
      return nil unless entry
      
      # Check if cache is still valid
      if Time.current < entry[:expires_at]
        entry[:tools]
      else
        @tool_cache.delete(cache_key)
        nil
      end
    end
  end
  
  def cache_tools(cache_key, tools, ttl:)
    @cache_mutex.synchronize do
      @tool_cache[cache_key] = {
        tools: tools,
        expires_at: Time.current + ttl,
        cached_at: Time.current
      }
    end
  end
  
  def clear_tool_cache(configuration_id = nil)
    @cache_mutex.synchronize do
      if configuration_id
        @tool_cache.delete("tools_#{configuration_id}")
      else
        @tool_cache.clear
      end
    end
  end
  
  # Performance metrics
  public
  def collect_metrics
    {
      active_processes: @processes.size,
      cached_tools: @tool_cache.size,
      memory_usage: process_memory_usage
    }
  end
  
  def process_memory_usage
    # Get memory usage for current process
    pid = Process.pid
    rss = `ps -o rss= -p #{pid}`.to_i * 1024 # Convert KB to bytes
    rss
  rescue
    0
  end
end