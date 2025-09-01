# frozen_string_literal: true

class EasyModeProcessingJob < ApplicationJob
  queue_as :default

  def perform(app_project_id, description)
    app_project = AppProject.find(app_project_id)

    Rails.logger.info "Starting Easy Mode processing job for project: #{app_project.name}"

    begin
      # Create and run the processor service
      processor = Llm::EasyModeProcessorService.new(app_project, description)
      processor.process!

      Rails.logger.info "Easy Mode processing job completed successfully"

      # Optional: Send notification to user if you have notification system
      # UserMailer.easy_mode_complete(app_project).deliver_now

    rescue => e
      Rails.logger.error "Easy Mode processing job failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Update project status to error if not already done
      app_project.update!(
        status: "error",
        generation_metadata: app_project.generation_metadata.merge(
          "easy_mode_job_error" => e.message,
          "easy_mode_job_failed_at" => Time.current.iso8601
        )
      )

      # Re-raise to let Sidekiq handle retry logic
      raise
    end
  end
end
