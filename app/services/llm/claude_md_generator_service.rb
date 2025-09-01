# frozen_string_literal: true

# Service for generating project-specific CLAUDE.md files using AI
#
# This service creates a customized CLAUDE.md file based on the generated
# PRD, tasks, and other project materials to provide AI coding assistants with
# specific context about the application being built.
#
# Usage:
#   service = Llm::ClaudeMdGeneratorService.new(app_project)
#   result = service.generate
#
class Llm::ClaudeMdGeneratorService
  include ActiveModel::Model
  include ActiveModel::Attributes

  def initialize(app_project, provider: nil)
    @app_project = app_project
    @provider = provider || "gemini"  # Default to Gemini for CLAUDE.md generation
    super()
  end

  def generate
    return false unless app_project.claude_md_ready_for_generation?

    # Create AI generation record for tracking
    ai_generation = create_ai_generation

    begin
      # Generate the CLAUDE.md content
      generated_content = generate_claude_md_content

      if generated_content.present?
        # Process and clean the content
        processed_content = process_claude_md_content(generated_content)

        # Store the result in the app project
        store_claude_md_result(processed_content, ai_generation)

        # Update AI generation record with success
        ai_generation.update!(
          status: "completed",
          raw_output: processed_content,
          processing_time_seconds: Time.current - ai_generation.created_at
        )

        true
      else
        ai_generation.update!(
          status: "failed",
          error_message: "Generated content was empty"
        )
        false
      end

    rescue => e
      Rails.logger.error "CLAUDE.md generation failed: #{e.message}"
      ai_generation.update!(
        status: "failed",
        error_message: e.message,
        processing_time_seconds: Time.current - ai_generation.created_at
      )
      false
    end
  end

  private

  attr_reader :app_project, :provider

  def create_ai_generation
    app_project.ai_generations.create!(
      generation_type: "claude_md",
      llm_provider: provider,
      model_used: determine_model,
      input_prompt: build_prompt,
      status: "pending"
    )
  end

  def generate_claude_md_content
    prompt = build_prompt
    Rails.logger.info "Generating CLAUDE.md with #{provider} using prompt length: #{prompt.length}"

    case provider
    when "gemini"
      result = call_gemini_api(prompt)
    else
      raise "Unsupported provider: #{provider}"
    end

    Rails.logger.info "Generated CLAUDE.md content length: #{result&.length || 0}"
    result
  end

  def call_gemini_api(prompt)
    adapter = Llm::AdapterFactory.create # Use default provider from config

    adapter.generate(
      prompt,
      max_tokens: 20000,
      temperature: 0.7
    )
  end

  def build_prompt
    <<~PROMPT
      You are a technical documentation expert. Generate a comprehensive CLAUDE.md file for this specific Rails application.

      CLAUDE.md files provide guidance to AI coding assistants (Claude, Cursor, GitHub Copilot, etc.) when working with code repositories.#{' '}
      This should be PROJECT-SPECIFIC, not generic Rails documentation.

      ## Project Information:
      **Project Name:** #{app_project.name}
      **Vision:** #{app_project.vision_response}

      ## Generated PRD Content:
      #{app_project.generated_prd}

      ## Generated Development Tasks:
      #{app_project.generated_tasks}

      ## User Responses:
      - **Target Users:** #{app_project.users_response}
      - **Core Features:** #{app_project.features_response}
      - **Technical Requirements:** #{app_project.technical_response}
      - **Integrations:** #{app_project.integrations_response}
      - **Design Requirements:** #{app_project.design_response}

      ## Template Features Available:
      This Rails template includes many built-in features that should be leveraged instead of building from scratch:

      ### Core Infrastructure:
      - **Rails 8.0** with esbuild, PostgreSQL (UUID primary keys), Redis & Sidekiq
      - **Complete Authentication** with Devise + DaisyUI views and Pundit authorization
      - **Google Workspace Integration** (Drive, Gmail, Calendar APIs) with service layer patterns

      ### Component Library & UI:
      - **15+ Production-Ready ViewComponents** with DaisyUI styling and comprehensive testing
      - **Advanced Theme System** with 30+ DaisyUI themes, instant switching and persistence
      - **Lookbook Integration** for component documentation and previews
      - **Component Generators** for rapid UI development

      ### Real-time Features:
      - **ActionCable Infrastructure** with live notifications and presence tracking
      - **Live Updates** with progress tracking and collaborative editing support
      - **Real-time Notifications** with automatic delivery and read/unread tracking
      - **Presence System** for user online/offline status

      ### Testing & Quality:
      - **Comprehensive RSpec Suite** with FactoryBot, SimpleCov, and comprehensive helpers
      - **System Testing** with Capybara and real-time feature testing
      - **Component Testing** with ViewComponent test helpers
      - **Code Quality Tools** with RuboCop, Brakeman, Bundle Audit and auto-fixing

      ### Monitoring & Performance:
      - **Performance Tracking** with request timing and memory monitoring
      - **Error Tracking** with context and automatic reporting
      - **Event Analytics** ready for Ahoy/Blazer integration
      - **Health Monitoring** with system checks and metrics collection

      ## Documentation Directory (docs/):
      Refer to these documentation files for implementation guidance:

      - **docs/generators.md** - Custom generators for UI components, services, and scaffolds
      - **docs/theme-system.md** - DaisyUI theme system implementation and customization
      - **docs/logo-replacement.md** - Logo specifications and replacement guidelines
      - **docs/ai-code-examples.md** - AI/LLM integration patterns and examples
      - **docs/monitoring.md** - Performance monitoring and error tracking setup
      - **docs/components/** - ViewComponent documentation and examples

      ## Development Environment:
      **CRITICAL: This app runs in Docker for development.** All Rails commands must be executed inside the Docker container:

      ```bash
      # Correct way to run Rails commands:
      docker exec rails-template-app-1 bin/rails generate model User
      docker exec rails-template-app-1 bin/rails db:migrate
      docker exec rails-template-app-1 bin/rails console
      docker exec rails-template-app-1 bundle install

      # For Sidekiq monitoring:
      docker exec rails-template-sidekiq-1 [sidekiq-commands]
      ```

      ## Instructions:
      Generate a CLAUDE.md file that includes:

      1. **Project Overview** - Specific to this application's purpose and goals
      2. **Architecture & Tech Stack** - Based on the technical requirements and PRD, leveraging template features
      3. **Key Features & Components** - From the features and requirements, noting which template components to use
      4. **Development Workflow** - Based on the generated tasks and phases, with Docker commands
      5. **Implementation Guide** - Specific guidance for building this app using template features
      6. **Database Schema** - Based on the data requirements in PRD (use UUID primary keys)
      7. **API Endpoints** - If mentioned in requirements
      8. **Testing Strategy** - Specific to this application's needs using RSpec/Capybara
      9. **Documentation References** - Point to relevant docs/ files for guidance
      10. **Docker Development Commands** - All commands with docker exec prefixes
      11. **Built-in Features to Leverage** - List which template features to use vs build custom

      ## Requirements:
      - Focus on THIS SPECIFIC APPLICATION, not generic Rails advice
      - Always recommend using built-in template features when applicable
      - Include actual feature names, models, and components from the PRD
      - Reference relevant docs/ files for implementation guidance
      - ALL Rails/database commands must use docker exec format
      - Provide actionable guidance for AI assistants when working on this project
      - Use proper markdown formatting
      - Be comprehensive but focused on what's actually being built

      Generate ONLY the CLAUDE.md content, starting with "# CLAUDE.md" header.
    PROMPT
  end

  def process_claude_md_content(content)
    # Clean up the content
    processed = content.strip

    # Ensure it starts with proper header
    unless processed.start_with?("# CLAUDE.md")
      processed = "# CLAUDE.md\n\n#{processed}"
    end

    # Remove any meta-commentary about the task
    processed = processed.gsub(/^(Here's|I'll generate|This is).*?\n\n/m, "")

    # Ensure proper spacing
    processed = processed.gsub(/\n{3,}/, "\n\n")

    processed.strip
  end

  def store_claude_md_result(content, ai_generation)
    metadata = {
      generated_at: Time.current,
      model: determine_model,
      provider: provider,
      cost: ai_generation.cost || 0,
      token_count: ai_generation.token_count,
      content_length: content.length
    }

    app_project.update!(
      generated_claude_md: content,
      claude_md_metadata: metadata
    )

    Rails.logger.info "Stored CLAUDE.md for app_project #{app_project.id} (#{content.length} characters)"
  end

  def determine_model
    case provider
    when "gemini"
      "gemini-2.5-pro"  # Use Gemini 2.5 Pro specifically for CLAUDE.md generation
    when "claude"
      ENV["CLAUDE_MODEL"] || "claude-3-5-sonnet-20241022"
    when "openai"
      ENV["OPENAI_MODEL"] || "gpt-4o-mini"
    else
      "unknown"
    end
  end
end
