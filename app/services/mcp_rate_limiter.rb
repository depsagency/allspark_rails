# frozen_string_literal: true

class McpRateLimiter
  RATE_LIMIT_PREFIX = 'mcp_rate_limit'
  DEFAULT_LIMITS = {
    per_second: 10,
    per_minute: 100,
    per_hour: 1000,
    per_day: 5000
  }.freeze

  class RateLimitExceeded < StandardError
    attr_reader :retry_after, :limit_type, :current_count, :limit

    def initialize(message, retry_after: nil, limit_type: nil, current_count: nil, limit: nil)
      super(message)
      @retry_after = retry_after
      @limit_type = limit_type
      @current_count = current_count
      @limit = limit
    end
  end

  def initialize(server_id, user_id = nil)
    @server_id = server_id
    @user_id = user_id
    @server = McpServer.find(server_id)
  end

  def check_limits!
    # Check server-level limits
    check_server_limits!
    
    # Check user-level limits if user is specified
    check_user_limits! if @user_id
    
    # Check global system limits
    check_global_limits!
  end

  def record_request
    current_time = Time.current
    
    # Record for different time windows
    %w[second minute hour day].each do |window|
      key = build_key('server', @server_id, window, current_time)
      increment_counter(key, window_ttl(window))
      
      if @user_id
        user_key = build_key('user', @user_id, window, current_time)
        increment_counter(user_key, window_ttl(window))
      end
      
      global_key = build_key('global', 'all', window, current_time)
      increment_counter(global_key, window_ttl(window))
    end
  end

  def get_current_usage
    current_time = Time.current
    
    {
      server: get_usage_for_entity('server', @server_id, current_time),
      user: @user_id ? get_usage_for_entity('user', @user_id, current_time) : nil,
      global: get_usage_for_entity('global', 'all', current_time)
    }.compact
  end

  def get_remaining_quota
    current_usage = get_current_usage
    limits = get_effective_limits
    
    {
      server: calculate_remaining(current_usage[:server], limits[:server]),
      user: @user_id ? calculate_remaining(current_usage[:user], limits[:user]) : nil,
      global: calculate_remaining(current_usage[:global], limits[:global])
    }.compact
  end

  private

  def check_server_limits!
    current_time = Time.current
    server_limits = get_server_limits
    
    %w[second minute hour day].each do |window|
      limit = server_limits[:"per_#{window}"]
      next unless limit && limit > 0
      
      key = build_key('server', @server_id, window, current_time)
      current_count = get_counter(key)
      
      if current_count >= limit
        retry_after = calculate_retry_after(window, current_time)
        raise RateLimitExceeded.new(
          "Server rate limit exceeded: #{current_count}/#{limit} requests per #{window}",
          retry_after: retry_after,
          limit_type: "server_#{window}",
          current_count: current_count,
          limit: limit
        )
      end
    end
  end

  def check_user_limits!
    return unless @user_id
    
    current_time = Time.current
    user_limits = get_user_limits
    
    %w[second minute hour day].each do |window|
      limit = user_limits[:"per_#{window}"]
      next unless limit && limit > 0
      
      key = build_key('user', @user_id, window, current_time)
      current_count = get_counter(key)
      
      if current_count >= limit
        retry_after = calculate_retry_after(window, current_time)
        raise RateLimitExceeded.new(
          "User rate limit exceeded: #{current_count}/#{limit} requests per #{window}",
          retry_after: retry_after,
          limit_type: "user_#{window}",
          current_count: current_count,
          limit: limit
        )
      end
    end
  end

  def check_global_limits!
    current_time = Time.current
    global_limits = get_global_limits
    
    %w[second minute hour day].each do |window|
      limit = global_limits[:"per_#{window}"]
      next unless limit && limit > 0
      
      key = build_key('global', 'all', window, current_time)
      current_count = get_counter(key)
      
      if current_count >= limit
        retry_after = calculate_retry_after(window, current_time)
        raise RateLimitExceeded.new(
          "Global rate limit exceeded: #{current_count}/#{limit} requests per #{window}",
          retry_after: retry_after,
          limit_type: "global_#{window}",
          current_count: current_count,
          limit: limit
        )
      end
    end
  end

  def get_server_limits
    # Get custom limits from server config, fall back to defaults
    config_limits = @server.config&.dig('rate_limits') || {}
    
    {
      per_second: config_limits['per_second'] || DEFAULT_LIMITS[:per_second],
      per_minute: config_limits['per_minute'] || DEFAULT_LIMITS[:per_minute],
      per_hour: config_limits['per_hour'] || DEFAULT_LIMITS[:per_hour],
      per_day: config_limits['per_day'] || DEFAULT_LIMITS[:per_day]
    }
  end

  def get_user_limits
    # Get user-specific rate limits from app config
    Rails.application.config.mcp&.dig(:user_rate_limits) || {
      per_second: 5,
      per_minute: 50,
      per_hour: 500,
      per_day: 2000
    }
  end

  def get_global_limits
    # Get global system rate limits from app config
    Rails.application.config.mcp&.dig(:global_rate_limits) || {
      per_second: 100,
      per_minute: 1000,
      per_hour: 10000,
      per_day: 50000
    }
  end

  def get_effective_limits
    {
      server: get_server_limits,
      user: @user_id ? get_user_limits : nil,
      global: get_global_limits
    }.compact
  end

  def build_key(entity_type, entity_id, window, time)
    window_start = case window
    when 'second'
      time.beginning_of_minute.to_i + time.sec
    when 'minute'
      time.beginning_of_hour.to_i + (time.min * 60)
    when 'hour'
      time.beginning_of_day.to_i + (time.hour * 3600)
    when 'day'
      time.beginning_of_day.to_i
    end
    
    "#{RATE_LIMIT_PREFIX}:#{entity_type}:#{entity_id}:#{window}:#{window_start}"
  end

  def window_ttl(window)
    case window
    when 'second'
      60 # Keep for 1 minute
    when 'minute'
      3600 # Keep for 1 hour
    when 'hour'
      86400 # Keep for 1 day
    when 'day'
      604800 # Keep for 1 week
    end
  end

  def calculate_retry_after(window, current_time)
    case window
    when 'second'
      1
    when 'minute'
      60 - current_time.sec
    when 'hour'
      3600 - (current_time.min * 60 + current_time.sec)
    when 'day'
      86400 - (current_time.hour * 3600 + current_time.min * 60 + current_time.sec)
    else
      60
    end
  end

  def increment_counter(key, ttl)
    Rails.cache.fetch(key, expires_in: ttl) { 0 }
    current = Rails.cache.increment(key) || 1
    Rails.cache.write(key, current, expires_in: ttl) if current == 1
    current
  end

  def get_counter(key)
    Rails.cache.read(key) || 0
  end

  def get_usage_for_entity(entity_type, entity_id, current_time)
    {
      per_second: get_counter(build_key(entity_type, entity_id, 'second', current_time)),
      per_minute: get_counter(build_key(entity_type, entity_id, 'minute', current_time)),
      per_hour: get_counter(build_key(entity_type, entity_id, 'hour', current_time)),
      per_day: get_counter(build_key(entity_type, entity_id, 'day', current_time))
    }
  end

  def calculate_remaining(current_usage, limits)
    {
      per_second: [limits[:per_second] - current_usage[:per_second], 0].max,
      per_minute: [limits[:per_minute] - current_usage[:per_minute], 0].max,
      per_hour: [limits[:per_hour] - current_usage[:per_hour], 0].max,
      per_day: [limits[:per_day] - current_usage[:per_day], 0].max
    }
  end
end