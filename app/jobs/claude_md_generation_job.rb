# frozen_string_literal: true

# Background job for generating project-specific CLAUDE.md files
#
# This job processes CLAUDE.md generation requests asynchronously
# to avoid blocking the web interface during LLM API calls.
#
class ClaudeMdGenerationJob < ApplicationJob
  queue_as :default

  # Retry configuration
  discard_on ActiveRecord::RecordNotFound

  def perform(app_project)
    Rails.logger.info "Starting CLAUDE.md generation for app_project: #{app_project.id}"

    # Verify prerequisites
    unless app_project.claude_md_ready_for_generation?
      Rails.logger.error "App project #{app_project.id} not ready for CLAUDE.md generation"
      return
    end

    begin
      # Initialize the generator service
      service = Llm::ClaudeMdGeneratorService.new(app_project)

      # Generate the CLAUDE.md content
      result = service.generate

      if result
        Rails.logger.info "CLAUDE.md generation completed successfully for app_project: #{app_project.id}"

        # Update project status back to completed after successful CLAUDE.md generation
        app_project.update!(status: "completed")
      else
        Rails.logger.error "CLAUDE.md generation failed for app_project #{app_project.id}"

        # Update app project status if it was generating
        if app_project.generating?
          app_project.update!(status: "error")
        end
      end

    rescue => e
      Rails.logger.error "ClaudeMdGenerationJob failed for app_project #{app_project.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Update app project status
      if app_project.generating?
        app_project.update!(status: :error)
      end

      # Re-raise to trigger retry mechanism
      raise e
    end
  end
end
