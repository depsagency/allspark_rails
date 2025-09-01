require "base64"

module AppProjects
  class DocumentationGeneratorService
    attr_reader :app_project, :project_dir

    OUTPUT_TYPES = %i[prd tasks user_input claude_context claude_prompts logo_data marketing_page metadata].freeze

    def initialize(app_project)
      @app_project = app_project
      @project_dir = Rails.root.join("docs/app-projects/generated/#{app_project.slug}")
    end

    # Main method - supports both full and partial generation
    def generate_and_save(options = {})
      only = Array(options[:only]) if options[:only]
      force = options[:force] || false

      return false unless should_generate?(only)

      create_project_directory

      if only
        serialize_specific_outputs(only, force)
      else
        serialize_all_outputs(force)
      end

      update_app_project_record(only)
      true
    rescue => e
      Rails.logger.error "Failed to generate documentation for AppProject #{app_project.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      cleanup_on_error
      false
    end

    # Individual serialization methods
    def serialize_prd(force: false)
      generate_and_save(only: [ :prd, :user_input, :metadata ], force: force)
    end

    def serialize_tasks(force: false)
      generate_and_save(only: [ :tasks, :metadata ], force: force)
    end

    def serialize_user_input(force: false)
      generate_and_save(only: [ :user_input, :metadata ], force: force)
    end

    def serialize_claude_context(force: false)
      generate_and_save(only: [ :claude_context, :metadata ], force: force)
    end

    def serialize_claude_prompts(force: false)
      generate_and_save(only: [ :claude_prompts, :metadata ], force: force)
    end

    def serialize_logo_data(force: false)
      generate_and_save(only: [ :logo_data, :metadata ], force: force)
    end

    def serialize_marketing_page(force: false)
      generate_and_save(only: [ :marketing_page, :metadata ], force: force)
    end

    def serialize_all(force: false)
      generate_and_save(force: force)
    end

    # Check which files exist and their status
    def documentation_status
      status = {}

      OUTPUT_TYPES.each do |type|
        file_path = file_path_for_type(type)
        if File.exist?(file_path)
          status[type] = {
            exists: true,
            path: file_path,
            size: File.size(file_path),
            modified_at: File.mtime(file_path),
            needs_update: needs_update?(type)
          }
        else
          status[type] = {
            exists: false,
            available: content_available_for_type?(type)
          }
        end
      end

      status
    end

    private

    def should_generate?(only_types)
      if only_types
        only_types.any? { |type| content_available_for_type?(type) }
      else
        app_project.has_ai_outputs? || app_project.completion_percentage > 0
      end
    end

    def serialize_specific_outputs(types, force)
      types.each do |type|
        next unless content_available_for_type?(type)
        next if !force && file_exists_and_current?(type)

        send("save_#{type}")
      end
    end

    def serialize_all_outputs(force)
      OUTPUT_TYPES.each do |type|
        next unless content_available_for_type?(type)
        next if !force && file_exists_and_current?(type)

        send("save_#{type}")
      end
    end

    def create_project_directory
      FileUtils.mkdir_p(project_dir)
      FileUtils.mkdir_p(project_dir.join("artifacts"))
    end

    def cleanup_on_error
      # Remove partial files on error, but keep existing complete files
      temp_files = Dir.glob(project_dir.join("*.tmp"))
      temp_files.each { |file| File.delete(file) rescue nil }
    end

    def content_available_for_type?(type)
      case type
      when :prd
        app_project.generated_prd.present?
      when :tasks
        app_project.generated_tasks.present?
      when :user_input
        app_project.completion_percentage > 0
      when :claude_context
        app_project.generated_claude_md.present?
      when :claude_prompts
        app_project.generated_claude_prompt.present?
      when :logo_data
        app_project.has_logo?
      when :marketing_page
        app_project.has_marketing_page?
      when :metadata
        true # Always available
      else
        false
      end
    end

    def file_exists_and_current?(type)
      file_path = file_path_for_type(type)
      File.exist?(file_path) && !needs_update?(type)
    end

    def needs_update?(type)
      file_path = file_path_for_type(type)
      return true unless File.exist?(file_path)

      file_mtime = File.mtime(file_path)
      content_mtime = content_updated_at_for_type(type)

      content_mtime && content_mtime > file_mtime
    end

    def content_updated_at_for_type(type)
      case type
      when :prd, :tasks, :claude_context
        app_project.updated_at
      when :user_input
        app_project.updated_at
      when :logo_data
        app_project.logo_generation_metadata&.dig("generated_at")&.to_time
      when :marketing_page
        app_project.marketing_page_metadata&.dig("generated_at")&.to_time
      when :metadata
        app_project.updated_at
      else
        app_project.updated_at
      end
    end

    def file_path_for_type(type)
      case type
      when :prd
        project_dir.join("prd.md")
      when :tasks
        project_dir.join("tasks.md")
      when :user_input
        project_dir.join("user-input.md")
      when :claude_context
        project_dir.join("claude-context.md")
      when :claude_prompts
        project_dir.join("claude-prompts.md")
      when :logo_data
        # Determine file extension based on logo data
        extension = detect_logo_extension
        project_dir.join("artifacts/logo.#{extension}")
      when :marketing_page
        project_dir.join("artifacts/marketing-page.md")
      when :metadata
        project_dir.join("metadata.json")
      else
        project_dir.join("#{type}.md")
      end
    end

    def save_prd
      content = build_prd_content
      write_file_safely(file_path_for_type(:prd), content)
    end

    def save_tasks
      content = build_tasks_content
      write_file_safely(file_path_for_type(:tasks), content)
    end

    def save_user_input
      content = build_user_input_content
      write_file_safely(file_path_for_type(:user_input), content)
    end

    def save_claude_context
      return unless app_project.generated_claude_md.present?

      content = build_claude_context_content
      write_file_safely(file_path_for_type(:claude_context), content)
    end

    def save_claude_prompts
      return unless app_project.generated_claude_prompt.present?

      content = app_project.generated_claude_prompt
      write_file_safely(file_path_for_type(:claude_prompts), content)
    end

    def save_logo_data
      return unless app_project.has_logo?

      # Get the base64 logo data
      logo_data = app_project.logo_data
      return unless logo_data.present?

      # Extract the base64 data (remove data:image/...;base64, prefix if present)
      base64_data = logo_data.split(",").last

      # Decode the base64 data to binary
      binary_data = Base64.decode64(base64_data)

      # Write the binary image data directly
      file_path = file_path_for_type(:logo_data)
      write_binary_file_safely(file_path, binary_data)
    end

    def save_marketing_page
      return unless app_project.has_marketing_page?

      content = build_marketing_page_content
      write_file_safely(file_path_for_type(:marketing_page), content)
    end

    def save_metadata
      metadata = build_metadata
      write_file_safely(file_path_for_type(:metadata), JSON.pretty_generate(metadata))
    end

    def write_file_safely(file_path, content)
      # Create directory if it doesn't exist
      FileUtils.mkdir_p(File.dirname(file_path))

      # Write to temporary file first, then move to final location
      temp_path = "#{file_path}.tmp"
      File.write(temp_path, content)
      File.rename(temp_path, file_path)

      Rails.logger.debug "Saved documentation file: #{file_path}"
    rescue => e
      File.delete(temp_path) if File.exist?(temp_path)
      Rails.logger.error "Failed to write file #{file_path}: #{e.message}"
      raise
    end

    def write_binary_file_safely(file_path, binary_data)
      # Create directory if it doesn't exist
      FileUtils.mkdir_p(File.dirname(file_path))

      # Write to temporary file first, then move to final location
      temp_path = "#{file_path}.tmp"
      File.binwrite(temp_path, binary_data)
      File.rename(temp_path, file_path)

      Rails.logger.debug "Saved binary file: #{file_path}"
    rescue => e
      File.delete(temp_path) if File.exist?(temp_path)
      Rails.logger.error "Failed to write binary file #{file_path}: #{e.message}"
      raise
    end

    def detect_logo_extension
      return "png" unless app_project.logo_data.present?

      # Check the data URL prefix to determine format
      logo_data = app_project.logo_data
      case logo_data
      when /^data:image\/jpeg/i
        "jpg"
      when /^data:image\/jpg/i
        "jpg"
      when /^data:image\/png/i
        "png"
      when /^data:image\/gif/i
        "gif"
      when /^data:image\/webp/i
        "webp"
      else
        # Default to png if format cannot be determined
        "png"
      end
    end

    def build_user_input_content
      <<~MARKDOWN
        # User Input: #{app_project.name}

        Generated: #{Time.current.strftime('%Y-%m-%d %H:%M:%S UTC')}
        Project ID: #{app_project.id}
        Completion: #{app_project.completion_percentage}%

        ## Application Vision
        #{app_project.vision_response || 'Not provided'}

        ## Target Users
        #{app_project.users_response || 'Not provided'}

        ## User Journeys
        #{app_project.journeys_response || 'Not provided'}

        ## Core Features
        #{app_project.features_response || 'Not provided'}

        ## Technical Requirements
        #{app_project.technical_response || 'Not provided'}

        ## Third-party Integrations
        #{app_project.integrations_response || 'Not provided'}

        ## Success Metrics
        #{app_project.success_response || 'Not provided'}

        ## Competition Analysis
        #{app_project.competition_response || 'Not provided'}

        ## Design Requirements
        #{app_project.design_response || 'Not provided'}

        ## Challenges & Concerns
        #{app_project.challenges_response || 'Not provided'}
      MARKDOWN
    end

    def build_claude_context_content
      return app_project.generated_claude_md if app_project.generated_claude_md.present?

      <<~MARKDOWN
        # Claude Code Context: #{app_project.name}

        Generated: #{Time.current.strftime('%Y-%m-%d %H:%M:%S UTC')}
        Project ID: #{app_project.id}

        ## Project Overview
        #{app_project.vision_response&.truncate(300) || 'Not provided'}

        ## Implementation Notes
        This context file will be populated when Claude.md generation is completed.
      MARKDOWN
    end

    def build_logo_data_content
      logo_data = {
        project_id: app_project.id,
        generated_at: Time.current.iso8601,
        logo_url: app_project.generated_logo_url,
        logo_attached: app_project.generated_logo.attached?,
        logo_data: app_project.logo_data,
        generation_metadata: app_project.logo_generation_metadata,
        prompt_used: app_project.logo_prompt
      }

      JSON.pretty_generate(logo_data)
    end

    def build_marketing_page_content
      marketing_page = app_project.generated_marketing_page

      <<~MARKDOWN
        # Marketing Page: #{app_project.name}

        Generated: #{Time.current.strftime('%Y-%m-%d %H:%M:%S UTC')}
        Project ID: #{app_project.id}

        #{marketing_page&.content || 'Marketing page content not available'}

        ## Generation Metadata
        - **Prompt**: #{app_project.marketing_page_prompt}
        - **Generated At**: #{app_project.marketing_page_metadata&.dig('generated_at')}
        - **Cost**: $#{app_project.marketing_page_metadata&.dig('cost') || 0}
      MARKDOWN
    end

    def build_prd_content
      <<~MARKDOWN
        # Product Requirements Document: #{app_project.name}

        Generated: #{Time.current.strftime('%Y-%m-%d %H:%M:%S UTC')}
        Project ID: #{app_project.id}

        #{app_project.generated_prd}

        ---

        ## Original User Responses

        ### Vision & Goals
        #{app_project.vision_response}

        ### Target Users
        #{app_project.users_response}

        ### User Journeys
        #{app_project.journeys_response}

        ### Features & Requirements
        #{app_project.features_response}

        ### Technical Requirements
        #{app_project.technical_response}

        ### Integrations
        #{app_project.integrations_response}

        ### Success Metrics
        #{app_project.success_response}

        ### Competition Analysis
        #{app_project.competition_response}

        ### Design Requirements
        #{app_project.design_response}

        ### Challenges & Risks
        #{app_project.challenges_response}
      MARKDOWN
    end

    def build_tasks_content
      <<~MARKDOWN
        # Task List: #{app_project.name}

        Generated: #{Time.current.strftime('%Y-%m-%d %H:%M:%S UTC')}
        Project ID: #{app_project.id}

        #{app_project.generated_tasks}

        ## Additional Context

        ### Technical Stack Recommendations
        Based on responses: #{app_project.technical_response&.truncate(200)}

        ### Integration Requirements
        #{app_project.integrations_response&.truncate(200)}

        ### Success Criteria
        #{app_project.success_response&.truncate(200)}
      MARKDOWN
    end

    def build_metadata
      {
        project_id: app_project.id,
        generated_at: Time.current.iso8601,
        generation_version: "1.0",
        user_id: app_project.user_id,
        session_data: {
          completion_percentage: app_project.completion_percentage,
          questions_answered: count_answered_questions,
          total_questions: AppProject::RESPONSE_FIELDS.count,
          ready_for_generation: app_project.ready_for_generation?
        },
        llm_metadata: build_llm_metadata,
        project_metadata: {
          name: app_project.name,
          slug: app_project.slug,
          status: app_project.status,
          created_at: app_project.created_at.iso8601,
          updated_at: app_project.updated_at.iso8601,
          generation_cost: app_project.generation_cost,
          last_generation_at: app_project.last_generation_at&.iso8601
        },
        files_generated: generated_files,
        outputs_available: {
          prd: app_project.generated_prd.present?,
          tasks: app_project.generated_tasks.present?,
          claude_prompt: app_project.generated_claude_prompt.present?,
          claude_md: app_project.generated_claude_md.present?,
          logo: app_project.has_logo?,
          marketing_page: app_project.has_marketing_page?
        }
      }
    end

    def build_llm_metadata
      ai_gens = app_project.ai_generations.completed

      {
        total_generations: ai_gens.count,
        total_tokens: ai_gens.sum(:token_count) || 0,
        total_cost: ai_gens.sum(:cost) || 0,
        providers_used: ai_gens.distinct.pluck(:llm_provider),
        models_used: ai_gens.distinct.pluck(:model_used).compact,
        generation_types: ai_gens.distinct.pluck(:generation_type),
        average_processing_time: ai_gens.average(:processing_time_seconds)&.round(2)
      }
    end

    def count_answered_questions
      AppProject::RESPONSE_FIELDS.count { |field| app_project.send(field).present? }
    end

    def generated_files
      files = []
      files << "prd.md" if app_project.generated_prd.present?
      files << "tasks.md" if app_project.generated_tasks.present?
      files << "user-input.md"
      files << "claude-context.md" if app_project.generated_claude_md.present?
      if app_project.has_logo?
        extension = detect_logo_extension
        files << "artifacts/logo.#{extension}"
      end
      files << "artifacts/marketing-page.md" if app_project.has_marketing_page?
      files << "metadata.json"
      files
    end

    def build_metadata
      {
        project_id: app_project.id,
        generated_at: Time.current.iso8601,
        generation_version: "1.0",
        user_id: app_project.user_id,
        session_data: {
          completion_percentage: app_project.completion_percentage,
          questions_answered: count_answered_questions,
          total_questions: AppProject::RESPONSE_FIELDS.count,
          ready_for_generation: app_project.ready_for_generation?
        },
        llm_metadata: build_llm_metadata,
        project_metadata: {
          name: app_project.name,
          slug: app_project.slug,
          status: app_project.status,
          created_at: app_project.created_at.iso8601,
          updated_at: app_project.updated_at.iso8601,
          generation_cost: app_project.generation_cost,
          last_generation_at: app_project.last_generation_at&.iso8601
        },
        files_generated: generated_files,
        outputs_available: {
          prd: app_project.generated_prd.present?,
          tasks: app_project.generated_tasks.present?,
          claude_prompt: app_project.generated_claude_prompt.present?,
          claude_md: app_project.generated_claude_md.present?,
          logo: app_project.has_logo?,
          marketing_page: app_project.has_marketing_page?
        }
      }
    end

    def build_llm_metadata
      ai_gens = app_project.ai_generations.completed

      {
        total_generations: ai_gens.count,
        total_tokens: ai_gens.sum(:token_count) || 0,
        total_cost: ai_gens.sum(:cost) || 0,
        providers_used: ai_gens.distinct.pluck(:llm_provider),
        models_used: ai_gens.distinct.pluck(:model_used).compact,
        generation_types: ai_gens.distinct.pluck(:generation_type),
        average_processing_time: ai_gens.average(:processing_time_seconds)&.round(2)
      }
    end

    def count_answered_questions
      AppProject::RESPONSE_FIELDS.count { |field| app_project.send(field).present? }
    end

    def generated_files
      files = []
      files << "prd.md" if app_project.generated_prd.present?
      files << "tasks.md" if app_project.generated_tasks.present?
      files << "user-input.md"
      files << "claude-context.md" if app_project.generated_claude_md.present?
      files << "metadata.json"
      files
    end

    def update_app_project_record(only_types = nil)
      timestamp = Time.current.iso8601
      update_data = {
        documentation_generated_at: timestamp,
        documentation_version: "1.0"
      }

      if only_types
        # Track which specific outputs were serialized
        serialized_outputs = only_types.index_with { timestamp }
        update_data[:serialized_outputs] = (app_project.generation_metadata["serialized_outputs"] || {}).merge(serialized_outputs)
      else
        # Full generation
        update_data[:full_documentation_generated_at] = timestamp
      end

      app_project.update!(
        generation_metadata: app_project.generation_metadata.merge(update_data)
      )
    end
  end
end
