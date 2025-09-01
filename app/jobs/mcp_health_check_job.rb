class McpHealthCheckJob < ApplicationJob
  queue_as :default
  
  HEALTH_CHECK_INTERVAL = 5.minutes
  UNHEALTHY_THRESHOLD = 3 # Number of consecutive failures before marking unhealthy
  
  retry_on StandardError, wait: 1.minute, attempts: 2

  def perform(server_id = nil)
    if server_id
      check_single_server(server_id)
    else
      check_all_servers
    end
  end

  def self.schedule_periodic_checks
    # Schedule health checks for all active servers
    perform_later
    
    # Schedule next check
    set(wait: HEALTH_CHECK_INTERVAL).perform_later
  end

  def self.check_server_health(server)
    perform_later(server.id)
  end

  private

  def check_all_servers
    Rails.logger.info "[MCP Health] Starting health check for all active servers"
    
    servers = McpServer.active
    healthy_count = 0
    unhealthy_count = 0
    
    servers.find_each do |server|
      begin
        result = check_server_health(server)
        if result[:healthy]
          healthy_count += 1
        else
          unhealthy_count += 1
        end
      rescue => e
        Rails.logger.error "[MCP Health] Error checking server #{server.id}: #{e.message}"
        unhealthy_count += 1
      end
    end
    
    Rails.logger.info "[MCP Health] Health check complete: #{healthy_count} healthy, #{unhealthy_count} unhealthy"
    
    # Update global health metrics
    update_global_health_metrics(healthy_count, unhealthy_count)
  end

  def check_single_server(server_id)
    server = McpServer.find(server_id)
    
    Rails.logger.debug "[MCP Health] Checking health for server #{server.name}"
    
    result = check_server_health(server)
    
    if result[:healthy]
      Rails.logger.debug "[MCP Health] Server #{server.name} is healthy (#{result[:response_time]}ms)"
    else
      Rails.logger.warn "[MCP Health] Server #{server.name} is unhealthy: #{result[:error]}"
    end
    
    result
  end

  def check_server_health(server)
    start_time = Time.current
    
    # Use instrumentation for health checks
    healthy = McpInstrumentation.instance.instrument_health_check(server.id) do
      # Test basic connection
      client = McpClient.new(server)
      client.test_connection
    end
    
    response_time = ((Time.current - start_time) * 1000).round
    
    # Update health status in connection manager
    connection_manager = McpConnectionManager.instance
    previous_status = connection_manager.health_status(server)
    
    # Track consecutive failures
    consecutive_failures = get_consecutive_failures(server.id)
    
    if healthy
      # Reset failure count on success
      clear_consecutive_failures(server.id)
      
      # Update connection manager health status
      set_health_status(server.id, true)
      
      # Update server status if it was in error
      if server.error?
        server.update(status: :active)
        Rails.logger.info "[MCP Health] Server #{server.name} recovered from error state"
      end
      
      {
        healthy: true,
        response_time: response_time,
        consecutive_failures: 0,
        status_changed: previous_status != true
      }
    else
      # Increment failure count
      new_failure_count = increment_consecutive_failures(server.id)
      
      # Mark as unhealthy if threshold exceeded
      if new_failure_count >= UNHEALTHY_THRESHOLD
        set_health_status(server.id, false)
        
        # Update server status to error if not already
        unless server.error?
          server.update(status: :error)
          Rails.logger.error "[MCP Health] Server #{server.name} marked as error after #{new_failure_count} consecutive failures"
          
          # Send alert
          send_unhealthy_alert(server, new_failure_count)
        end
      end
      
      {
        healthy: false,
        error: "Connection test failed",
        response_time: response_time,
        consecutive_failures: new_failure_count,
        status_changed: previous_status != false && new_failure_count >= UNHEALTHY_THRESHOLD
      }
    end
  rescue => e
    response_time = ((Time.current - start_time) * 1000).round
    
    # Increment failure count
    new_failure_count = increment_consecutive_failures(server.id)
    
    # Mark as unhealthy
    set_health_status(server.id, false)
    
    # Update server status if threshold exceeded
    if new_failure_count >= UNHEALTHY_THRESHOLD && !server.error?
      server.update(status: :error)
      send_unhealthy_alert(server, new_failure_count)
    end
    
    Rails.logger.error "[MCP Health] Health check failed for #{server.name}: #{e.message}"
    
    {
      healthy: false,
      error: e.message,
      response_time: response_time,
      consecutive_failures: new_failure_count,
      status_changed: new_failure_count == UNHEALTHY_THRESHOLD
    }
  end

  def get_consecutive_failures(server_id)
    cache_key = "mcp_health_failures_#{server_id}"
    Rails.cache.read(cache_key) || 0
  end

  def increment_consecutive_failures(server_id)
    cache_key = "mcp_health_failures_#{server_id}"
    current_failures = Rails.cache.read(cache_key) || 0
    new_count = current_failures + 1
    
    Rails.cache.write(cache_key, new_count, expires_in: 1.hour)
    new_count
  end

  def clear_consecutive_failures(server_id)
    cache_key = "mcp_health_failures_#{server_id}"
    Rails.cache.delete(cache_key)
  end

  def set_health_status(server_id, healthy)
    # Update connection manager
    connection_manager = McpConnectionManager.instance
    # Note: This is a simplified approach - in a real implementation,
    # the connection manager would have a method to update health status
    
    # Update cache for tracking
    health_cache_key = "mcp_health_status_#{server_id}"
    Rails.cache.write(health_cache_key, healthy, expires_in: 10.minutes)
  end

  def send_unhealthy_alert(server, failure_count)
    Rails.logger.error "[MCP Health Alert] Server #{server.name} is unhealthy after #{failure_count} consecutive failures"
    
    # Create alert through error handler
    error = StandardError.new("Server unhealthy after #{failure_count} consecutive failures")
    
    McpErrorHandler.instance.handle_error(error, {
      server_id: server.id,
      server_name: server.name,
      context: 'health_check_alert',
      consecutive_failures: failure_count,
      alert_type: 'server_unhealthy'
    })
    
    # Broadcast alert
    ActionCable.server.broadcast(
      'mcp_alerts',
      {
        type: 'server_unhealthy',
        server_id: server.id,
        server_name: server.name,
        consecutive_failures: failure_count,
        timestamp: Time.current.iso8601
      }
    )
  end

  def update_global_health_metrics(healthy_count, unhealthy_count)
    total_servers = healthy_count + unhealthy_count
    health_percentage = total_servers > 0 ? (healthy_count.to_f / total_servers * 100).round(2) : 100
    
    # Store global health metrics
    Rails.cache.write('mcp_global_health', {
      healthy_servers: healthy_count,
      unhealthy_servers: unhealthy_count,
      total_servers: total_servers,
      health_percentage: health_percentage,
      last_check: Time.current.iso8601
    }, expires_in: 10.minutes)
    
    # Log overall health
    if health_percentage < 80
      Rails.logger.warn "[MCP Health] Overall system health is low: #{health_percentage}%"
    else
      Rails.logger.info "[MCP Health] Overall system health: #{health_percentage}%"
    end
    
    # Broadcast global health update
    ActionCable.server.broadcast(
      'mcp_system_health',
      {
        type: 'global_health_update',
        healthy_servers: healthy_count,
        unhealthy_servers: unhealthy_count,
        health_percentage: health_percentage,
        timestamp: Time.current.iso8601
      }
    )
  end
end