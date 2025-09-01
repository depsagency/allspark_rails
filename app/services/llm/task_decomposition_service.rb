module Llm
  class TaskDecompositionService
    include ActiveModel::Model

    attr_accessor :app_project, :provider

    validates :app_project, presence: true

    TASK_CATEGORIES = [
      "Setup & Configuration",
      "Database & Models",
      "API Development",
      "Frontend Components",
      "Authentication & Authorization",
      "Business Logic",
      "Third-party Integrations",
      "Testing",
      "Performance & Security",
      "Deployment & DevOps"
    ].freeze

    def initialize(app_project:, provider: nil)
      @app_project = app_project
      @provider = provider || "gemini"  # Default to Gemini 2.5 Pro for task generation
    end

    def generate
      return false unless valid?
      return false unless app_project.generated_prd.present?

      ai_generation = create_generation_record

      begin
        prompt = ai_generation.input_prompt

        # Call LLM provider
        result = call_llm_provider(prompt)

        if result[:success]
          process_successful_generation(ai_generation, result)
        else
          process_failed_generation(ai_generation, result)
        end

        result[:success]
      rescue => e
        handle_generation_error(ai_generation, e)
        false
      end
    end

    private

    def create_generation_record
      prompt = build_prompt
      app_project.ai_generations.create!(
        generation_type: "tasks",
        llm_provider: provider,
        status: "pending",
        input_prompt: prompt,
        raw_output: nil
      )
    end

    def build_prompt
      readme_content = read_readme_content

      <<~PROMPT
        You are an expert technical project manager and software architect. Your task is to decompose the following Product Requirements Document (PRD) into a comprehensive, actionable task list for development.

        PROJECT: #{app_project.name}

        PRD CONTENT:
        #{app_project.generated_prd}

        USER'S TECHNICAL CONTEXT:
        #{app_project.technical_response}

        RAILS TEMPLATE FEATURES & CAPABILITIES:
        #{readme_content}

        IMPORTANT: This project uses a sophisticated Rails 8.0 template with many built-in features. When creating tasks, leverage the existing:
        - UI Components (15+ DaisyUI components available at /lookbook)
        - Generators (scaffold, ui_component, service, api_controller, ai_model)
        - Authentication system (already configured with Devise)
        - Real-time features (ActionCable, notifications, live updates)
        - Background jobs (Sidekiq configured)
        - AI/LLM integration services
        - Docker development environment
        - Quality tools (RuboCop, Brakeman, tests)

        UI/UX TEMPLATE PATTERNS & STRUCTURE:
        - Navigation: Main sidebar at app/views/layouts/_sidebar.html.erb with role-based sections
        - User Flow: Default users land at profile, admins at app_projects (see pages_controller.rb root action)
        - Routing: Features should be added to config/routes.rb with RESTful patterns
        - Views: Use DaisyUI components and follow existing patterns in app/views/
        - Controllers: Create user-facing controllers, not just API endpoints
        - Navigation Integration: Add new features to sidebar menu with proper icons and permissions
        - Responsive Design: All views must work on mobile/tablet using DaisyUI responsive classes
        - User Roles: Support both default users and admin users with appropriate feature access

        Please generate a detailed task breakdown with the following structure:

        ## Task Breakdown for #{app_project.name}

        ### Phase 1: Foundation & Setup (Week 1-2)
        - Leverage existing Rails template setup and configuration
        - Customize existing features for specific project needs
        - Database schema design and initial migrations using Rails generators

        ### Phase 2: Core Infrastructure (Week 3-4)
        - Extend existing authentication and authorization
        - Create models using Rails generators with UUID support
        - Build on existing API structure and routing
        - Utilize existing error handling and logging framework

        ### Phase 2.5: User Interface & Navigation Setup (Week 4.5)
        - Create user-facing controllers with proper actions
        - Design and implement view templates using DaisyUI components
        - Update routes.rb with all feature routes
        - Integrate new features into sidebar navigation
        - Create user landing pages and feature discovery flows
        - Implement responsive design for mobile and tablet use
        - Set up user role-based access and feature visibility

        ### Phase 3: Feature Development (Week 5-8)
        - Use existing UI components and create new ones with generators
        - Leverage real-time features for live updates
        - Build API endpoints and business logic using service patterns
        - Create complete user experiences with proper navigation flows

        ### Phase 4: Integrations (Week 9-10)
        - Use existing Google Workspace integrations if applicable
        - Build new integrations using service object patterns
        - Implement webhooks and data synchronization
        - Leverage existing LLM integration capabilities

        ### Phase 5: Testing & Quality (Week 11)
        - Use existing test infrastructure (RSpec configured)
        - Run existing quality checks (RuboCop, Brakeman)
        - Implement feature-specific tests
        - Performance testing using built-in tools

        ### Phase 6: Polish & Deployment (Week 12)
        - UI/UX refinements using existing component library
        - Performance optimizations with built-in monitoring
        - Security hardening using existing tools
        - Deploy using existing Docker configuration
        - Documentation using established patterns

        For each task, provide:
        1. **Task ID**: A unique identifier (e.g., TASK-001)
        2. **Task Title**: Clear, actionable title
        3. **Description**: Detailed description of what needs to be done
        4. **Dependencies**: Other tasks that must be completed first
        5. **Status**: Not Started | In Progress | Complete
        6. **Priority**: High/Medium/Low
        7. **Technical Notes**: Any specific technical considerations
        8. **Detailed execution plan**: Create a detailed execution plan for this task and list out all the steps to executing it so that a code agent can follow the steps and check them off as it goes.

        Format as a structured markdown document with clear sections and bullet points. Each task should be specific enough that a developer can start working on it immediately.

        Focus on:
        - Leveraging existing Rails template features and capabilities
        - Using built-in generators and components where possible
        - Following established patterns in the codebase
        - Breaking large features into manageable chunks
        - Identifying technical dependencies
        - Following Rails best practices
        - Considering the user's technical requirements and constraints
        - Creating a logical development sequence that builds on existing foundation
        - Providing detailed step-by-step execution plans for each task

        CRITICAL UI/UX REQUIREMENTS:
        - Every feature MUST have user-facing controllers and views, not just API endpoints
        - All new features MUST be accessible through the main navigation sidebar
        - Include tasks to update config/routes.rb with proper routing
        - Include tasks to update app/views/layouts/_sidebar.html.erb with navigation links
        - Create landing pages that work for default users (not just admins)
        - Update pages_controller.rb root action if needed to redirect users to new features
        - Ensure mobile-responsive design using DaisyUI components
        - Include tasks for user onboarding and feature discovery flows
        - Create proper user role-based access patterns
        - Include tasks for testing the complete user journey from login to feature usage

        REQUIRED UI TASK EXAMPLES (include similar tasks for this project):
        - "Create RecipesController with index, show, new, create actions for user interface"
        - "Create app/views/recipes/ directory with index.html.erb, show.html.erb, new.html.erb templates using DaisyUI"
        - "Add recipe routes to config/routes.rb: resources :recipes, only: [:index, :show, :new, :create]"
        - "Update app/views/layouts/_sidebar.html.erb to include Recipes navigation link with chef icon"
        - "Update pages_controller.rb root action to redirect default users to recipes_path instead of profile"
        - "Create recipe discovery landing page with search and filtering using DaisyUI components"
        - "Implement responsive design for mobile recipe viewing with touch-friendly controls"
      PROMPT
    end

    def read_readme_content
      readme_path = Rails.root.join("README.md")
      if File.exist?(readme_path)
        File.read(readme_path)
      else
        "README.md not found - using default Rails template features"
      end
    rescue => e
      Rails.logger.warn("Could not read README.md: #{e.message}")
      "Unable to load README.md content"
    end

    def call_llm_provider(prompt)
      adapter = Llm::AdapterFactory.create(provider: provider)

      start_time = Time.current
      response = adapter.chat(
        [ { "role" => "user", "content" => prompt } ],
        temperature: 0.7,
        max_tokens: 20000
      )
      processing_time = Time.current - start_time

      {
        success: true,
        content: response,
        model: adapter.model_name,
        token_count: estimate_tokens(prompt + response.to_s),
        cost: calculate_cost_from_tokens(estimate_tokens(prompt + response.to_s), provider),
        processing_time: processing_time
      }
    rescue => e
      {
        success: false,
        error: e.message
      }
    end

    def process_successful_generation(ai_generation, result)
      ai_generation.update!(
        status: "completed",
        raw_output: result[:content],
        model_used: result[:model],
        token_count: result[:token_count],
        cost: result[:cost],
        processing_time_seconds: result[:processing_time]
      )

      # Parse and structure the tasks
      structured_tasks = parse_tasks(result[:content])

      app_project.update!(
        generated_tasks: result[:content],
        status: "completed",
        generation_metadata: app_project.generation_metadata.merge(
          "tasks_generated_at" => Time.current.iso8601,
          "tasks_generation_id" => ai_generation.id,
          "tasks_provider" => provider,
          "tasks_model" => result[:model],
          "task_count" => structured_tasks[:total_tasks],
          "estimated_hours" => structured_tasks[:total_hours]
        )
      )
    end

    def process_failed_generation(ai_generation, result)
      ai_generation.update!(
        status: "failed",
        error_message: result[:error]
      )
    end

    def handle_generation_error(ai_generation, error)
      Rails.logger.error("Task Decomposition Error: #{error.message}")
      Rails.logger.error(error.backtrace.join("\n"))

      ai_generation.update!(
        status: "failed",
        error_message: "#{error.class}: #{error.message}"
      )
    end

    def parse_tasks(content)
      # Simple parsing to extract task metrics
      task_count = content.scan(/TASK-\d+/).uniq.count

      # Extract hours (looking for patterns like "8 hours", "2-4 hours", etc.)
      hours = content.scan(/(\d+(?:-\d+)?)\s*hours?/i).flatten.map do |h|
        if h.include?("-")
          # Take average of range
          low, high = h.split("-").map(&:to_i)
          (low + high) / 2.0
        else
          h.to_i
        end
      end.sum

      {
        total_tasks: task_count,
        total_hours: hours
      }
    end

    def estimate_tokens(text)
      # Rough estimation: ~4 characters per token for English text
      (text.length / 4.0).ceil
    end

    def calculate_cost_from_tokens(token_count, provider)
      # Calculate cost based on token count instead of usage hash
      case provider.to_s
      when "openai"
        token_count * 0.00002  # $0.02 per 1K tokens average
      when "claude"
        token_count * 0.00002  # $0.02 per 1K tokens average
      when "gemini"
        token_count * 0.000001  # $0.001 per 1K tokens
      else
        0.0
      end
    end

    def calculate_cost(usage, provider)
      case provider.to_s
      when "openai"
        input_cost = usage[:prompt_tokens] * 0.00001
        output_cost = usage[:completion_tokens] * 0.00003
        input_cost + output_cost
      when "claude"
        input_cost = usage[:prompt_tokens] * 0.00001
        output_cost = usage[:completion_tokens] * 0.00003
        input_cost + output_cost
      when "gemini"
        total_tokens = usage[:total_tokens] || (usage[:prompt_tokens] + usage[:completion_tokens])
        total_tokens * 0.000001
      else
        0.0
      end
    end
  end
end
