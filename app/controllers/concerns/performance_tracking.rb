# frozen_string_literal: true

# PerformanceTracking concern provides controller-level performance monitoring
# and error tracking functionality. Include this in controllers that need
# detailed performance monitoring.
#
# Example usage:
#   class ApplicationController < ActionController::Base
#     include PerformanceTracking
#   end

module PerformanceTracking
  extend ActiveSupport::Concern

  included do
    # Track request performance
    around_action :track_performance, if: :should_track_performance?

    # Handle and track errors
    rescue_from StandardError, with: :handle_and_track_error if Rails.env.production?

    # Add performance headers in development
    after_action :add_performance_headers, if: -> { Rails.env.development? }
  end

  private

  def track_performance
    start_time = Time.current
    start_memory = current_memory_usage if Rails.env.development?

    begin
      yield
    ensure
      end_time = Time.current
      duration = end_time - start_time

      # Log performance metrics
      log_performance_metrics(duration, start_time, start_memory)

      # Track slow requests
      track_slow_request(duration) if duration > slow_request_threshold

      # Send metrics to external services (if configured)
      send_performance_metrics(duration)
    end
  end

  def handle_and_track_error(error)
    # Log the error with request context
    error_context = {
      controller: controller_name,
      action: action_name,
      params: params.to_unsafe_h,
      user_id: current_user&.id,
      user_agent: request.user_agent,
      ip_address: request.remote_ip,
      referer: request.referer,
      request_id: request.uuid
    }

    Rails.logger.error "Unhandled error in #{controller_name}##{action_name}: #{error.class} - #{error.message}"
    Rails.logger.error "Context: #{error_context.inspect}"
    Rails.logger.error error.backtrace.join("\n") if error.backtrace

    # Track error with Rails error handling
    Rails.error.handle(error, context: error_context, severity: :error)

    # Send to external error tracking services
    track_error_externally(error, error_context)

    # Render appropriate error response
    if request.format.json?
      render json: { error: "Internal server error" }, status: :internal_server_error
    else
      render "errors/500", status: :internal_server_error, layout: "error"
    end
  end

  def add_performance_headers
    if @performance_data
      response.headers["X-Runtime"] = "#{@performance_data[:duration].round(6)}"
      response.headers["X-Memory-Usage"] = "#{@performance_data[:memory_delta]}MB" if @performance_data[:memory_delta]
      response.headers["X-DB-Queries"] = @performance_data[:db_queries].to_s if @performance_data[:db_queries]
    end
  end

  def log_performance_metrics(duration, start_time, start_memory = nil)
    @performance_data = {
      controller: controller_name,
      action: action_name,
      duration: duration,
      timestamp: start_time,
      user_id: current_user&.id
    }

    # Calculate memory usage delta (development only)
    if start_memory && Rails.env.development?
      end_memory = current_memory_usage
      @performance_data[:memory_delta] = ((end_memory - start_memory) / 1024.0 / 1024.0).round(2)
    end

    # Count database queries
    if defined?(ActiveSupport::Notifications)
      query_count = 0
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { query_count += 1 }
      @performance_data[:db_queries] = query_count
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    # Log metrics
    Rails.logger.info "Performance: #{controller_name}##{action_name} completed in #{duration.round(3)}s"

    if @performance_data[:memory_delta]
      Rails.logger.debug "Memory delta: #{@performance_data[:memory_delta]}MB"
    end

    if @performance_data[:db_queries] && @performance_data[:db_queries] > 0
      Rails.logger.debug "Database queries: #{@performance_data[:db_queries]}"
    end
  end

  def track_slow_request(duration)
    slow_request_data = {
      controller: controller_name,
      action: action_name,
      duration: duration,
      params: params.to_unsafe_h.except(:password, :password_confirmation),
      user_id: current_user&.id,
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    }

    Rails.logger.warn "Slow request detected: #{controller_name}##{action_name} took #{duration.round(3)}s"
    Rails.logger.warn "Slow request data: #{slow_request_data.inspect}"

    # Send slow request notification to external services
    # Example: WebhookNotifier.send("Slow request: #{controller_name}##{action_name} - #{duration.round(2)}s")
  end

  def send_performance_metrics(duration)
    # Send metrics to external monitoring services
    # Examples:

    # StatsD
    # if defined?(StatsD)
    #   StatsD.timing("rails.controller.#{controller_name}.#{action_name}", duration * 1000)
    #   StatsD.increment("rails.controller.#{controller_name}.requests")
    # end

    # New Relic
    # if defined?(NewRelic)
    #   NewRelic::Agent.record_metric("Custom/Controller/#{controller_name}/#{action_name}", duration)
    # end

    # Custom metrics endpoint
    # MetricsCollector.record_request_time(controller_name, action_name, duration)
  end

  def track_error_externally(error, context)
    # Send errors to external tracking services
    # Examples:

    # Sentry
    # if defined?(Sentry)
    #   Sentry.capture_exception(error, contexts: { request: context })
    # end

    # Bugsnag
    # if defined?(Bugsnag)
    #   Bugsnag.notify(error, metadata: context)
    # end

    # Airbrake
    # if defined?(Airbrake)
    #   Airbrake.notify(error, context)
    # end

    # Custom error tracking
    # ErrorTracker.track(error, context)
  end

  def should_track_performance?
    # Only track performance for non-health check requests
    !health_check_request? && !asset_request?
  end

  def health_check_request?
    request.path == "/up" || request.path.starts_with?("/health")
  end

  def asset_request?
    request.path.starts_with?("/assets/") ||
    request.path.starts_with?("/packs/") ||
    request.path.match?(/\.(css|js|png|jpg|jpeg|gif|svg|ico|woff|woff2|ttf|eot)$/)
  end

  def slow_request_threshold
    # Configurable threshold for slow requests (in seconds)
    ENV.fetch("SLOW_REQUEST_THRESHOLD", "1.0").to_f
  end

  def current_memory_usage
    # Get current memory usage in bytes
    if defined?(GC)
      GC.stat[:heap_live_slots] * 40 # rough estimate: 40 bytes per object
    else
      0
    end
  end

  # Class methods
  class_methods do
    def track_action_performance(*actions)
      # Track specific actions with detailed monitoring
      around_action :detailed_performance_tracking, only: actions
    end

    def skip_performance_tracking(*actions)
      # Skip performance tracking for specific actions
      skip_around_action :track_performance, only: actions
    end
  end

  private

  def detailed_performance_tracking
    # Enhanced tracking for specific actions
    start_time = Time.current
    gc_stat_before = GC.stat if defined?(GC)

    begin
      yield
    ensure
      end_time = Time.current
      duration = end_time - start_time

      # Detailed GC analysis
      if gc_stat_before && defined?(GC)
        gc_stat_after = GC.stat
        gc_runs = gc_stat_after[:count] - gc_stat_before[:count]

        if gc_runs > 0
          Rails.logger.info "GC Analysis: #{gc_runs} GC runs during #{controller_name}##{action_name}"
        end
      end

      # Log detailed timing
      Rails.logger.info "Detailed timing for #{controller_name}##{action_name}: #{duration.round(6)}s"
    end
  end
end
