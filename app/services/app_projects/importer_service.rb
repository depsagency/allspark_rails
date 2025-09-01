require "base64"
require "json"

module AppProjects
  class ImporterService
    include ActiveModel::Validations

    attr_reader :project_folder_id, :project_dir, :current_user, :import_options, :errors

    def initialize(project_folder_id, current_user:, options: {})
      @project_folder_id = project_folder_id
      @current_user = current_user
      @import_options = {
        overwrite_existing: false,
        import_artifacts: true,
        validate_metadata: true
      }.merge(options)
      @project_dir = Rails.root.join("docs/app-projects/generated/#{project_folder_id}")
      @errors = []
    end

    # Main import method
    def import!
      validate_preconditions!

      metadata = load_metadata
      validate_metadata!(metadata) if import_options[:validate_metadata]

      # Check for existing project
      existing_project = find_existing_project(metadata)
      if existing_project && !import_options[:overwrite_existing]
        raise ImportError, "Project already exists with ID #{existing_project.id}. Use overwrite_existing: true to replace it."
      end

      # Import the project
      ActiveRecord::Base.transaction do
        app_project = import_project_data(metadata, existing_project)
        import_file_contents(app_project, metadata)
        import_artifacts(app_project) if import_options[:import_artifacts]

        app_project.tap do |project|
          Rails.logger.info "Successfully imported AppProject #{project.id} from #{project_folder_id}"
        end
      end
    rescue ImportError => e
      Rails.logger.error "Import failed for #{project_folder_id}: #{e.message}"
      raise
    rescue => e
      Rails.logger.error "Unexpected error during import of #{project_folder_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise ImportError, "Import failed: #{e.message}"
    end

    # Preview what will be imported without actually importing
    def preview
      validate_preconditions!
      metadata = load_metadata

      {
        project_id: metadata["project_id"],
        project_name: metadata.dig("project_metadata", "name"),
        slug: metadata.dig("project_metadata", "slug"),
        status: metadata.dig("project_metadata", "status"),
        completion_percentage: metadata.dig("session_data", "completion_percentage"),
        generation_cost: metadata.dig("project_metadata", "generation_cost"),
        files_available: detect_available_files,
        artifacts_available: detect_available_artifacts,
        existing_project: find_existing_project(metadata)&.slice(:id, :name, :slug, :status),
        can_import: true,
        warnings: generate_warnings(metadata)
      }
    rescue => e
      {
        project_id: project_folder_id,
        project_name: "Unknown",
        can_import: false,
        error: e.message,
        files_available: [],
        artifacts_available: []
      }
    end

    # Class method to list all available projects for import
    def self.list_available_projects
      generated_dir = Rails.root.join("docs/app-projects/generated")
      return [] unless Dir.exist?(generated_dir)

      Dir.entries(generated_dir)
         .select { |entry| File.directory?(File.join(generated_dir, entry)) && !entry.start_with?(".") }
         .map { |folder_id| preview_project(folder_id) }
         .sort_by { |p| p[:project_name] || "zzz" }
    end

    # Quick preview without user context
    def self.preview_project(project_folder_id)
      project_dir = Rails.root.join("docs/app-projects/generated/#{project_folder_id}")
      metadata_file = project_dir.join("metadata.json")

      return {
        project_id: project_folder_id,
        project_name: "Invalid Project",
        can_import: false,
        error: "Project folder not found"
      } unless Dir.exist?(project_dir)

      return {
        project_id: project_folder_id,
        project_name: "No Metadata",
        can_import: false,
        error: "metadata.json not found"
      } unless File.exist?(metadata_file)

      begin
        metadata = JSON.parse(File.read(metadata_file))
        {
          project_id: project_folder_id,
          project_name: metadata.dig("project_metadata", "name") || "Unnamed Project",
          slug: metadata.dig("project_metadata", "slug"),
          status: metadata.dig("project_metadata", "status"),
          completion_percentage: metadata.dig("session_data", "completion_percentage"),
          generated_at: metadata["generated_at"],
          can_import: true,
          files_count: metadata["files_generated"]&.count || 0
        }
      rescue JSON::ParserError
        {
          project_id: project_folder_id,
          project_name: "Invalid Metadata",
          can_import: false,
          error: "Invalid metadata.json format"
        }
      rescue => e
        {
          project_id: project_folder_id,
          project_name: "Error",
          can_import: false,
          error: e.message
        }
      end
    end

    private

    def validate_preconditions!
      raise ImportError, "Project folder not found: #{project_dir}" unless Dir.exist?(project_dir)
      raise ImportError, "metadata.json not found in #{project_dir}" unless metadata_file_exists?
      raise ImportError, "Current user is required for import" unless current_user
    end

    def metadata_file_exists?
      File.exist?(project_dir.join("metadata.json"))
    end

    def load_metadata
      metadata_content = File.read(project_dir.join("metadata.json"))
      JSON.parse(metadata_content)
    rescue JSON::ParserError => e
      raise ImportError, "Invalid metadata.json format: #{e.message}"
    end

    def validate_metadata!(metadata)
      required_fields = %w[project_id generated_at project_metadata]
      missing_fields = required_fields - metadata.keys

      if missing_fields.any?
        raise ImportError, "Metadata missing required fields: #{missing_fields.join(', ')}"
      end

      unless metadata["project_metadata"]["name"].present?
        raise ImportError, "Project name is required in metadata"
      end
    end

    def find_existing_project(metadata)
      project_id = metadata["project_id"]
      project_slug = metadata.dig("project_metadata", "slug")

      # Try to find by UUID first, then by slug
      AppProject.find_by(id: project_id) || AppProject.find_by(slug: project_slug)
    end

    def import_project_data(metadata, existing_project = nil)
      project_data = build_project_attributes(metadata)

      if existing_project
        existing_project.update!(project_data)
        existing_project
      else
        # Use the original project ID if it doesn't conflict
        begin
          AppProject.create!(project_data.merge(id: metadata["project_id"]))
        rescue ActiveRecord::RecordNotUnique
          # If ID conflicts, let Rails generate a new UUID
          AppProject.create!(project_data.except(:id))
        end
      end
    end

    def build_project_attributes(metadata)
      project_meta = metadata["project_metadata"] || {}
      session_data = metadata["session_data"] || {}

      {
        name: project_meta["name"],
        slug: generate_unique_slug(project_meta["slug"]),
        status: project_meta["status"] || "completed",
        user: current_user,
        generation_metadata: metadata.except("project_metadata", "session_data").merge(
          "imported_at" => Time.current.iso8601,
          "imported_by" => current_user.id,
          "original_project_id" => metadata["project_id"]
        )
      }
    end

    def generate_unique_slug(desired_slug)
      return desired_slug if desired_slug.blank?

      base_slug = desired_slug
      candidate_slug = base_slug
      counter = 1

      while AppProject.exists?(slug: candidate_slug)
        candidate_slug = "#{base_slug}-#{counter}"
        counter += 1
      end

      candidate_slug
    end

    def import_file_contents(app_project, metadata)
      # Import user input responses
      import_user_responses(app_project)

      # Import generated content
      import_generated_content(app_project)

      # Save the updated project
      app_project.save!
    end

    def import_user_responses(app_project)
      user_input_file = project_dir.join("user-input.md")
      return unless File.exist?(user_input_file)

      content = File.read(user_input_file)

      # Parse user input sections
      responses = parse_user_input_sections(content)
      app_project.assign_attributes(responses)
    end

    def parse_user_input_sections(content)
      responses = {}

      # Define section mappings
      section_mappings = {
        "Application Vision" => :vision_response,
        "Target Users" => :users_response,
        "User Journeys" => :journeys_response,
        "Core Features" => :features_response,
        "Technical Requirements" => :technical_response,
        "Third-party Integrations" => :integrations_response,
        "Success Metrics" => :success_response,
        "Competition Analysis" => :competition_response,
        "Design Requirements" => :design_response,
        "Challenges & Concerns" => :challenges_response
      }

      # Split content into sections
      sections = content.split(/^## /)

      sections.each do |section|
        section_mappings.each do |title, field|
          if section.start_with?(title)
            # Extract content after the title
            content_lines = section.lines[1..-1] || []
            clean_content = content_lines.join.strip
            clean_content = clean_content.gsub(/^Not provided$/, "") # Remove "Not provided" placeholders

            responses[field] = clean_content if clean_content.present?
            break
          end
        end
      end

      responses
    end

    def import_generated_content(app_project)
      # Import PRD
      prd_file = project_dir.join("prd.md")
      if File.exist?(prd_file)
        app_project.generated_prd = File.read(prd_file)
      end

      # Import tasks
      tasks_file = project_dir.join("tasks.md")
      if File.exist?(tasks_file)
        app_project.generated_tasks = File.read(tasks_file)
      end

      # Import Claude prompts
      prompts_file = project_dir.join("claude-prompts.md")
      if File.exist?(prompts_file)
        app_project.generated_claude_prompt = File.read(prompts_file)
      end

      # Import Claude context/CLAUDE.md
      context_file = project_dir.join("claude-context.md")
      if File.exist?(context_file)
        app_project.generated_claude_md = File.read(context_file)
      end
    end

    def import_artifacts(app_project)
      artifacts_dir = project_dir.join("artifacts")
      return unless Dir.exist?(artifacts_dir)

      # Import logo
      import_logo(app_project, artifacts_dir)

      # Import marketing page content
      import_marketing_page(app_project, artifacts_dir)
    end

    def import_logo(app_project, artifacts_dir)
      logo_files = Dir.glob(artifacts_dir.join("logo.*"))
      return if logo_files.empty?

      logo_file = logo_files.first
      file_content = File.binread(logo_file)

      # Convert to base64 data URL
      file_extension = File.extname(logo_file).sub(".", "")
      mime_type = case file_extension.downcase
      when "png" then "image/png"
      when "jpg", "jpeg" then "image/jpeg"
      when "gif" then "image/gif"
      when "webp" then "image/webp"
      else "image/png"
      end

      base64_data = Base64.strict_encode64(file_content)
      data_url = "data:#{mime_type};base64,#{base64_data}"

      app_project.logo_data = data_url
    end

    def import_marketing_page(app_project, artifacts_dir)
      marketing_file = artifacts_dir.join("marketing-page.md")
      return unless File.exist?(marketing_file)

      content = File.read(marketing_file)

      # Store the marketing page content in metadata for now
      # This can be enhanced later to create actual Page records
      metadata = app_project.generation_metadata || {}
      metadata["imported_marketing_page_content"] = content
      app_project.generation_metadata = metadata
    end

    # Add a helper method to check if model has responses
    def app_project_has_responses?(app_project)
      AppProject::RESPONSE_FIELDS.any? { |field| app_project.send(field).present? }
    end

    def detect_available_files
      files = []

      %w[prd.md tasks.md user-input.md claude-context.md claude-prompts.md metadata.json].each do |filename|
        file_path = project_dir.join(filename)
        if File.exist?(file_path)
          files << {
            name: filename,
            size: File.size(file_path),
            modified_at: File.mtime(file_path)
          }
        end
      end

      files
    end

    def detect_available_artifacts
      artifacts = []
      artifacts_dir = project_dir.join("artifacts")

      return artifacts unless Dir.exist?(artifacts_dir)

      Dir.glob(artifacts_dir.join("*")).each do |file_path|
        next unless File.file?(file_path)

        artifacts << {
          name: File.basename(file_path),
          size: File.size(file_path),
          modified_at: File.mtime(file_path)
        }
      end

      artifacts
    end

    def generate_warnings(metadata)
      warnings = []

      # Check if project already exists
      existing = find_existing_project(metadata)
      if existing
        warnings << "Project already exists with name '#{existing.name}' and slug '#{existing.slug}'"
      end

      # Check for missing files
      essential_files = %w[user-input.md metadata.json]
      missing_files = essential_files.reject { |f| File.exist?(project_dir.join(f)) }

      if missing_files.any?
        warnings << "Missing essential files: #{missing_files.join(', ')}"
      end

      # Check metadata version compatibility
      generation_version = metadata["generation_version"]
      if generation_version && generation_version != "1.0"
        warnings << "Metadata version #{generation_version} may not be fully compatible"
      end

      warnings
    end

    # Custom exception for import errors
    class ImportError < StandardError; end
  end
end
