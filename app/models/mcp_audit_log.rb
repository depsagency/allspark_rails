class McpAuditLog < ApplicationRecord
  belongs_to :user
  belongs_to :mcp_server, optional: true
  belongs_to :mcp_configuration, optional: true
  belongs_to :assistant

  validates :tool_name, presence: true
  validates :executed_at, presence: true
  
  # Ensure either mcp_server or mcp_configuration is present
  validate :mcp_source_present

  # JSON serialization
  serialize :request_data, coder: JSON
  serialize :response_data, coder: JSON

  # Enums
  enum :status, { successful: 0, failed: 1, timeout: 2 }

  # Scopes
  scope :recent, -> { where('executed_at > ?', 30.days.ago) }
  scope :by_server, ->(server) { where(mcp_server: server) }
  scope :by_user, ->(user) { where(user: user) }
  scope :failed, -> { where(status: :failed) }
  scope :successful, -> { where(status: :successful) }
  scope :timed_out, -> { where(status: :timeout) }
  scope :by_tool, ->(tool_name) { where(tool_name: tool_name) }
  scope :in_date_range, ->(start_date, end_date) { where(executed_at: start_date..end_date) }

  # Class methods
  def self.log_execution(user:, mcp_server:, assistant:, tool_name:, request_data:, response_data:, status:, response_time_ms: nil)
    create!(
      user: user,
      mcp_server: mcp_server,
      assistant: assistant,
      tool_name: tool_name,
      request_data: request_data,
      response_data: response_data,
      executed_at: Time.current,
      status: status,
      response_time_ms: response_time_ms
    )
  end

  def self.average_response_time(scope = all)
    scope.where.not(response_time_ms: nil).average(:response_time_ms)&.round(2)
  end

  def self.success_rate(scope = all)
    total = scope.count
    return 0 if total.zero?
    
    successful = scope.successful.count
    (successful.to_f / total * 100).round(2)
  end

  def self.failure_rate(scope = all)
    total = scope.count
    return 0 if total.zero?
    
    failed = scope.failed.count
    (failed.to_f / total * 100).round(2)
  end

  def self.timeout_rate(scope = all)
    total = scope.count
    return 0 if total.zero?
    
    timed_out = scope.timed_out.count
    (timed_out.to_f / total * 100).round(2)
  end

  # Instance methods
  def successful?
    status == 'success'
  end

  def failed?
    status == 'failure'
  end

  def timed_out?
    status == 'timeout'
  end

  def response_time_seconds
    return nil unless response_time_ms
    response_time_ms / 1000.0
  end

  def formatted_response_time
    return 'N/A' unless response_time_ms
    
    if response_time_ms < 1000
      "#{response_time_ms}ms"
    else
      "#{response_time_seconds.round(2)}s"
    end
  end

  # Analytics methods
  def self.usage_by_hour(start_date = 7.days.ago, end_date = Time.current)
    in_date_range(start_date, end_date)
      .group("DATE_TRUNC('hour', executed_at)")
      .count
  end

  def self.usage_by_day(start_date = 30.days.ago, end_date = Time.current)
    in_date_range(start_date, end_date)
      .group("DATE_TRUNC('day', executed_at)")
      .count
  end

  def self.top_tools(limit = 10, start_date = 30.days.ago)
    where('executed_at > ?', start_date)
      .group(:tool_name)
      .order('count_all DESC')
      .limit(limit)
      .count
  end

  def self.top_users(limit = 10, start_date = 30.days.ago)
    where('executed_at > ?', start_date)
      .joins(:user)
      .group('users.email')
      .order('count_all DESC')
      .limit(limit)
      .count
  end

  private

  def mcp_source_present
    unless mcp_server_id.present? || mcp_configuration_id.present?
      errors.add(:base, 'Either mcp_server or mcp_configuration must be present')
    end
  end
end