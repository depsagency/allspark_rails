# frozen_string_literal: true

module Agents
  class ErrorMonitor
    include Singleton
    
    attr_reader :errors
    
    def initialize
      @errors = []
      @mutex = Mutex.new
    end
    
    # Record an error
    def record_error(assistant_id:, run_id: nil, error:, context: {})
      error_data = {
        assistant_id: assistant_id,
        run_id: run_id,
        error_class: error.class.name,
        error_message: error.message,
        backtrace: error.backtrace&.first(10),
        context: context,
        timestamp: Time.current
      }
      
      @mutex.synchronize do
        @errors << error_data
        @errors = @errors.last(1000) # Keep last 1000 errors
      end
      
      # Log to Rails logger
      Rails.logger.error "Agent Error: #{error_data.to_json}"
      
      # Could also send to error tracking service (Sentry, etc.)
      notify_error_service(error_data) if defined?(Sentry)
      
      error_data
    end
    
    # Get recent errors
    def recent_errors(limit: 50)
      @mutex.synchronize do
        @errors.last(limit).reverse
      end
    end
    
    # Get errors for a specific assistant
    def errors_for_assistant(assistant_id, limit: 50)
      @mutex.synchronize do
        @errors.select { |e| e[:assistant_id] == assistant_id }.last(limit).reverse
      end
    end
    
    # Get error statistics
    def error_stats
      @mutex.synchronize do
        {
          total_errors: @errors.size,
          errors_by_class: @errors.group_by { |e| e[:error_class] }.transform_values(&:count),
          errors_by_assistant: @errors.group_by { |e| e[:assistant_id] }.transform_values(&:count),
          recent_error_rate: calculate_error_rate
        }
      end
    end
    
    # Clear errors (for testing)
    def clear!
      @mutex.synchronize do
        @errors.clear
      end
    end
    
    private
    
    def calculate_error_rate
      recent = @errors.select { |e| e[:timestamp] > 1.hour.ago }
      return 0 if recent.empty?
      
      (recent.size.to_f / 60).round(2) # Errors per minute
    end
    
    def notify_error_service(error_data)
      # Integration with error tracking service
      Sentry.capture_message(
        "Agent Error: #{error_data[:error_message]}",
        extra: error_data
      )
    rescue => e
      Rails.logger.error "Failed to send to Sentry: #{e.message}"
    end
  end
end