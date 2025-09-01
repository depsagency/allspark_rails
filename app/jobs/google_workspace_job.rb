# frozen_string_literal: true

# Base job class for Google Workspace operations
#
# Provides common functionality for Google Workspace jobs including:
# - Error handling
# - Progress tracking
# - Retry logic
# - Logging
#
class GoogleWorkspaceJob < ApplicationJob
  queue_as :google_workspace

  retry_on GoogleWorkspaceIntegration::RateLimitError, wait: :exponentially_longer, attempts: 5
  retry_on GoogleWorkspaceIntegration::GoogleWorkspaceError, wait: 30.seconds, attempts: 3

  discard_on GoogleWorkspaceIntegration::AuthenticationError do |job, error|
    Rails.logger.error "Google Workspace authentication failed for job #{job.class}: #{error.message}"
    # Could notify administrators here
  end

  private

  # Execute operation with progress tracking
  #
  # @param operation_name [String] Name of the operation for tracking
  # @param total_items [Integer] Total number of items to process
  # @yield [progress] Block to execute with progress tracking
  def execute_with_progress(operation_name, total_items = 1)
    progress_data = {
      operation: operation_name,
      total: total_items,
      completed: 0,
      started_at: Time.current,
      errors: []
    }

    broadcast_progress(progress_data)

    begin
      yield progress_data

      progress_data[:completed_at] = Time.current
      progress_data[:status] = "completed"
      broadcast_progress(progress_data)

    rescue => error
      progress_data[:status] = "failed"
      progress_data[:error] = error.message
      progress_data[:failed_at] = Time.current
      broadcast_progress(progress_data)

      raise error
    end
  end

  # Update and broadcast progress
  #
  # @param progress_data [Hash] Progress information
  def update_progress(progress_data, increment: 1)
    progress_data[:completed] += increment
    progress_data[:percentage] = ((progress_data[:completed].to_f / progress_data[:total]) * 100).round(2)

    broadcast_progress(progress_data)
  end

  # Broadcast progress update via ActionCable
  #
  # @param progress_data [Hash] Progress information
  def broadcast_progress(progress_data)
    # Broadcast to GoogleWorkspaceChannel if available
    if defined?(GoogleWorkspaceChannel)
      ActionCable.server.broadcast(
        "google_workspace_#{job_id}",
        {
          type: "progress_update",
          job_id: job_id,
          data: progress_data
        }
      )
    end

    # Log progress
    Rails.logger.info "Google Workspace Job Progress: #{progress_data}"
  end

  # Add error to progress tracking
  #
  # @param progress_data [Hash] Progress information
  # @param error_message [String] Error message
  def add_error(progress_data, error_message)
    progress_data[:errors] << {
      message: error_message,
      timestamp: Time.current
    }
  end

  # Get job ID for tracking
  def job_id
    @job_id ||= job_id.presence || SecureRandom.uuid
  end
end
