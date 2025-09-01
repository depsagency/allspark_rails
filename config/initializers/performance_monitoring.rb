# frozen_string_literal: true

# Performance Monitoring and Error Tracking Configuration
#
# This initializer sets up basic performance monitoring and error tracking
# for the Rails application. It provides a foundation that can be extended
# with specific monitoring services like Sentry, Bugsnag, or New Relic.

if Rails.env.production? || Rails.env.staging?

  # Configure Rails built-in error reporting - TEMPORARILY DISABLED TO FIX BOOT LOOP
  # Rails.error.handle(StandardError) do |error, handled:, severity:, context:|
  #   # Log the error with context
  #   Rails.logger.error "Error #{handled ? 'handled' : 'unhandled'}: #{error.class} - #{error.message}"
  #   Rails.logger.error error.backtrace.join("\n") if error.backtrace

  #   # Log context information
  #   if context
  #     Rails.logger.error "Context: #{context.inspect}"
  #   end

    # Here you would integrate with external error tracking services:
    # Sentry.capture_exception(error, contexts: context)
    # Bugsnag.notify(error, metadata: context)
    # Airbrake.notify(error, context)
  # end

  # Subscribe to Rails notifications for performance monitoring
  ActiveSupport::Notifications.subscribe "process_action.action_controller" do |name, started, finished, unique_id, data|
    duration = finished - started

    # Log slow requests
    if duration > 1.0 # requests taking longer than 1 second
      Rails.logger.warn "Slow request detected: #{data[:controller]}##{data[:action]} took #{duration.round(2)}s"
      Rails.logger.warn "Parameters: #{data[:params].inspect}" if data[:params]
      Rails.logger.warn "SQL queries: #{data[:db_runtime]&.round(2)}ms" if data[:db_runtime]
      Rails.logger.warn "View rendering: #{data[:view_runtime]&.round(2)}ms" if data[:view_runtime]
    end

    # Here you would send metrics to monitoring services:
    # StatsD.timing("rails.request_duration", duration * 1000)
    # NewRelic::Agent.record_metric("Custom/RequestDuration", duration)
  end

  # Subscribe to Active Record notifications
  ActiveSupport::Notifications.subscribe "sql.active_record" do |name, started, finished, unique_id, data|
    duration = finished - started

    # Log slow database queries
    if duration > 0.5 # queries taking longer than 500ms
      Rails.logger.warn "Slow query detected: #{data[:sql]} took #{duration.round(3)}s"
      Rails.logger.warn "Query name: #{data[:name]}" if data[:name]
    end

    # Here you would send database metrics to monitoring services:
    # StatsD.timing("rails.db_query_duration", duration * 1000)
  end

  # Subscribe to cache notifications
  ActiveSupport::Notifications.subscribe /cache/ do |name, started, finished, unique_id, data|
    duration = finished - started

    case name
    when "cache_read.active_support"
      # Track cache hit/miss rates
      if data[:hit]
        Rails.logger.debug "Cache hit: #{data[:key]}"
      else
        Rails.logger.debug "Cache miss: #{data[:key]}"
      end
    when "cache_write.active_support"
      Rails.logger.debug "Cache write: #{data[:key]}"
    end

    # Here you would send cache metrics to monitoring services:
    # StatsD.increment("rails.cache.#{name.split('.').first}")
  end

  # Monitor job performance
  ActiveSupport::Notifications.subscribe "perform.active_job" do |name, started, finished, unique_id, data|
    duration = finished - started
    job_name = data[:job].class.name

    # Log slow jobs
    if duration > 30 # jobs taking longer than 30 seconds
      Rails.logger.warn "Slow job detected: #{job_name} took #{duration.round(2)}s"
      Rails.logger.warn "Job arguments: #{data[:job].arguments.inspect}"
    end

    # Here you would send job metrics to monitoring services:
    # StatsD.timing("rails.job_duration.#{job_name.underscore}", duration * 1000)
  end

end

# Development and test environment monitoring - TEMPORARILY DISABLED TO FIX BOOT LOOP
# if Rails.env.development?

#   # Memory usage monitoring in development
#   ActiveSupport::Notifications.subscribe "process_action.action_controller" do |name, started, finished, unique_id, data|
#     # Log memory usage for development debugging
#     if defined?(GC) && GC.respond_to?(:stat)
#       gc_stats = GC.stat
#       Rails.logger.debug "GC Stats - Objects: #{gc_stats[:heap_live_slots]}, GC Runs: #{gc_stats[:count]}"
#     end
#   end

#   # N+1 query detection (requires bullet gem)
#   if defined?(Bullet)
#     Rails.logger.info "Bullet gem is configured for N+1 query detection"
#   end

# end

# Error tracking service integration examples:
#
# For Sentry:
# if Rails.env.production?
#   Sentry.init do |config|
#     config.dsn = ENV['SENTRY_DSN']
#     config.breadcrumbs_logger = [:active_support_logger, :http_logger]
#     config.traces_sample_rate = 0.1
#   end
# end
#
# For Bugsnag:
# if Rails.env.production?
#   Bugsnag.configure do |config|
#     config.api_key = ENV['BUGSNAG_API_KEY']
#     config.release_stage = Rails.env
#   end
# end
#
# For Airbrake:
# if Rails.env.production?
#   Airbrake.configure do |config|
#     config.project_id = ENV['AIRBRAKE_PROJECT_ID']
#     config.project_key = ENV['AIRBRAKE_PROJECT_KEY']
#     config.environment = Rails.env
#   end
# end
