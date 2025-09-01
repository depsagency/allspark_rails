# frozen_string_literal: true

# Test job class for integration testing
# This job is used to test cross-container Sidekiq communication
class TestJob < ApplicationJob
  queue_as :default

  def perform(data)
    Rails.logger.info "TestJob performed with data: #{data.inspect}"
    
    # Store job execution info for testing
    job_key = "test_job_#{data[:id] || 'unknown'}"
    Rails.cache.write(job_key, {
      executed_at: Time.current,
      data: data,
      worker_info: {
        pid: Process.pid,
        hostname: Socket.gethostname,
        queue: queue_name
      }
    }, expires_in: 1.hour)
    
    true
  end
end