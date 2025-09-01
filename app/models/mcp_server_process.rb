# frozen_string_literal: true

# Represents an active MCP server process
# Tracks process state, capabilities, and IO handles
class McpServerProcess
  attr_accessor :id, :user_id, :configuration_id, :configuration, :process_id, :status, :last_activity,
                :stdin, :stdout, :stderr, :wait_thread, :capabilities, :tools, :restart_count, :start_time

  STATUSES = %w[starting ready error stopping stopped].freeze

  # Validate status transitions
  VALID_STATUS_TRANSITIONS = {
    'starting' => %w[ready error stopping stopped],
    'ready' => %w[error stopping stopped],
    'error' => %w[starting stopping stopped],
    'stopping' => %w[stopped],
    'stopped' => %w[starting]
  }.freeze

  def initialize(configuration)
    @id = SecureRandom.uuid
    @configuration = configuration
    @configuration_id = configuration.id
    @user_id = configuration.owner_type == 'User' ? configuration.owner_id : nil
    @status = 'starting'
    @last_activity = Time.current
    @start_time = Time.current
    @restart_count = 0
    @capabilities = {}
    @tools = []
  end

  # Check if the process is in a running state
  def running?
    %w[starting ready].include?(@status)
  end

  # Check if the process is ready to accept commands
  def ready?
    @status == 'ready'
  end

  # Check if the process is in an error state
  def error?
    @status == 'error'
  end

  # Check if the process has been stopped
  def stopped?
    %w[stopping stopped].include?(@status)
  end

  # Update the process status with validation
  def update_status(new_status)
    raise ArgumentError, "Invalid status: #{new_status}" unless STATUSES.include?(new_status)
    
    current_status = @status
    valid_transitions = VALID_STATUS_TRANSITIONS[current_status] || []
    
    unless valid_transitions.include?(new_status)
      raise ArgumentError, "Invalid status transition from #{current_status} to #{new_status}"
    end
    
    @status = new_status
    @last_activity = Time.current
    
    Rails.logger.info "[MCP Process #{@id}] Status changed from #{current_status} to #{new_status}"
  end

  # Increment restart count
  def increment_restart_count
    @restart_count += 1
  end

  # Check if process has exceeded restart limit
  def exceeded_restart_limit?
    max_restarts = @configuration.server_config['max_restarts'] || 3
    @restart_count >= max_restarts
  end

  # Get process age in seconds
  def age_in_seconds
    Time.current - @last_activity
  end
  
  # Get process uptime in seconds
  def uptime_in_seconds
    Time.current - @start_time
  end

  # Check if process is stale (no activity for a long time)
  def stale?(threshold_seconds = 300)
    age_in_seconds > threshold_seconds
  end

  # Close all IO streams
  def close_io_streams
    [@stdin, @stdout, @stderr].each do |stream|
      begin
        stream&.close unless stream&.closed?
      rescue IOError => e
        Rails.logger.warn "[MCP Process #{@id}] Error closing stream: #{e.message}"
      end
    end
  end

  # Get process information as a hash
  def to_h
    {
      id: @id,
      user_id: @user_id,
      configuration_id: @configuration_id,
      process_id: @process_id,
      status: @status,
      last_activity: @last_activity,
      start_time: @start_time,
      restart_count: @restart_count,
      capabilities: @capabilities,
      tools_count: @tools&.size || 0,
      age_seconds: age_in_seconds.to_i,
      uptime_seconds: uptime_in_seconds.to_i
    }
  end

  # Check if the underlying system process is still alive
  def process_alive?
    return false unless @process_id
    
    begin
      Process.getpgid(@process_id)
      true
    rescue Errno::ESRCH
      false
    end
  end

  # Wait for the process to exit with optional timeout
  def wait_for_exit(timeout = nil)
    return unless @wait_thread&.alive?
    
    if timeout
      @wait_thread.join(timeout)
    else
      @wait_thread.join
    end
  end

  # Get exit status if process has exited
  def exit_status
    @wait_thread&.value&.exitstatus if @wait_thread && !@wait_thread.alive?
  end
end