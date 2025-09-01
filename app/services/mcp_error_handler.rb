class McpErrorHandler
  include Singleton

  # Error categories for analytics
  ERROR_CATEGORIES = {
    connection: ['ConnectionError', 'TimeoutError', 'ProtocolError'],
    authentication: ['AuthenticationError'],
    rate_limiting: ['RateLimitError'],
    server: ['ServerError'],
    client: ['ClientError'],
    unknown: ['StandardError', 'RuntimeError']
  }.freeze

  # Alert thresholds
  DEFAULT_THRESHOLDS = {
    error_rate_5min: 50.0,    # 50% error rate in 5 minutes
    error_count_1min: 10,     # 10 errors in 1 minute
    consecutive_failures: 5,   # 5 consecutive failures
    timeout_rate_5min: 30.0   # 30% timeout rate in 5 minutes
  }.freeze

  def initialize
    @error_counts = Concurrent::Map.new
    @error_history = Concurrent::Map.new
    @alert_history = Concurrent::Map.new
    @mutex = Mutex.new
  end

  def handle_error(error, context = {})
    error_data = build_error_data(error, context)
    
    # Log the error
    log_error(error_data)
    
    # Store error for analytics
    store_error(error_data)
    
    # Check alert thresholds
    check_alerts(error_data)
    
    # Return standardized error response
    build_error_response(error_data)
  end

  def error_stats(time_window = 1.hour)
    @mutex.synchronize do
      cutoff_time = Time.current - time_window
      
      recent_errors = @error_history.values.flatten.select do |error|
        error[:timestamp] >= cutoff_time
      end
      
      total_errors = recent_errors.size
      return { total: 0, by_category: {}, by_server: {}, rate: 0.0 } if total_errors.zero?
      
      by_category = recent_errors.group_by { |e| e[:category] }
                                 .transform_values(&:size)
      
      by_server = recent_errors.group_by { |e| e[:server_id] }
                               .transform_values(&:size)
      
      by_error_type = recent_errors.group_by { |e| e[:error_type] }
                                   .transform_values(&:size)
      
      error_rate = (total_errors.to_f / time_window.in_minutes).round(2)
      
      {
        total: total_errors,
        rate_per_minute: error_rate,
        by_category: by_category,
        by_server: by_server,
        by_error_type: by_error_type,
        time_window: time_window.inspect
      }
    end
  end

  def server_error_stats(server_id, time_window = 1.hour)
    @mutex.synchronize do
      cutoff_time = Time.current - time_window
      server_key = "server_#{server_id}"
      
      server_errors = @error_history[server_key] || []
      recent_errors = server_errors.select { |error| error[:timestamp] >= cutoff_time }
      
      return { total: 0, consecutive: 0, last_error: nil } if recent_errors.empty?
      
      # Count consecutive failures from most recent
      consecutive = 0
      recent_errors.reverse_each do |error|
        if error[:category] == :connection || error[:category] == :server
          consecutive += 1
        else
          break
        end
      end
      
      {
        total: recent_errors.size,
        consecutive: consecutive,
        last_error: recent_errors.last,
        by_category: recent_errors.group_by { |e| e[:category] }.transform_values(&:size),
        error_rate: (recent_errors.size.to_f / time_window.in_minutes).round(2)
      }
    end
  end

  def clear_old_errors(retention_period = 24.hours)
    @mutex.synchronize do
      cutoff_time = Time.current - retention_period
      cleared_count = 0
      
      @error_history.each do |key, errors|
        original_size = errors.size
        errors.reject! { |error| error[:timestamp] < cutoff_time }
        cleared_count += (original_size - errors.size)
        
        # Remove empty arrays
        @error_history.delete(key) if errors.empty?
      end
      
      # Clear old alert history
      @alert_history.each do |key, alerts|
        alerts.reject! { |alert| alert[:timestamp] < cutoff_time }
        @alert_history.delete(key) if alerts.empty?
      end
      
      Rails.logger.info "[MCP] Cleared #{cleared_count} old error records"
      cleared_count
    end
  end

  def export_errors(format: :json, time_window: 24.hours)
    stats = error_stats(time_window)
    
    case format
    when :json
      stats.to_json
    when :csv
      generate_csv(stats)
    else
      raise ArgumentError, "Unsupported export format: #{format}"
    end
  end

  def get_recovery_suggestions(error_category, server_id = nil)
    suggestions = []
    
    case error_category
    when :connection
      suggestions << "Check server endpoint URL and network connectivity"
      suggestions << "Verify firewall rules and DNS resolution"
      suggestions << "Test connection manually using curl or similar tool"
      if server_id
        server = McpServer.find_by(id: server_id)
        suggestions << "Current server status: #{server&.status}" if server
      end
      
    when :authentication
      suggestions << "Verify API credentials are correct and not expired"
      suggestions << "Check if API key has required permissions"
      suggestions << "For OAuth: ensure refresh token is valid"
      suggestions << "Test authentication manually with API documentation"
      
    when :rate_limiting
      suggestions << "Reduce request frequency or implement backoff"
      suggestions << "Check API quota and usage limits"
      suggestions << "Consider upgrading API plan if applicable"
      suggestions << "Implement request queuing to smooth traffic"
      
    when :server
      suggestions << "Check MCP server logs for internal errors"
      suggestions << "Verify server is running and responding"
      suggestions << "Test with minimal request to isolate issue"
      suggestions << "Contact server administrator if external service"
      
    else
      suggestions << "Check application logs for more details"
      suggestions << "Verify MCP server configuration"
      suggestions << "Test with different tool or parameters"
    end
    
    suggestions
  end

  private

  def build_error_data(error, context)
    {
      timestamp: Time.current,
      error_type: error.class.name,
      message: error.message,
      category: categorize_error(error),
      server_id: context[:server_id],
      server_name: context[:server_name],
      tool_name: context[:tool_name],
      user_id: context[:user_id],
      assistant_id: context[:assistant_id],
      request_id: context[:request_id],
      backtrace: error.backtrace&.first(10),
      context: context.except(:server_id, :server_name, :tool_name, :user_id, :assistant_id, :request_id)
    }
  end

  def categorize_error(error)
    ERROR_CATEGORIES.each do |category, error_types|
      return category if error_types.any? { |type| error.class.name.include?(type) }
    end
    
    :unknown
  end

  def log_error(error_data)
    level = determine_log_level(error_data[:category])
    
    message = "[MCP Error] #{error_data[:error_type]}: #{error_data[:message]}"
    message += " (Server: #{error_data[:server_name]})" if error_data[:server_name]
    message += " (Tool: #{error_data[:tool_name]})" if error_data[:tool_name]
    
    case level
    when :error
      Rails.logger.error message
    when :warn
      Rails.logger.warn message
    when :info
      Rails.logger.info message
    else
      Rails.logger.debug message
    end
    
    # Log backtrace in development
    if Rails.env.development? && error_data[:backtrace]
      Rails.logger.debug error_data[:backtrace].join("\n")
    end
  end

  def determine_log_level(category)
    case category
    when :connection, :server, :authentication
      :error
    when :rate_limiting
      :warn
    when :client
      :info
    else
      :debug
    end
  end

  def store_error(error_data)
    @mutex.synchronize do
      # Store by server for server-specific analytics
      if error_data[:server_id]
        server_key = "server_#{error_data[:server_id]}"
        @error_history[server_key] ||= []
        @error_history[server_key] << error_data
        
        # Keep only last 100 errors per server
        @error_history[server_key] = @error_history[server_key].last(100)
      end
      
      # Store in global history
      @error_history[:global] ||= []
      @error_history[:global] << error_data
      @error_history[:global] = @error_history[:global].last(1000)
      
      # Update error counts
      @error_counts[error_data[:category]] ||= 0
      @error_counts[error_data[:category]] += 1
    end
  end

  def check_alerts(error_data)
    return unless error_data[:server_id]
    
    server_stats = server_error_stats(error_data[:server_id], 5.minutes)
    
    # Check consecutive failures
    if server_stats[:consecutive] >= DEFAULT_THRESHOLDS[:consecutive_failures]
      send_alert(:consecutive_failures, error_data, server_stats)
    end
    
    # Check error rate
    if server_stats[:error_rate] >= DEFAULT_THRESHOLDS[:error_rate_5min]
      send_alert(:high_error_rate, error_data, server_stats)
    end
  end

  def send_alert(alert_type, error_data, stats)
    alert_key = "#{alert_type}_#{error_data[:server_id]}"
    
    @mutex.synchronize do
      @alert_history[alert_key] ||= []
      
      # Don't send duplicate alerts within 5 minutes
      last_alert = @alert_history[alert_key].last
      return if last_alert && last_alert[:timestamp] > (Time.current - 5.minutes)
      
      alert_data = {
        timestamp: Time.current,
        type: alert_type,
        server_id: error_data[:server_id],
        server_name: error_data[:server_name],
        stats: stats,
        suggestions: get_recovery_suggestions(error_data[:category], error_data[:server_id])
      }
      
      @alert_history[alert_key] << alert_data
      
      # Send notification (could be enhanced to send emails, webhooks, etc.)
      Rails.logger.error "[MCP ALERT] #{alert_type.to_s.humanize} for server #{error_data[:server_name]} (#{error_data[:server_id]})"
      Rails.logger.error "[MCP ALERT] Stats: #{stats.inspect}"
      Rails.logger.error "[MCP ALERT] Suggestions: #{alert_data[:suggestions].join('; ')}"
    end
  end

  def build_error_response(error_data)
    base_response = {
      error: error_data[:message],
      error_type: error_data[:error_type],
      category: error_data[:category],
      timestamp: error_data[:timestamp].iso8601
    }
    
    # Add recovery suggestions for client errors
    if [:authentication, :rate_limiting, :client].include?(error_data[:category])
      base_response[:suggestions] = get_recovery_suggestions(error_data[:category], error_data[:server_id])
    end
    
    # Add request ID for tracking
    base_response[:request_id] = error_data[:request_id] if error_data[:request_id]
    
    base_response
  end

  def generate_csv(stats)
    require 'csv'
    
    CSV.generate do |csv|
      csv << ['Category', 'Count', 'Percentage']
      
      total = stats[:total]
      stats[:by_category].each do |category, count|
        percentage = total > 0 ? (count.to_f / total * 100).round(2) : 0
        csv << [category, count, "#{percentage}%"]
      end
    end
  end
end