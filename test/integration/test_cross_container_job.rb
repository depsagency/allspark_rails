# frozen_string_literal: true

# Test job class specifically for cross-container communication testing
class TestCrossContainerJob < ApplicationJob
  queue_as :target_development

  def perform(message)
    Rails.logger.info "TestCrossContainerJob executed: #{message}"
    
    # Store execution evidence
    Rails.cache.write("cross_container_job_#{message}", {
      message: message,
      executed_at: Time.current.iso8601,
      container_info: {
        hostname: Socket.gethostname,
        pid: Process.pid,
        rails_env: Rails.env,
        container_role: ENV['CONTAINER_ROLE']
      }
    }, expires_in: 30.minutes)
    
    message
  end
end