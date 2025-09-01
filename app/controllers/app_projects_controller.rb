# frozen_string_literal: true

class AppProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin
  before_action :set_app_project, only: [ :show, :edit, :update, :destroy, :generate_prd, :generate_all, :generate_tasks, :generate_prompts, :generate_logo, :generate_marketing_page, :generate_claude_md, :status, :regenerate, :export, :context, :serialize_output, :documentation_status, :view_documentation, :download_file, :replace_claude_md ]

  # GET /app_projects
  def index
    @app_projects = current_user.app_projects.by_completion
    @recent_projects = @app_projects.limit(5)
    @stats = {
      total: @app_projects.count,
      completed: @app_projects.completed_projects.count,
      in_progress: @app_projects.where.not(status: [ :completed, :error ]).count
    }
  end

  # GET /app_projects/:id
  def show
    @completion_percentage = @app_project.completion_percentage
    @can_generate = @app_project.can_generate?
    @ai_generations = @app_project.ai_generations.recent.limit(10)
  end

  # GET /app_projects/new
  def new
    @app_project = current_user.app_projects.build
  end

  # GET /app_projects/:id/edit
  def edit
  end

  # POST /app_projects
  def create
    @app_project = current_user.app_projects.build(app_project_params)

    if @app_project.save
      redirect_to @app_project, notice: "Project created successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /app_projects/:id
  def update
    if @app_project.update(app_project_params)
      respond_to do |format|
        format.html { redirect_to @app_project, notice: "Project updated successfully!" }
        format.json { render json: {
          status: "success",
          completion_percentage: @app_project.completion_percentage,
          can_generate: @app_project.can_generate?
        }}
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { status: "error", errors: @app_project.errors } }
      end
    end
  end

  # DELETE /app_projects/:id
  def destroy
    if @app_project.nil?
      redirect_to app_projects_url, alert: "Project not found."
      return
    end
    
    project_name = @app_project.name
    
    if @app_project.destroy
      redirect_to app_projects_url, notice: "Project '#{project_name}' was successfully deleted."
    else
      redirect_to edit_app_project_path(@app_project), alert: "Unable to delete project. Please try again."
    end
  end

  # GET /app_projects/wizard
  def wizard
    @app_project = current_user.app_projects.find_by(slug: params[:project_slug]) if params[:project_slug]
    @app_project ||= current_user.app_projects.build

    # If new project and no easy mode bypass, redirect to easy mode
    if !@app_project.persisted? && params[:skip_easy_mode] != "true"
      redirect_to wizard_easy_mode_app_projects_path
      return
    end

    # Determine the current step - either from params or find next incomplete question
    @current_step = params[:step]&.to_i || find_next_incomplete_step(@app_project)
    @current_step = [ @current_step, 1 ].max
    @current_step = [ @current_step, 10 ].min

    @questions = wizard_questions
    @current_question = @questions[@current_step - 1]
  end

  # GET /app_projects/wizard/easy_mode
  def easy_mode
    @app_project = current_user.app_projects.build
  end

  # POST /app_projects/wizard/process_easy_mode
  def process_easy_mode
    @app_project = current_user.app_projects.build(name: params[:app_project][:name])

    if @app_project.save
      # Queue the Easy Mode processing job
      EasyModeProcessingJob.perform_later(@app_project.id, params[:app_project][:description])

      # Update project status
      @app_project.update!(
        status: "generating",
        generation_metadata: @app_project.generation_metadata.merge(
          "easy_mode_started_at" => Time.current.iso8601,
          "easy_mode" => true
        )
      )

      redirect_to @app_project, notice: "Processing your project description with AI... This may take a moment."
    else
      render :easy_mode, status: :unprocessable_entity
    end
  end

  # POST /app_projects/wizard
  def create_from_wizard
    @app_project = current_user.app_projects.find_by(slug: params[:project_slug]) if params[:project_slug]

    if @app_project
      if @app_project.update(app_project_params)
        handle_wizard_step_complete
      else
        render :wizard, status: :unprocessable_entity
      end
    else
      @app_project = current_user.app_projects.build(app_project_params)
      if @app_project.save
        handle_wizard_step_complete
      else
        render :wizard, status: :unprocessable_entity
      end
    end
  end

  # POST /app_projects/:id/generate_prd
  def generate_prd
    unless @app_project.ready_for_generation?
      redirect_to @app_project, alert: "Project needs at least 70% completion before generating PRD."
      return
    end

    # Queue the PRD generation job
    AppProjectGenerationJob.perform_later(@app_project.id, "prd")

    # Update project status
    @app_project.update!(
      status: "generating",
      generation_metadata: @app_project.generation_metadata.merge(
        "generation_started_at" => Time.current.iso8601
      )
    )

    redirect_to @app_project, notice: "PRD generation started! You will be notified when complete."
  end

  # POST /app_projects/:id/generate_all
  def generate_all
    unless @app_project.ready_for_generation?
      redirect_to @app_project, alert: "Project needs at least 70% completion before generating outputs."
      return
    end

    # Queue the full generation job
    AppProjectGenerationJob.perform_later(@app_project.id, "all")

    # Update project status
    @app_project.update!(
      status: "generating",
      generation_metadata: @app_project.generation_metadata.merge(
        "generation_started_at" => Time.current.iso8601
      )
    )

    redirect_to @app_project, notice: "Full generation started! You will be notified when complete."
  end

  # POST /app_projects/:id/generate_tasks
  def generate_tasks
    unless @app_project.generated_prd.present?
      redirect_to @app_project, alert: "PRD must be generated before generating tasks."
      return
    end

    # Queue the tasks generation job
    AppProjectGenerationJob.perform_later(@app_project.id, "tasks")

    # Update project status
    @app_project.update!(
      status: "generating",
      generation_metadata: @app_project.generation_metadata.merge(
        "generation_started_at" => Time.current.iso8601
      )
    )

    redirect_to @app_project, notice: "Task generation started! You will be notified when complete."
  end

  # POST /app_projects/:id/generate_prompts
  def generate_prompts
    unless @app_project.generated_prd.present? && @app_project.generated_tasks.present?
      redirect_to @app_project, alert: "PRD and tasks must be generated before generating prompts."
      return
    end

    # Queue the prompts generation job
    AppProjectGenerationJob.perform_later(@app_project.id, "prompts")

    # Update project status
    @app_project.update!(
      status: "generating",
      generation_metadata: @app_project.generation_metadata.merge(
        "generation_started_at" => Time.current.iso8601
      )
    )

    redirect_to @app_project, notice: "Prompt generation started! You will be notified when complete."
  end

  # POST /app_projects/:id/generate_logo
  def generate_logo
    unless @app_project.logo_ready_for_generation?
      redirect_to @app_project, alert: "PRD must be generated before creating a logo."
      return
    end

    # Queue the logo generation job
    AppProjectGenerationJob.perform_later(@app_project.id, "logo")

    # Update project status
    @app_project.update!(
      status: "generating",
      generation_metadata: @app_project.generation_metadata.merge(
        "generation_started_at" => Time.current.iso8601
      )
    )

    redirect_to @app_project, notice: "Logo generation started! You will be notified when complete."
  end

  # POST /app_projects/:id/generate_marketing_page
  def generate_marketing_page
    unless @app_project.marketing_page_ready_for_generation?
      redirect_to @app_project, alert: "PRD must be generated before creating a marketing page."
      return
    end

    # Queue the marketing page generation job
    AppProjectGenerationJob.perform_later(@app_project.id, "marketing_page")

    # Update project status
    @app_project.update!(
      status: "generating",
      generation_metadata: @app_project.generation_metadata.merge(
        "generation_started_at" => Time.current.iso8601
      )
    )

    redirect_to @app_project, notice: "Marketing page generation started! You will be notified when complete."
  end

  # POST /app_projects/:id/generate_claude_md
  def generate_claude_md
    unless @app_project.claude_md_ready_for_generation?
      redirect_to @app_project, alert: "PRD and tasks must be generated before creating a CLAUDE.md file."
      return
    end

    # Queue the CLAUDE.md generation job
    AppProjectGenerationJob.perform_later(@app_project.id, "claude_md")

    # Update project status
    @app_project.update!(
      status: "generating",
      generation_metadata: @app_project.generation_metadata.merge(
        "generation_started_at" => Time.current.iso8601
      )
    )

    redirect_to @app_project, notice: "CLAUDE.md generation started! You will be notified when complete."
  end

  # POST /app_projects/:id/replace_claude_md
  def replace_claude_md
    Rails.logger.info "replace_claude_md called for project #{@app_project.slug}"

    unless @app_project.generated_claude_md.present?
      Rails.logger.warn "No generated CLAUDE.md found for project #{@app_project.slug}"
      redirect_to @app_project, alert: "CLAUDE.md must be generated before it can be replaced."
      return
    end

    begin
      # Path to the root CLAUDE.md file
      claude_md_path = Rails.root.join("CLAUDE.md")
      backup_path = nil

      Rails.logger.info "Attempting to replace #{claude_md_path}"

      # Back up existing CLAUDE.md if it exists
      if File.exist?(claude_md_path)
        backup_path = Rails.root.join("CLAUDE.md.backup-#{Time.current.strftime('%Y%m%d-%H%M%S')}")
        FileUtils.cp(claude_md_path, backup_path)
        Rails.logger.info "Backup created at #{backup_path}"
      end

      # Write the generated CLAUDE.md content to the root file
      File.write(claude_md_path, @app_project.generated_claude_md)
      Rails.logger.info "CLAUDE.md file replaced successfully"

      # Update project metadata to track the replacement
      @app_project.update!(
        generation_metadata: @app_project.generation_metadata.merge(
          "claude_md_replaced_at" => Time.current.iso8601,
          "claude_md_backup_created" => backup_path&.to_s
        )
      )

      redirect_to @app_project, notice: 'Successfully replaced the root CLAUDE.md file! This app is now configured for "' + @app_project.name + '".'
    rescue => e
      Rails.logger.error "Failed to replace CLAUDE.md: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to @app_project, alert: "Failed to replace CLAUDE.md file. Please check file permissions."
    end
  end

  # GET /app_projects/:id/status
  def status
    render json: {
      status: @app_project.status,
      completion_percentage: @app_project.completion_percentage,
      can_generate: @app_project.can_generate?,
      has_outputs: @app_project.has_ai_outputs?,
      has_logo: @app_project.has_logo?,
      logo_ready_for_generation: @app_project.logo_ready_for_generation?,
      has_marketing_page: @app_project.has_marketing_page?,
      marketing_page_ready_for_generation: @app_project.marketing_page_ready_for_generation?,
      has_claude_md: @app_project.generated_claude_md.present?,
      claude_md_ready_for_generation: @app_project.claude_md_ready_for_generation?,
      generation_status: @app_project.generation_status_summary,
      last_generation: @app_project.last_generation_at
    }
  end

  # GET /app_projects/:id/context
  def context
    # Build comprehensive context for AI coding assistants
    context_content = build_project_context(@app_project)

    render json: {
      context: context_content,
      project_name: @app_project.name,
      status: @app_project.status,
      completion: @app_project.completion_percentage
    }
  end

  # POST /app_projects/:id/regenerate
  def regenerate
    # Queue the regeneration job
    AppProjectGenerationJob.perform_later(@app_project.id, "all")

    # Update project status
    @app_project.update!(
      status: "generating",
      generation_metadata: @app_project.generation_metadata.merge(
        "regeneration_started_at" => Time.current.iso8601
      )
    )

    render json: { status: "success", message: "Regeneration started!" }
  end

  # GET /app_projects/:id/export/:format
  def export
    case params[:format]
    when "prd"
      export_prd
    when "tasks"
      export_tasks
    when "prompt"
      export_claude_prompt
    when "claude_md"
      export_claude_md
    when "json"
      export_json
    when "zip"
      export_zip
    else
      redirect_to @app_project, alert: "Invalid export format requested."
    end
  end

  # POST /app_projects/:id/serialize_output
  def serialize_output
    output_type = params[:output_type]&.to_sym
    force = params[:force] == "true"

    unless AppProjects::DocumentationGeneratorService::OUTPUT_TYPES.include?(output_type)
      render json: { status: "error", message: "Invalid output type" }, status: :bad_request
      return
    end

    service = AppProjects::DocumentationGeneratorService.new(@app_project)

    case output_type
    when :prd
      result = service.serialize_prd(force: force)
    when :tasks
      result = service.serialize_tasks(force: force)
    when :user_input
      result = service.serialize_user_input(force: force)
    when :claude_context
      result = service.serialize_claude_context(force: force)
    when :claude_prompts
      result = service.serialize_claude_prompts(force: force)
    when :logo_data
      result = service.serialize_logo_data(force: force)
    when :marketing_page
      result = service.serialize_marketing_page(force: force)
    when :all
      result = service.serialize_all(force: force)
    else
      result = service.generate_and_save(only: [ output_type ], force: force)
    end

    if result
      render json: {
        status: "success",
        message: "#{output_type.to_s.humanize} serialized successfully",
        serialized_at: Time.current.iso8601
      }
    else
      render json: {
        status: "error",
        message: "Failed to serialize #{output_type.to_s.humanize}"
      }, status: :unprocessable_entity
    end
  end

  # GET /app_projects/:id/documentation_status
  def documentation_status
    service = AppProjects::DocumentationGeneratorService.new(@app_project)
    status = service.documentation_status

    render json: {
      status: "success",
      documentation_status: status,
      project_id: @app_project.id
    }
  end

  # GET /app_projects/:id/view_documentation
  def view_documentation
    service = AppProjects::DocumentationGeneratorService.new(@app_project)
    @documentation_status = service.documentation_status
    @project_dir = Rails.root.join("docs/app-projects/generated/#{@app_project.id}")
  end

  # GET /app_projects/import
  def import_index
    @available_projects = AppProjects::ImporterService.list_available_projects
    @importable_count = @available_projects.count { |p| p[:can_import] }
    @error_count = @available_projects.count { |p| !p[:can_import] }
  end

  # GET /app_projects/import/:project_folder_id/preview
  def import_preview
    project_folder_id = params[:project_folder_id]

    begin
      importer = AppProjects::ImporterService.new(project_folder_id, current_user: current_user)
      @preview_data = importer.preview
    rescue AppProjects::ImporterService::ImportError => e
      @preview_data = {
        project_id: project_folder_id,
        project_name: "Error",
        can_import: false,
        error: e.message
      }
    end

    render json: @preview_data
  end

  # POST /app_projects/import/:project_folder_id
  def import_execute
    project_folder_id = params[:project_folder_id]
    overwrite_existing = params[:overwrite_existing] == "true"

    begin
      importer = AppProjects::ImporterService.new(
        project_folder_id,
        current_user: current_user,
        options: { overwrite_existing: overwrite_existing }
      )

      @imported_project = importer.import!

      render json: {
        status: "success",
        message: "Successfully imported project '#{@imported_project.name}'",
        project: {
          id: @imported_project.slug,
          name: @imported_project.name,
          url: app_project_path(@imported_project)
        }
      }
    rescue AppProjects::ImporterService::ImportError => e
      render json: {
        status: "error",
        message: e.message
      }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error "Unexpected error during import: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      render json: {
        status: "error",
        message: "An unexpected error occurred during import. Please try again."
      }, status: :internal_server_error
    end
  end

  # GET /app_projects/:id/download_file/:file_type
  def download_file
    file_type = params[:file_type]&.to_sym
    service = AppProjects::DocumentationGeneratorService.new(@app_project)

    unless AppProjects::DocumentationGeneratorService::OUTPUT_TYPES.include?(file_type)
      redirect_to @app_project, alert: "Invalid file type requested."
      return
    end

    file_path = service.send(:file_path_for_type, file_type)

    unless File.exist?(file_path)
      redirect_to @app_project, alert: "File not found. Please serialize the output first."
      return
    end

    filename = case file_type
    when :prd
                 "#{@app_project.slug}-prd.md"
    when :tasks
                 "#{@app_project.slug}-tasks.md"
    when :user_input
                 "#{@app_project.slug}-user-input.md"
    when :claude_context
                 "#{@app_project.slug}-claude-context.md"
    when :claude_prompts
                 "#{@app_project.slug}-claude-prompts.md"
    when :logo_data
                 extension = service.send(:detect_logo_extension)
                 "#{@app_project.slug}-logo.#{extension}"
    when :marketing_page
                 "#{@app_project.slug}-marketing-page.md"
    when :metadata
                 "#{@app_project.slug}-metadata.json"
    else
                 "#{@app_project.slug}-#{file_type}.md"
    end

    content_type = case file_type
    when :metadata
                     "application/json"
    when :logo_data
                     extension = service.send(:detect_logo_extension)
                     case extension
                     when "png"
                       "image/png"
                     when "jpg", "jpeg"
                       "image/jpeg"
                     when "gif"
                       "image/gif"
                     when "webp"
                       "image/webp"
                     else
                       "image/png"
                     end
    else
                     "text/markdown"
    end

    send_file file_path,
              filename: filename,
              type: content_type,
              disposition: "attachment"
  end

  private

  def set_app_project
    @app_project = current_user.app_projects.find_by!(slug: params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to app_projects_path, alert: "Project not found."
  end

  def ensure_admin
    unless current_user&.admin?
      redirect_to root_path, alert: "Access denied. Admin privileges required."
    end
  end

  def app_project_params
    params.require(:app_project).permit(
      :name, :status, :vision_response, :users_response, :journeys_response, :features_response,
      :technical_response, :integrations_response, :success_response, :competition_response,
      :design_response, :challenges_response, :generated_prd, :generated_tasks,
      :generated_claude_prompt, :generated_claude_md
    )
  end

  def wizard_questions
    [
      {
        title: "Application Vision",
        prompt: "Describe your application idea in detail. What problem does it solve and for whom?",
        field: :vision_response,
        placeholder: "I want to build a marketplace for freelance designers...",
        example: "Example: A platform connecting freelance UX designers with small businesses that need affordable design help."
      },
      {
        title: "Target Users",
        prompt: "Who are your users? Describe the different types of people who will use your application.",
        field: :users_response,
        placeholder: "My target users include...",
        example: "Example: Small business owners (25-45, tech-savvy, budget-conscious) and freelance designers (22-35, portfolio-focused)."
      },
      {
        title: "User Journeys",
        prompt: "Walk me through the key user journeys. How do your users interact with your application from start to finish?",
        field: :journeys_response,
        placeholder: "Users start by...",
        example: "Example: Business owners post projects → Designers submit proposals → Clients review and select → Project collaboration begins."
      },
      {
        title: "Core Features",
        prompt: "What are the core features and functionality your application needs?",
        field: :features_response,
        placeholder: "Essential features include...",
        example: "Example: User profiles, project posting, portfolio galleries, messaging system, payment processing, rating system."
      },
      {
        title: "Technical Requirements",
        prompt: "Describe your technical requirements and constraints.",
        field: :technical_response,
        placeholder: "Platform needs include...",
        example: "Example: Web-first responsive design, real-time messaging, file upload capabilities, mobile-optimized interface."
      },
      {
        title: "Third-party Integrations",
        prompt: "What third-party services do you need to integrate with?",
        field: :integrations_response,
        placeholder: "I need to integrate with...",
        example: "Example: Stripe for payments, SendGrid for emails, AWS S3 for file storage, Google Analytics for tracking."
      },
      {
        title: "Success Metrics",
        prompt: "What does success look like for your application? How will you measure it?",
        field: :success_response,
        placeholder: "Success will be measured by...",
        example: "Example: 1000+ active users within 6 months, $10K monthly transaction volume, 4.5+ star user rating."
      },
      {
        title: "Competition Analysis",
        prompt: "Are there any existing solutions or competitors? How is your application different?",
        field: :competition_response,
        placeholder: "Existing solutions include...",
        example: "Example: Upwork and Fiverr exist but focus on broader services. We specialize in UX/UI design with better matching."
      },
      {
        title: "Design Requirements",
        prompt: "Describe any specific design or user experience requirements.",
        field: :design_response,
        placeholder: "Design requirements include...",
        example: "Example: Clean, modern interface. Portfolio-focused layouts. Mobile-first approach. Accessibility compliant."
      },
      {
        title: "Challenges & Concerns",
        prompt: "What are your biggest concerns or potential challenges for this project?",
        field: :challenges_response,
        placeholder: "My main concerns are...",
        example: "Example: User acquisition, payment processing complexity, quality control for designers, mobile responsiveness."
      }
    ]
  end

  def handle_wizard_step_complete
    step = params[:step]&.to_i || 1

    if step >= 10
      redirect_to @app_project, notice: "Questionnaire completed! You can now generate your PRD."
    else
      next_step = step + 1
      redirect_to wizard_app_projects_path(project_slug: @app_project.slug, step: next_step)
    end
  end

  def export_prd
    return redirect_to(@app_project, alert: "PRD not yet generated.") unless @app_project.generated_prd.present?

    filename = "#{@app_project.slug}-prd.md"
    send_data @app_project.generated_prd,
              filename: filename,
              type: "text/markdown",
              disposition: "attachment"
  end

  def export_tasks
    return redirect_to(@app_project, alert: "Task list not yet generated.") unless @app_project.generated_tasks.present?

    filename = "#{@app_project.slug}-tasks.md"
    send_data @app_project.generated_tasks,
              filename: filename,
              type: "text/markdown",
              disposition: "attachment"
  end

  def export_claude_prompt
    return redirect_to(@app_project, alert: "Claude prompt not yet generated.") unless @app_project.generated_claude_prompt.present?

    filename = "#{@app_project.slug}-claude-prompt.md"
    send_data @app_project.generated_claude_prompt,
              filename: filename,
              type: "text/markdown",
              disposition: "attachment"
  end

  def export_claude_md
    return redirect_to(@app_project, alert: "CLAUDE.md not yet generated.") unless @app_project.generated_claude_md.present?

    filename = "#{@app_project.slug}-CLAUDE.md"
    send_data @app_project.generated_claude_md,
              filename: filename,
              type: "text/markdown",
              disposition: "attachment"
  end

  def export_json
    data = {
      project: @app_project.as_json(except: [ :id, :user_id ]),
      responses: @app_project.all_responses,
      metadata: {
        completion_percentage: @app_project.completion_percentage,
        generated_at: Time.current,
        version: "1.0"
      }
    }

    filename = "#{@app_project.slug}-project-data.json"
    send_data data.to_json,
              filename: filename,
              type: "application/json",
              disposition: "attachment"
  end

  def export_zip
    require "zip"

    temp_file = Tempfile.new([ "#{@app_project.slug}-complete", ".zip" ])

    begin
      Zip::File.open(temp_file.path, Zip::File::CREATE) do |zipfile|
        # Add PRD if present
        if @app_project.generated_prd.present?
          zipfile.get_output_stream("#{@app_project.slug}-prd.md") do |f|
            f.write @app_project.generated_prd
          end
        end

        # Add tasks if present
        if @app_project.generated_tasks.present?
          zipfile.get_output_stream("#{@app_project.slug}-tasks.md") do |f|
            f.write @app_project.generated_tasks
          end
        end

        # Add Claude prompts if present
        if @app_project.generated_claude_prompt.present?
          zipfile.get_output_stream("#{@app_project.slug}-claude-prompts.md") do |f|
            f.write @app_project.generated_claude_prompt
          end
        end

        # Add CLAUDE.md if present
        if @app_project.generated_claude_md.present?
          zipfile.get_output_stream("#{@app_project.slug}-CLAUDE.md") do |f|
            f.write @app_project.generated_claude_md
          end
        end

        # Add project data as JSON
        project_data = {
          project: @app_project.as_json(except: [ :id, :user_id ]),
          responses: @app_project.all_responses,
          generation_metadata: @app_project.generation_metadata,
          metadata: {
            completion_percentage: @app_project.completion_percentage,
            export_date: Time.current.iso8601,
            version: "1.0"
          }
        }

        zipfile.get_output_stream("#{@app_project.slug}-project-data.json") do |f|
          f.write JSON.pretty_generate(project_data)
        end

        # Add README with instructions
        readme_content = generate_readme_content
        zipfile.get_output_stream("README.md") do |f|
          f.write readme_content
        end
      end

      zip_data = File.read(temp_file.path)
      send_data zip_data,
                filename: "#{@app_project.slug}-complete-export.zip",
                type: "application/zip",
                disposition: "attachment"
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  def generate_readme_content
    <<~README
      # #{@app_project.name} - AI Generated App Blueprint

      This export contains all the generated materials for your application project.

      ## Contents

      ### 📋 Product Requirements Document (PRD)
      **File:** `#{@app_project.slug}-prd.md`

      Comprehensive 15-section PRD including:
      - Executive Summary
      - Vision and Objectives#{'  '}
      - Target Users and Personas
      - User Journeys and Workflows
      - Functional Requirements
      - Technical Requirements
      - And 9 additional sections...

      ### 📝 Development Task List
      **File:** `#{@app_project.slug}-tasks.md`

      Phased development breakdown with:
      - 6 implementation phases
      - Task dependencies and priorities
      - Time estimates
      - Technical considerations

      ### 🤖 AI Implementation Prompts
      **File:** `#{@app_project.slug}-claude-prompts.md`

      Ready-to-use prompts for AI coding assistants including:
      - Setup and architecture guidance
      - Feature implementation prompts
      - Testing and deployment instructions

      ### 📄 CLAUDE.md Documentation
      **File:** `#{@app_project.slug}-CLAUDE.md`

      Project-specific documentation for AI coding assistants including:
      - Application architecture and tech stack
      - Key features and components
      - Development workflow and implementation guide
      - Database schema and API endpoints
      - Testing strategy and deployment notes

      ### 📊 Project Data
      **File:** `#{@app_project.slug}-project-data.json`

      Complete project metadata including:
      - Your questionnaire responses
      - Generation metadata and costs
      - Project completion status

      ## Getting Started

      1. **Review the PRD** to understand the full scope and requirements
      2. **Use the task list** to plan your development phases
      3. **Copy prompts** into your AI coding assistant to start implementation

      ## Generation Details

      - **Project:** #{@app_project.name}
      - **Completion:** #{@app_project.completion_percentage}%
      - **Status:** #{@app_project.status.humanize}
      - **Generated:** #{Time.current.strftime("%B %d, %Y at %I:%M %p")}
      - **Cost:** $#{'%.4f' % @app_project.generation_cost}

      ---

      Generated with the AI-Powered Application Blueprint Generator
      Built with Rails 8.0 + AI-Powered Development
    README
  end

  # Find the next incomplete step for continuing the wizard
  def find_next_incomplete_step(app_project)
    return 1 unless app_project.persisted?

    # Check each response field to find the first empty one
    AppProject::RESPONSE_FIELDS.each_with_index do |field, index|
      return index + 1 if app_project.send(field).blank?
    end

    # If all are completed, go to the last step for review
    10
  end

  # Helper method to parse task sections from generated content
  def parse_task_sections(content)
    return [] if content.blank?

    sections = []
    current_section = nil

    content.split("\n").each do |line|
      # Match phase headers
      if line.match(/^###?\s*Phase\s*(\d+):\s*(.+)/)
        if current_section
          sections << current_section
        end
        current_section = {
          title: line.strip,
          tasks: [],
          estimated_hours: 0
        }
      elsif line.match(/TASK-(\d+)/)
        # Extract task information
        task_match = line.match(/TASK-(\d+):\s*(.+)/)
        if task_match && current_section
          task = {
            id: "TASK-#{task_match[1]}",
            title: task_match[2],
            description: nil,
            priority: nil,
            hours: nil,
            dependencies: [],
            technical_notes: nil
          }
          current_section[:tasks] << task
        end
      end
    end

    # Add the last section
    if current_section
      sections << current_section
    end

    # Default sections if parsing fails
    if sections.empty?
      [
        {
          title: "Phase 1: Foundation & Setup",
          tasks: [],
          estimated_hours: 0
        },
        {
          title: "Phase 2: Core Infrastructure",
          tasks: [],
          estimated_hours: 0
        },
        {
          title: "Phase 3: Feature Development",
          tasks: [],
          estimated_hours: 0
        }
      ]
    else
      sections
    end
  end

  helper_method :parse_task_sections

  def build_project_context(app_project)
    context_parts = []

    # Project header
    context_parts << "# #{app_project.name} - Project Context for AI Development"
    context_parts << ""
    context_parts << "This project was created using an AI-powered application blueprint generator."
    context_parts << "Status: #{app_project.status.humanize} (#{app_project.completion_percentage}% complete)"
    context_parts << "Generated: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
    context_parts << ""

    # Project responses
    if app_project.has_responses?
      context_parts << "## Project Requirements & Vision"
      context_parts << ""

      responses = []
      AppProject::RESPONSE_FIELDS.each_with_index do |field, index|
        value = app_project.send(field)
        next if value.blank?

        question_titles = [
          "Application Vision", "Target Users", "User Journeys", "Core Features",
          "Technical Requirements", "Third-party Integrations", "Success Metrics",
          "Competition Analysis", "Design Requirements", "Challenges & Concerns"
        ]

        responses << "### #{index + 1}. #{question_titles[index]}"
        responses << ""
        responses << value
        responses << ""
      end

      context_parts.concat(responses)
    end

    # PRD if available
    if app_project.generated_prd.present?
      context_parts << "## Product Requirements Document"
      context_parts << ""
      context_parts << app_project.generated_prd
      context_parts << ""
    end

    # Tasks if available
    if app_project.generated_tasks.present?
      context_parts << "## Development Task Breakdown"
      context_parts << ""
      context_parts << app_project.generated_tasks
      context_parts << ""
    end

    # CLAUDE.md if available
    if app_project.generated_claude_md.present?
      context_parts << "## Existing CLAUDE.md Documentation"
      context_parts << ""
      context_parts << app_project.generated_claude_md
      context_parts << ""
    end

    # Usage instructions
    context_parts << "## How to Use This Context"
    context_parts << ""
    context_parts << "This context contains all the information about the '#{app_project.name}' project."
    context_parts << "You can use this information to:"
    context_parts << "- Understand the project requirements and scope"
    context_parts << "- Implement features according to the PRD specifications"
    context_parts << "- Follow the development task breakdown"
    context_parts << "- Answer questions about the project"
    context_parts << ""
    context_parts << "When working on this project, please refer to the requirements, user journeys,"
    context_parts << "and technical specifications outlined above."

    context_parts.join("\n")
  end
end
