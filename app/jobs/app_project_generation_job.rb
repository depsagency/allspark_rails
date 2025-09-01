class AppProjectGenerationJob < ApplicationJob
  queue_as :default

  def perform(app_project_id, generation_type = "all")
    app_project = AppProject.find(app_project_id)

    case generation_type
    when "all"
      generate_all(app_project)
    when "prd"
      if generate_prd(app_project)
        # Update status back to completed after successful PRD generation
        app_project.update!(status: "completed")
        send_completion_notification(app_project, "PRD")
      end
    when "tasks"
      if generate_tasks(app_project)
        # Update status back to completed after successful tasks generation
        app_project.update!(status: "completed")
        send_completion_notification(app_project, "Tasks")
      end
    when "prompts"
      if generate_prompts(app_project)
        # Update status back to completed after successful prompts generation
        app_project.update!(status: "completed")
        send_completion_notification(app_project, "Prompts")
      end
    when "logo"
      if generate_logo(app_project)
        # Update status back to completed after successful logo generation
        app_project.update!(status: "completed")
        send_completion_notification(app_project, "Logo")
      end
    when "marketing_page"
      if generate_marketing_page(app_project)
        # Update status back to completed after successful marketing page generation
        app_project.update!(status: "completed")
        send_completion_notification(app_project, "Marketing Page")
      end
    when "claude_md"
      if generate_claude_md(app_project)
        # Update status back to completed after successful CLAUDE.md generation
        app_project.update!(status: "completed")
        send_completion_notification(app_project, "CLAUDE.md")
      end
    else
      Rails.logger.error("Unknown generation type: #{generation_type}")
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("AppProject not found: #{app_project_id}")
    raise e
  rescue => e
    Rails.logger.error("Generation failed for AppProject #{app_project_id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))

    # Update project status to indicate failure
    if app_project
      app_project.update!(
        status: "error",
        generation_metadata: app_project.generation_metadata.merge(
          "last_error" => e.message,
          "failed_at" => Time.current.iso8601
        )
      )
    end

    raise e
  end

  private

  def generate_all(app_project)
    # Generate PRD first
    if generate_prd(app_project)
      # Broadcast progress update
      broadcast_progress(app_project, "PRD generated successfully", 20)

      # Generate tasks
      if generate_tasks(app_project)
        broadcast_progress(app_project, "Tasks generated successfully", 40)

        # Generate prompts
        if generate_prompts(app_project)
          broadcast_progress(app_project, "Prompts generated successfully", 60)

          # Generate logo
          if generate_logo(app_project)
            broadcast_progress(app_project, "Logo generated successfully", 80)

            # Generate documentation
            if generate_documentation(app_project)
              broadcast_progress(app_project, "All generations completed!", 100)

              # Send completion notification
              send_completion_notification(app_project)
            else
              # Documentation failure shouldn't fail the whole process
              Rails.logger.warn "Documentation generation failed for AppProject #{app_project.id}, but continuing with completion"
              broadcast_progress(app_project, "Generations completed (documentation partial)", 100)
              send_completion_notification(app_project)
            end
          else
            broadcast_error(app_project, "Failed to generate logo")
          end
        else
          broadcast_error(app_project, "Failed to generate Claude prompts")
        end
      else
        broadcast_error(app_project, "Failed to generate task breakdown")
      end
    else
      broadcast_error(app_project, "Failed to generate PRD")
    end
  end

  def generate_prd(app_project)
    service = Llm::PrdGeneratorService.new(app_project: app_project)
    result = service.generate

    if result
      broadcast_update(app_project, "PRD generation completed")
      # Reload to get updated status from service
      app_project.reload
    else
      # Update status to error if generation failed
      app_project.update!(
        status: "error",
        generation_metadata: app_project.generation_metadata.merge(
          "last_error" => "PRD generation failed",
          "failed_at" => Time.current.iso8601
        )
      )
      broadcast_error(app_project, "Failed to generate PRD")
    end

    result
  end

  def generate_tasks(app_project)
    service = Llm::TaskDecompositionService.new(app_project: app_project)
    result = service.generate

    if result
      broadcast_update(app_project, "Task breakdown completed")
      app_project.reload
    else
      broadcast_error(app_project, "Failed to generate task breakdown")
    end

    result
  end

  def generate_prompts(app_project)
    service = Llm::PromptBuilderService.new(app_project: app_project)
    result = service.generate

    if result
      broadcast_update(app_project, "Claude prompts generated")
      app_project.reload
    else
      broadcast_error(app_project, "Failed to generate Claude prompts")
    end

    result
  end

  def generate_logo(app_project)
    service = Llm::LogoGeneratorService.new(app_project: app_project)
    result = service.generate

    if result
      broadcast_update(app_project, "Logo generated successfully")
      app_project.reload
    else
      broadcast_error(app_project, "Failed to generate logo")
    end

    result
  end

  def generate_marketing_page(app_project)
    service = Llm::MarketingPageGeneratorService.new(app_project: app_project)
    result = service.generate

    if result
      broadcast_update(app_project, "Marketing page generated successfully")
      app_project.reload
    else
      broadcast_error(app_project, "Failed to generate marketing page")
    end

    result
  end

  def generate_claude_md(app_project)
    service = Llm::ClaudeMdGeneratorService.new(app_project)
    result = service.generate

    if result
      broadcast_update(app_project, "CLAUDE.md generated successfully")
      app_project.reload
    else
      broadcast_error(app_project, "Failed to generate CLAUDE.md")
    end

    result
  end

  def generate_documentation(app_project)
    service = AppProjects::DocumentationGeneratorService.new(app_project)
    result = service.generate_and_save

    if result
      broadcast_update(app_project, "Documentation files generated successfully")
      app_project.reload
    else
      broadcast_error(app_project, "Failed to generate documentation files")
    end

    result
  end

  def broadcast_progress(app_project, message, percentage)
    # Broadcast to the project-specific channel
    ActionCable.server.broadcast(
      "app_project_#{app_project.id}",
      {
        type: "progress",
        message: message,
        percentage: percentage,
        status: app_project.status
      }
    )
  end

  def broadcast_update(app_project, message)
    ActionCable.server.broadcast(
      "app_project_#{app_project.id}",
      {
        type: "update",
        message: message,
        status: app_project.status,
        metadata: app_project.generation_metadata
      }
    )
  end

  def broadcast_error(app_project, message)
    ActionCable.server.broadcast(
      "app_project_#{app_project.id}",
      {
        type: "error",
        message: message,
        status: "error"
      }
    )
  end

  def send_completion_notification(app_project, type = nil)
    # Create a notification for the user
    title = case type
    when "PRD"
              "PRD generated successfully!"
    when "Tasks"
              "Task breakdown generated!"
    when "Prompts"
              "Claude prompts generated!"
    when "Logo"
              "Logo generated successfully!"
    when "Marketing Page"
              "Marketing page generated successfully!"
    when "CLAUDE.md"
              "CLAUDE.md documentation generated!"
    else
              "Your app blueprint is ready!"
    end

    message = case type
    when "PRD"
                "The Product Requirements Document for '#{app_project.name}' has been generated successfully."
    when "Tasks"
                "The task breakdown for '#{app_project.name}' has been generated successfully."
    when "Prompts"
                "The Claude prompts for '#{app_project.name}' have been generated successfully."
    when "Logo"
                "The logo for '#{app_project.name}' has been generated successfully."
    when "Marketing Page"
                "The marketing landing page for '#{app_project.name}' has been generated successfully."
    when "CLAUDE.md"
                "The CLAUDE.md documentation for '#{app_project.name}' has been generated successfully."
    else
                "The PRD, task breakdown, Claude prompts, logo, and documentation files for '#{app_project.name}' have been generated successfully. Your complete project documentation is ready for download and implementation."
    end

    Notification.create!(
      user: app_project.user,
      title: title,
      message: message,
      notification_type: "success",
      action_url: Rails.application.routes.url_helpers.app_project_path(app_project),
      metadata: {
        app_project_id: app_project.id,
        generation_type: type,
        generation_completed_at: Time.current.iso8601
      }
    )
  end
end
