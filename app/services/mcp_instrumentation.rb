class McpInstrumentation
  include Singleton

  # Notification events
  EVENTS = {
    connection_attempt: 'mcp.connection.attempt',
    connection_success: 'mcp.connection.success',
    connection_failure: 'mcp.connection.failure',
    tool_execution: 'mcp.tool.execution',
    tool_discovery: 'mcp.tool.discovery',
    rate_limit_hit: 'mcp.rate_limit.hit',
    health_check: 'mcp.health_check'
  }.freeze

  def initialize
    @metrics = Concurrent::Map.new
    @counters = Concurrent::Map.new
    @timers = Concurrent::Map.new
    
    setup_subscribers
  end

  # Instrument a connection attempt
  def instrument_connection(server_id, &block)
    start_time = Time.current
    
    ActiveSupport::Notifications.instrument(EVENTS[:connection_attempt], {
      server_id: server_id,
      timestamp: start_time
    }) do |payload|
      begin
        result = yield
        
        duration = (Time.current - start_time) * 1000
        
        ActiveSupport::Notifications.instrument(EVENTS[:connection_success], {
          server_id: server_id,
          duration: duration,
          timestamp: Time.current
        })
        
        track_metric(:connection_duration, server_id, duration)
        increment_counter(:successful_connections, server_id)
        
        result
      rescue => error
        duration = (Time.current - start_time) * 1000
        
        ActiveSupport::Notifications.instrument(EVENTS[:connection_failure], {
          server_id: server_id,
          error: error.class.name,
          message: error.message,
          duration: duration,
          timestamp: Time.current
        })
        
        increment_counter(:failed_connections, server_id)
        
        raise error
      end
    end
  end

  # Instrument tool execution
  def instrument_tool_execution(server_id, tool_name, user_id: nil, assistant_id: nil, &block)
    start_time = Time.current
    
    ActiveSupport::Notifications.instrument(EVENTS[:tool_execution], {
      server_id: server_id,
      tool_name: tool_name,
      user_id: user_id,
      assistant_id: assistant_id,
      timestamp: start_time
    }) do |payload|
      begin
        result = yield
        
        duration = (Time.current - start_time) * 1000
        
        payload[:status] = 'success'
        payload[:duration] = duration
        payload[:response_size] = result.to_s.bytesize if result
        
        track_metric(:tool_execution_duration, "#{server_id}_#{tool_name}", duration)
        track_metric(:tool_execution_duration_global, tool_name, duration)
        increment_counter(:successful_tool_executions, server_id)
        increment_counter(:tool_usage, tool_name)
        
        result
      rescue => error
        duration = (Time.current - start_time) * 1000
        
        payload[:status] = 'failure'
        payload[:error] = error.class.name
        payload[:message] = error.message
        payload[:duration] = duration
        
        increment_counter(:failed_tool_executions, server_id)
        increment_counter(:tool_errors, tool_name)
        
        # Track specific error types
        if error.is_a?(McpConnection::Base::TimeoutError)
          increment_counter(:tool_timeouts, server_id)
        elsif error.is_a?(McpConnection::Base::RateLimitError)
          increment_counter(:rate_limit_hits, server_id)
        end
        
        raise error
      end
    end
  end

  # Instrument tool discovery
  def instrument_tool_discovery(server_id, &block)
    start_time = Time.current
    
    ActiveSupport::Notifications.instrument(EVENTS[:tool_discovery], {
      server_id: server_id,
      timestamp: start_time
    }) do |payload|
      begin
        tools = yield
        
        duration = (Time.current - start_time) * 1000
        tool_count = tools.is_a?(Array) ? tools.size : 0
        
        payload[:status] = 'success'
        payload[:duration] = duration
        payload[:tool_count] = tool_count
        
        track_metric(:discovery_duration, server_id, duration)
        track_metric(:discovered_tools, server_id, tool_count)
        increment_counter(:successful_discoveries, server_id)
        
        tools
      rescue => error
        duration = (Time.current - start_time) * 1000
        
        payload[:status] = 'failure'
        payload[:error] = error.class.name
        payload[:message] = error.message
        payload[:duration] = duration
        
        increment_counter(:failed_discoveries, server_id)
        
        raise error
      end
    end
  end

  # Instrument health checks
  def instrument_health_check(server_id, &block)
    start_time = Time.current
    
    ActiveSupport::Notifications.instrument(EVENTS[:health_check], {
      server_id: server_id,
      timestamp: start_time
    }) do |payload|
      begin
        result = yield
        
        duration = (Time.current - start_time) * 1000
        
        payload[:status] = result ? 'healthy' : 'unhealthy'
        payload[:duration] = duration
        
        track_metric(:health_check_duration, server_id, duration)
        
        if result
          increment_counter(:healthy_checks, server_id)
        else
          increment_counter(:unhealthy_checks, server_id)
        end
        
        result
      rescue => error
        duration = (Time.current - start_time) * 1000
        
        payload[:status] = 'error'
        payload[:error] = error.class.name
        payload[:message] = error.message
        payload[:duration] = duration
        
        increment_counter(:health_check_errors, server_id)
        
        raise error
      end
    end
  end

  # Get performance metrics
  def get_metrics(metric_name = nil, time_window = 1.hour)
    cutoff_time = Time.current - time_window
    
    if metric_name
      metric_data = @metrics[metric_name] || []
      recent_data = metric_data.select { |d| d[:timestamp] >= cutoff_time }
      
      return {} if recent_data.empty?
      
      values = recent_data.map { |d| d[:value] }
      
      {
        count: values.size,
        min: values.min,
        max: values.max,
        avg: values.sum.to_f / values.size,
        p50: percentile(values, 50),
        p95: percentile(values, 95),
        p99: percentile(values, 99)
      }
    else
      # Return all metrics
      @metrics.keys.map do |key|
        [key, get_metrics(key, time_window)]
      end.to_h
    end
  end

  # Get counter values
  def get_counters(time_window = 1.hour)
    cutoff_time = Time.current - time_window
    
    @counters.map do |key, entries|
      recent_count = entries.count { |entry| entry[:timestamp] >= cutoff_time }
      [key, recent_count]
    end.to_h
  end

  # Get rate limiting statistics
  def rate_limit_stats(server_id = nil, time_window = 1.hour)
    if server_id
      rate_limits = get_counters(time_window)["rate_limit_hits_#{server_id}"] || 0
      total_requests = (get_counters(time_window)["successful_tool_executions_#{server_id}"] || 0) +
                      (get_counters(time_window)["failed_tool_executions_#{server_id}"] || 0)
      
      rate = total_requests > 0 ? (rate_limits.to_f / total_requests * 100).round(2) : 0
      
      {
        server_id: server_id,
        rate_limit_hits: rate_limits,
        total_requests: total_requests,
        rate_limit_percentage: rate
      }
    else
      # Global stats
      all_counters = get_counters(time_window)
      
      rate_limit_keys = all_counters.keys.select { |k| k.to_s.start_with?('rate_limit_hits_') }
      total_rate_limits = rate_limit_keys.sum { |k| all_counters[k] }
      
      success_keys = all_counters.keys.select { |k| k.to_s.start_with?('successful_tool_executions_') }
      failure_keys = all_counters.keys.select { |k| k.to_s.start_with?('failed_tool_executions_') }
      
      total_requests = success_keys.sum { |k| all_counters[k] } + 
                      failure_keys.sum { |k| all_counters[k] }
      
      rate = total_requests > 0 ? (total_rate_limits.to_f / total_requests * 100).round(2) : 0
      
      {
        rate_limit_hits: total_rate_limits,
        total_requests: total_requests,
        rate_limit_percentage: rate
      }
    end
  end

  # Export metrics data
  def export_metrics(format: :json, time_window: 24.hours)
    data = {
      timestamp: Time.current.iso8601,
      time_window: time_window.inspect,
      metrics: get_metrics(nil, time_window),
      counters: get_counters(time_window),
      rate_limits: rate_limit_stats(nil, time_window)
    }
    
    case format
    when :json
      data.to_json
    when :csv
      generate_metrics_csv(data)
    else
      raise ArgumentError, "Unsupported export format: #{format}"
    end
  end

  # Clear old metrics data
  def cleanup_old_data(retention_period = 24.hours)
    cutoff_time = Time.current - retention_period
    cleaned_count = 0
    
    @metrics.each do |key, values|
      original_size = values.size
      values.reject! { |v| v[:timestamp] < cutoff_time }
      cleaned_count += (original_size - values.size)
      @metrics.delete(key) if values.empty?
    end
    
    @counters.each do |key, entries|
      original_size = entries.size
      entries.reject! { |e| e[:timestamp] < cutoff_time }
      cleaned_count += (original_size - entries.size)
      @counters.delete(key) if entries.empty?
    end
    
    Rails.logger.info "[MCP] Cleaned up #{cleaned_count} old metric data points"
    cleaned_count
  end

  private

  def setup_subscribers
    # Subscribe to all MCP events for logging
    EVENTS.each do |event_name, notification_name|
      ActiveSupport::Notifications.subscribe(notification_name) do |name, start, finish, id, payload|
        duration = (finish - start) * 1000
        
        Rails.logger.debug "[MCP Metrics] #{event_name}: #{payload.inspect} (#{duration.round(2)}ms)"
        
        # Store additional metrics based on event type
        case event_name
        when :connection_success, :connection_failure
          track_metric(:connection_event_duration, payload[:server_id], duration)
        when :tool_execution
          if payload[:status] == 'success'
            track_metric(:successful_execution_duration, payload[:server_id], duration)
          end
        end
      end
    end
  end

  def track_metric(metric_name, key, value)
    full_key = "#{metric_name}_#{key}"
    @metrics[full_key] ||= []
    @metrics[full_key] << {
      timestamp: Time.current,
      value: value.to_f
    }
    
    # Keep only last 1000 data points per metric
    @metrics[full_key] = @metrics[full_key].last(1000)
  end

  def increment_counter(counter_name, key)
    full_key = "#{counter_name}_#{key}"
    @counters[full_key] ||= []
    @counters[full_key] << { timestamp: Time.current }
    
    # Keep only last 10000 entries per counter
    @counters[full_key] = @counters[full_key].last(10000)
  end

  def percentile(values, p)
    return 0 if values.empty?
    
    sorted = values.sort
    index = (p / 100.0) * (sorted.length - 1)
    
    if index == index.to_i
      sorted[index.to_i]
    else
      lower = sorted[index.to_i]
      upper = sorted[index.to_i + 1]
      lower + (upper - lower) * (index - index.to_i)
    end
  end

  def generate_metrics_csv(data)
    require 'csv'
    
    CSV.generate do |csv|
      csv << ['Metric', 'Count', 'Min', 'Max', 'Avg', 'P95', 'P99']
      
      data[:metrics].each do |metric_name, stats|
        csv << [
          metric_name,
          stats[:count],
          stats[:min]&.round(2),
          stats[:max]&.round(2),
          stats[:avg]&.round(2),
          stats[:p95]&.round(2),
          stats[:p99]&.round(2)
        ]
      end
    end
  end
end