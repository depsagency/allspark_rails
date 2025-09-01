# frozen_string_literal: true

# Service for MCP analytics and monitoring using the new MCP Configuration system
# Replaces the analytics functionality from the deprecated McpServer system
class McpAnalyticsService
  def initialize(timeframe: 'last_7_days')
    @timeframe = timeframe
    @end_date = Time.current
    @start_date = calculate_start_date(timeframe)
  end

  # Get comprehensive analytics data for MCP configurations
  def global_analytics
    audit_logs = McpAuditLog.where(executed_at: @start_date..@end_date)
    
    {
      overview: global_overview(audit_logs),
      usage_trends: global_usage_trends,
      response_time_distribution: response_time_distribution(audit_logs),
      top_configurations: top_performing_configurations(audit_logs),
      popular_tools: most_popular_tools(audit_logs),
      health: global_health_status,
      unhealthy_configurations: unhealthy_configurations,
      recent_activity: recent_activity(50)
    }
  end

  # Get analytics for a specific MCP configuration
  def configuration_analytics(configuration_id)
    configuration = McpConfiguration.find(configuration_id)
    audit_logs = configuration.mcp_audit_logs.where(executed_at: @start_date..@end_date)

    {
      configuration: configuration,
      usage_stats: configuration_usage_statistics(configuration, audit_logs),
      error_stats: configuration_error_statistics(configuration, audit_logs),
      performance_stats: configuration_performance_statistics(audit_logs),
      health_status: configuration_health_status(configuration),
      daily_usage: daily_usage(configuration),
      tool_usage: tool_usage_breakdown(audit_logs)
    }
  end

  # Get health statistics for all configurations
  def health_statistics
    total = McpConfiguration.count
    active = McpConfiguration.where(enabled: true).count
    inactive = total - active
    error_count = count_configurations_with_errors

    {
      total: total,
      active: active,
      inactive: inactive,
      error: error_count,
      health_percentage: total > 0 ? (active.to_f / total * 100).round(1) : 100
    }
  end

  private

  def calculate_start_date(timeframe)
    case timeframe
    when 'last_24_hours'
      24.hours.ago
    when 'last_7_days'
      7.days.ago
    when 'last_30_days'
      30.days.ago
    when 'last_90_days'
      90.days.ago
    else
      7.days.ago
    end
  end

  def global_overview(audit_logs)
    total_configurations = McpConfiguration.count
    active_configurations = McpConfiguration.where(enabled: true).count
    total_executions = audit_logs.count
    successful_executions = audit_logs.where(status: 'success').count

    success_rate = total_executions > 0 ? (successful_executions.to_f / total_executions * 100).round(1) : 0
    avg_response_time = audit_logs.where(status: 'success').average(:response_time_ms)&.round(0) || 0

    # Calculate P95 response time
    response_times = audit_logs.where(status: 'success').pluck(:response_time_ms).compact.sort
    p95_index = (response_times.length * 0.95).ceil - 1
    p95_response_time = response_times[p95_index] || 0

    # Get most used tool
    most_used_tool = audit_logs.group(:tool_name).count.max_by { |_, count| count }&.first || 'None'

    # Count total available tools across all active configurations
    total_tools = count_total_available_tools

    {
      total_configurations: total_configurations,
      active_configurations: active_configurations,
      total_executions: total_executions,
      success_rate: success_rate,
      avg_response_time: avg_response_time,
      p95_response_time: p95_response_time,
      total_tools: total_tools,
      most_used_tool: most_used_tool
    }
  end

  def global_usage_trends
    days = (@start_date.to_date..@end_date.to_date).to_a
    labels = days.map { |date| date.strftime('%m/%d') }

    successful_data = days.map do |date|
      McpAuditLog.where(status: 'success')
                 .where(executed_at: date.beginning_of_day..date.end_of_day)
                 .count
    end

    failed_data = days.map do |date|
      McpAuditLog.where(status: 'error')
                 .where(executed_at: date.beginning_of_day..date.end_of_day)
                 .count
    end

    {
      labels: labels,
      successful: successful_data,
      failed: failed_data
    }
  end

  def response_time_distribution(audit_logs)
    response_times = audit_logs.where(status: 'success').pluck(:response_time_ms).compact

    # Define buckets
    buckets = {
      '0-100ms' => 0,
      '100-500ms' => 0,
      '500-1000ms' => 0,
      '1000-5000ms' => 0,
      '5000ms+' => 0
    }

    response_times.each do |time|
      case time
      when 0..100
        buckets['0-100ms'] += 1
      when 101..500
        buckets['100-500ms'] += 1
      when 501..1000
        buckets['500-1000ms'] += 1
      when 1001..5000
        buckets['1000-5000ms'] += 1
      else
        buckets['5000ms+'] += 1
      end
    end

    {
      labels: buckets.keys,
      data: buckets.values
    }
  end

  def top_performing_configurations(audit_logs)
    configuration_stats = {}

    McpConfiguration.includes(:mcp_audit_logs).each do |config|
      config_logs = audit_logs.joins(:mcp_configuration).where(mcp_configurations: { id: config.id })
      total = config_logs.count
      next if total == 0

      successful = config_logs.where(status: 'success').count
      success_rate = (successful.to_f / total * 100).round(1)
      avg_response = config_logs.where(status: 'success').average(:response_time_ms)&.round(0) || 0

      configuration_stats[config.id] = {
        name: config.name,
        server_type: config.server_type,
        executions: total,
        success_rate: success_rate,
        avg_response_time: avg_response
      }
    end

    # Sort by executions and take top 10
    configuration_stats.values.sort_by { |s| -s[:executions] }.first(10)
  end

  def most_popular_tools(audit_logs)
    tool_usage = audit_logs.joins(:mcp_configuration)
                          .group(:tool_name, 'mcp_configurations.name')
                          .count
                          .map { |(tool, config_name), count|
                            {
                              name: tool,
                              configuration_name: config_name,
                              usage_count: count
                            }
                          }
                          .sort_by { |tool| -tool[:usage_count] }
                          .first(10)

    tool_usage
  end

  def global_health_status
    configurations = McpConfiguration.where(enabled: true)
    healthy = 0
    warning = 0
    critical = 0

    configurations.each do |config|
      recent_logs = config.mcp_audit_logs.where(status: 'success')
                         .where('executed_at > ?', 1.hour.ago)
      next if recent_logs.empty?

      avg_response_time = recent_logs.average(:response_time_ms) || 0

      if avg_response_time < 1000
        healthy += 1
      elsif avg_response_time < 5000
        warning += 1
      else
        critical += 1
      end
    end

    # Add configurations with no recent successful executions to critical
    if McpAuditLog.exists?
      configs_with_no_recent_success = configurations.left_joins(:mcp_audit_logs)
                                                   .where.not(
                                                     id: configurations.joins(:mcp_audit_logs)
                                                                      .where('mcp_audit_logs.status = ? AND mcp_audit_logs.executed_at > ?',
                                                                             'success', 1.hour.ago)
                                                                      .select(:id)
                                                   )
                                                   .count
      critical += configs_with_no_recent_success
    else
      # If no audit logs exist, all configurations are potentially critical
      critical += configurations.count
    end

    {
      healthy: healthy,
      warning: warning,
      critical: critical
    }
  end

  def unhealthy_configurations
    unhealthy = []

    McpConfiguration.where(enabled: true).each do |config|
      # Check for configurations with recent failures
      recent_failures = config.mcp_audit_logs.where(status: 'error')
                             .where('executed_at > ?', 1.hour.ago).count
      recent_total = config.mcp_audit_logs.where('executed_at > ?', 1.hour.ago).count

      if recent_total > 0 && recent_failures.to_f / recent_total > 0.5
        unhealthy << {
          id: config.id,
          name: config.name,
          status: 'warning',
          issue: "High failure rate: #{recent_failures}/#{recent_total} executions failed in last hour"
        }
      end

      # Check for configurations with no recent activity
      last_execution = config.mcp_audit_logs.maximum(:executed_at)
      if last_execution.nil? || last_execution < 24.hours.ago
        unhealthy << {
          id: config.id,
          name: config.name,
          status: 'error',
          issue: last_execution ? "No activity since #{last_execution.strftime('%m/%d/%Y %H:%M')}" : "No recorded activity"
        }
      end
    end

    unhealthy.first(10) # Limit to 10 most critical
  end

  def recent_activity(limit = 50)
    return [] unless McpAuditLog.exists?

    McpAuditLog.includes(:user, :mcp_configuration)
               .order(executed_at: :desc)
               .limit(limit)
               .map do |log|
      {
        timestamp: log.executed_at,
        configuration_name: log.mcp_configuration&.name || 'Unknown Configuration',
        tool_name: log.tool_name,
        user_email: log.user&.email || 'Unknown User',
        status: log.status,
        response_time: log.response_time_ms || 0
      }
    end
  end

  def configuration_usage_statistics(configuration, audit_logs)
    {
      total_executions: audit_logs.count,
      successful_executions: audit_logs.where(status: 'success').count,
      failed_executions: audit_logs.where(status: 'error').count,
      avg_response_time: audit_logs.where(status: 'success').average(:response_time_ms)&.round(2),
      most_used_tools: audit_logs.group(:tool_name).count.sort_by { |_, count| -count }.first(5),
      daily_usage: daily_usage(configuration),
      top_users: audit_logs.joins(:user).group('users.email').count.sort_by { |_, count| -count }.first(5)
    }
  end

  def configuration_error_statistics(configuration, audit_logs)
    error_logs = audit_logs.where(status: 'error')

    {
      total_errors: error_logs.count,
      error_rate: calculate_error_rate(configuration),
      common_errors: group_common_errors(error_logs),
      error_trends: get_error_trends(configuration)
    }
  end

  def configuration_performance_statistics(audit_logs)
    successful_logs = audit_logs.where(status: 'success')
    response_times = successful_logs.pluck(:response_time_ms).compact

    if response_times.any?
      sorted_times = response_times.sort
      {
        avg_response_time: response_times.sum.to_f / response_times.size,
        median_response_time: sorted_times[sorted_times.size / 2],
        p95_response_time: sorted_times[(sorted_times.size * 0.95).to_i],
        min_response_time: sorted_times.first,
        max_response_time: sorted_times.last
      }
    else
      {
        avg_response_time: 0,
        median_response_time: 0,
        p95_response_time: 0,
        min_response_time: 0,
        max_response_time: 0
      }
    end
  end

  def configuration_health_status(configuration)
    cache_key = "mcp_health_failures_#{configuration.id}"
    consecutive_failures = Rails.cache.read(cache_key) || 0

    {
      healthy: consecutive_failures == 0,
      consecutive_failures: consecutive_failures,
      last_check: Rails.cache.read("mcp_health_last_check_#{configuration.id}")
    }
  end

  def daily_usage(configuration)
    # Get usage for last 7 days
    7.downto(0).map do |days_ago|
      date = days_ago.days.ago.to_date
      count = configuration.mcp_audit_logs.where(
        executed_at: date.beginning_of_day..date.end_of_day
      ).count
      [date.strftime('%Y-%m-%d'), count]
    end.to_h
  end

  def tool_usage_breakdown(audit_logs)
    audit_logs.group(:tool_name)
              .group("date_trunc('day', executed_at)")
              .count
              .transform_keys { |(tool, date)| [tool, date.strftime('%Y-%m-%d')] }
  end

  def calculate_error_rate(configuration)
    total = configuration.mcp_audit_logs.where(executed_at: @start_date..@end_date).count
    errors = configuration.mcp_audit_logs.where(status: 'error')
                          .where(executed_at: @start_date..@end_date).count

    return 0 if total == 0
    (errors.to_f / total * 100).round(2)
  end

  def group_common_errors(error_logs)
    # Group by error patterns in response_data
    error_patterns = {}

    error_logs.each do |log|
      error_msg = extract_error_message(log.response_data)
      error_patterns[error_msg] ||= 0
      error_patterns[error_msg] += 1
    end

    error_patterns.sort_by { |_, count| -count }.first(5).to_h
  end

  def extract_error_message(response_data)
    return 'Unknown error' unless response_data.is_a?(Hash)

    response_data['error'] || response_data['message'] || 'Unknown error'
  end

  def get_error_trends(configuration)
    # Get error counts for last 7 days
    7.downto(0).map do |days_ago|
      date = days_ago.days.ago.to_date
      count = configuration.mcp_audit_logs.where(status: 'error')
                           .where(executed_at: date.beginning_of_day..date.end_of_day)
                           .count
      [date.strftime('%Y-%m-%d'), count]
    end.to_h
  end

  def count_configurations_with_errors
    # Count configurations that have had errors in the timeframe
    McpConfiguration.joins(:mcp_audit_logs)
                    .where(mcp_audit_logs: { status: 'error', executed_at: @start_date..@end_date })
                    .distinct
                    .count
  end

  def count_total_available_tools
    # This would need to be implemented based on how tools are discovered
    # For now, return a placeholder that can be updated when bridge manager integration is complete
    McpConfiguration.where(enabled: true).count * 5 # Placeholder: assume avg 5 tools per config
  end
end