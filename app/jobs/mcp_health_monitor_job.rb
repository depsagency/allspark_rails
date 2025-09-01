# frozen_string_literal: true

# Background job for monitoring MCP server process health
# Runs periodically to check process status and restart failed processes
class McpHealthMonitorJob < ApplicationJob
  queue_as :default

  # Perform health check on all active MCP processes
  def perform
    Rails.logger.info "[MCP Health Monitor] Starting health check"
    
    process_pool = McpProcessPoolService.instance
    checked_count = 0
    unhealthy_count = 0
    
    # Get all active processes from the pool
    processes = get_all_processes(process_pool)
    
    processes.each do |process_id, process|
      checked_count += 1
      
      unless check_process_health(process, process_pool)
        unhealthy_count += 1
        handle_unhealthy_process(process, process_pool)
      end
    end
    
    Rails.logger.info "[MCP Health Monitor] Checked #{checked_count} processes, #{unhealthy_count} unhealthy"
    
    # Clean up any zombie processes
    cleanup_zombie_processes
    
    # Schedule next health check
    schedule_next_check
  rescue => e
    Rails.logger.error "[MCP Health Monitor] Error during health check: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Still schedule next check even if this one failed
    schedule_next_check
  end

  private

  # Get all processes from the pool
  def get_all_processes(process_pool)
    # Access the internal processes hash
    # This is a bit of a hack but necessary for monitoring
    process_pool.instance_variable_get(:@processes) || {}
  end

  # Check if a process is healthy
  # @param process [McpServerProcess] The process to check
  # @param process_pool [McpProcessPoolService] The process pool
  # @return [Boolean] true if healthy, false otherwise
  def check_process_health(process, process_pool)
    # Check if the OS process is still alive
    unless process.process_alive?
      Rails.logger.warn "[MCP Health Monitor] Process #{process.id} is not alive"
      return false
    end
    
    # Check if process is in error state
    if process.error?
      Rails.logger.warn "[MCP Health Monitor] Process #{process.id} is in error state"
      return false
    end
    
    # Check if process is stale (no activity for 5 minutes)
    if process.stale?(300)
      # Try to ping the process
      if process.ready?
        begin
          ping_request = JsonRpcMessage.request(
            method: "ping",
            id: "health-check-#{SecureRandom.hex(4)}"
          )
          
          response = process_pool.send(:send_message, process, ping_request)
          
          if response[:error]
            Rails.logger.warn "[MCP Health Monitor] Process #{process.id} ping failed: #{response[:error][:message]}"
            return false
          end
          
          # Update last activity on successful ping
          process.last_activity = Time.current
          Rails.logger.debug "[MCP Health Monitor] Process #{process.id} pinged successfully"
        rescue => e
          Rails.logger.warn "[MCP Health Monitor] Process #{process.id} ping error: #{e.message}"
          return false
        end
      end
    end
    
    true
  end

  # Handle an unhealthy process
  # @param process [McpServerProcess] The unhealthy process
  # @param process_pool [McpProcessPoolService] The process pool
  def handle_unhealthy_process(process, process_pool)
    Rails.logger.info "[MCP Health Monitor] Handling unhealthy process #{process.id}"
    
    # Update status to error if not already
    process.update_status('error') unless process.error?
    
    # Try to terminate the process gracefully
    if process.process_alive?
      begin
        Rails.logger.info "[MCP Health Monitor] Sending SIGTERM to process #{process.process_id}"
        Process.kill('TERM', process.process_id)
        
        # Wait up to 5 seconds for graceful shutdown
        process.wait_for_exit(5)
        
        # Force kill if still alive
        if process.process_alive?
          Rails.logger.warn "[MCP Health Monitor] Process didn't terminate, sending SIGKILL"
          Process.kill('KILL', process.process_id)
        end
      rescue Errno::ESRCH
        Rails.logger.info "[MCP Health Monitor] Process already dead"
      rescue => e
        Rails.logger.error "[MCP Health Monitor] Error terminating process: #{e.message}"
      end
    end
    
    # Close IO streams
    process.close_io_streams
    
    # Remove from process pool
    remove_from_pool(process, process_pool)
  end

  # Remove a process from the pool
  def remove_from_pool(process, process_pool)
    processes = process_pool.instance_variable_get(:@processes)
    process_pool_io = process_pool.instance_variable_get(:@process_pool)
    mutex = process_pool.instance_variable_get(:@mutex)
    
    mutex.synchronize do
      processes.delete(process.id)
      process_pool_io.delete(process.id)
    end
    
    Rails.logger.info "[MCP Health Monitor] Removed process #{process.id} from pool"
  end

  # Schedule the next health check
  def schedule_next_check
    # Schedule next check in 30 seconds
    self.class.set(wait: 30.seconds).perform_later
  end
  
  # Clean up zombie processes
  def cleanup_zombie_processes
    begin
      # Find all child processes that might be zombies
      zombie_pids = []
      
      # Use ps to find zombie processes
      output = `ps aux | grep defunct | grep -v grep`
      output.each_line do |line|
        parts = line.split
        pid = parts[1].to_i
        zombie_pids << pid if pid > 0
      end
      
      if zombie_pids.any?
        Rails.logger.warn "[MCP Health Monitor] Found #{zombie_pids.size} zombie processes"
        
        zombie_pids.each do |pid|
          begin
            # Try to reap the zombie
            Process.waitpid(pid, Process::WNOHANG)
            Rails.logger.info "[MCP Health Monitor] Reaped zombie process #{pid}"
          rescue Errno::ECHILD, Errno::ESRCH
            # Process already reaped or doesn't exist
          end
        end
      end
    rescue => e
      Rails.logger.error "[MCP Health Monitor] Error cleaning up zombies: #{e.message}"
    end
  end
end