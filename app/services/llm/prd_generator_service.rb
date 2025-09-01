module Llm
  class PrdGeneratorService
    include ActiveModel::Model

    attr_accessor :app_project, :provider

    validates :app_project, presence: true

    PRD_SECTIONS = [
      :executive_summary,
      :vision_and_objectives,
      :target_users,
      :user_journeys,
      :functional_requirements,
      :technical_requirements,
      :integrations,
      :success_metrics,
      :competitive_analysis,
      :design_requirements,
      :risks_and_challenges,
      :implementation_timeline,
      :data_requirements,
      :security_compliance,
      :glossary
    ].freeze

    def initialize(app_project:, provider: nil)
      @app_project = app_project
      @provider = provider || "gemini"  # Default to Gemini 2.5 Pro for PRD generation
    end

    def generate
      return false unless valid?
      return false unless app_project.ready_for_generation?

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
        generation_type: "prd",
        llm_provider: provider,
        status: "pending",
        input_prompt: prompt,
        raw_output: nil
      )
    end

    def build_prompt
      <<~PROMPT
        You are an expert product manager and technical architect. Generate a comprehensive Product Requirements Document (PRD) based on the following user responses to our application questionnaire.

        IMPORTANT: This application will be built as an extension of an existing Rails 8.0 starter template. You MUST consider the existing technical infrastructure and leverage built-in components, patterns, and capabilities wherever possible.

        PROJECT: #{app_project.name}

        EXISTING TECHNICAL INFRASTRUCTURE (MUST LEVERAGE):

        **Core Technology Stack:**
        - Rails 8.0 with esbuild for modern JavaScript bundling
        - PostgreSQL database with UUID primary keys (all new models must use UUIDs)
        - Redis for caching, sessions, and background job queues
        - Sidekiq for background job processing
        - Devise for user authentication and authorization (already configured)
        - ActionCable for real-time features and WebSocket connections

        **Frontend & Styling (REQUIRED TO USE):**
        - DaisyUI + Tailwind CSS styling framework (all UI must use DaisyUI components)
        - ViewComponent architecture for reusable UI components
        - Available UI Components: Alert, Badge, Button, Card, Checkbox, DataTable, Input, Modal, Select, ThemeSwitcher, Navbar
        - Responsive design patterns already implemented
        - Theme switching capabilities built-in

        **Built-in Generators (MUST USE WHEN APPLICABLE):**
        - `rails generate scaffold` - Creates DaisyUI-styled CRUD interfaces
        - `rails generate api_controller` - For API endpoints
        - `rails generate service` - For business logic service objects
        - `rails generate ai_model` - For AI-enhanced models with descriptions

        **Architecture Patterns (REQUIRED):**
        - Service Objects: All complex business logic must use service objects (app/services/)
        - Background Jobs: Use Sidekiq jobs for async processing (app/jobs/)
        - ViewComponents: Use existing UI components, extend when needed
        - UUID Primary Keys: All new models must use UUID primary keys
        - Rails Concerns: Use concerns for shared model/controller behavior

        **AI/LLM Integration (AVAILABLE):**
        - Multi-provider LLM support (OpenAI, Claude, Gemini) already configured
        - LLM adapter pattern for consistent AI integration
        - Background AI processing capabilities
        - Cost tracking and usage monitoring built-in

        **Development & Quality Tools (BUILT-IN):**
        - RuboCop for code style enforcement
        - Brakeman for security scanning
        - Bundle audit for dependency security
        - Comprehensive test suite setup (use existing patterns)
        - Docker configuration available
        - CI/CD pipeline templates provided

        **Production-Ready Component Library (REQUIRED TO USE):**
        - 15+ ViewComponents with DaisyUI styling: Button, Card, Alert, Badge, Modal, DataTable, Input, Select, Checkbox, Navbar, Progress, Avatar, Breadcrumb, Pagination, Tabs
        - Lookbook documentation system for component previews
        - Component generators for rapid UI development: `rails generate ui_component NAME --variants=variant1,variant2 --with-stimulus`
        - Stimulus controllers for interactive behavior
        - Comprehensive testing suite for all components

        **Advanced Theme System (BUILT-IN):**
        - 30+ DaisyUI themes with instant switching
        - Theme persistence across sessions
        - System theme detection (light/dark mode)
        - CSS custom properties for theme-aware styling
        - Theme switcher components with multiple variants

        **Real-time Features (AVAILABLE):**
        - ActionCable infrastructure for WebSocket connections
        - Live notifications with read/unread tracking
        - Presence system for user online/offline status
        - Real-time updates with progress tracking
        - Collaborative editing support

        **Available Features (LEVERAGE WHEN RELEVANT):**
        - User authentication & role-based access control (Devise + Pundit)
        - Feature flags system with application configuration
        - Performance monitoring with request timing and memory tracking
        - Error tracking with context and automatic reporting
        - Event analytics ready for Ahoy/Blazer integration
        - File upload handling (Active Storage with S3 support)
        - Rich text editing (TinyMCE integration)
        - Google Workspace Integration (Drive, Gmail, Calendar APIs)
        - Health monitoring with system checks and metrics
        - Background processing with Sidekiq job monitoring

        **Quality & Testing Infrastructure (BUILT-IN):**
        - Comprehensive RSpec suite with FactoryBot and SimpleCov
        - System testing with Capybara for real-time features
        - Component testing with ViewComponent test helpers
        - Code quality tools: RuboCop, Brakeman, Bundle Audit
        - Maintenance tools for cleanup and optimization

        **Deployment & Infrastructure (READY):**
        - Docker configuration with multi-service setup
        - CI/CD pipeline templates for GitHub Actions
        - Heroku deployment configuration
        - Environment management with feature flags
        - Monitoring and health check endpoints

        USER RESPONSES:

        1. VISION & PURPOSE:
        #{app_project.vision_response}

        2. TARGET USERS:
        #{app_project.users_response}

        3. USER JOURNEYS:
        #{app_project.journeys_response}

        4. KEY FEATURES:
        #{app_project.features_response}

        5. TECHNICAL REQUIREMENTS:
        #{app_project.technical_response}

        6. INTEGRATIONS:
        #{app_project.integrations_response}

        7. SUCCESS METRICS:
        #{app_project.success_response}

        8. COMPETITION:
        #{app_project.competition_response}

        9. DESIGN & UX:
        #{app_project.design_response}

        10. CHALLENGES:
        #{app_project.challenges_response}

        Please generate a detailed PRD with the following sections:

        1. **Executive Summary** - A concise overview of the product vision, key objectives, and value proposition
        2. **Vision and Objectives** - Detailed product vision, goals, and strategic alignment
        3. **Target Users and Personas** - Comprehensive user profiles, demographics, and behaviors
        4. **User Journeys and Workflows** - Detailed user flows, scenarios, and interaction maps
        5. **Functional Requirements** - Complete feature list with priorities and dependencies
        6. **Technical Requirements** - Architecture, performance, scalability, and infrastructure needs
        7. **Integrations and APIs** - Third-party services, data flows, and API requirements
        8. **Success Metrics and KPIs** - Measurable goals, tracking methods, and success criteria
        9. **Competitive Analysis** - Market positioning, differentiators, and competitive advantages
        10. **Design and UX Requirements** - UI/UX principles, accessibility, and design system needs
        11. **Risks and Mitigation Strategies** - Technical, business, and user adoption risks
        12. **Implementation Timeline** - Phased approach with milestones and deliverables
        13. **Data Requirements** - Data models, storage, privacy, and compliance needs
        14. **Security and Compliance** - Security requirements, compliance standards, and best practices
        15. **Glossary and Appendices** - Technical terms, references, and supporting documentation

        CRITICAL TECHNICAL CONSTRAINTS AND REQUIREMENTS:

        1. **MUST USE EXISTING INFRASTRUCTURE**: All features must leverage the existing Rails template infrastructure. Do not recommend building from scratch what already exists.

        2. **COMPONENT-FIRST APPROACH**: Use existing ViewComponents and extend them rather than creating custom HTML/CSS. All UI must use DaisyUI classes and components.

        3. **SERVICE OBJECT PATTERN**: Complex business logic must be implemented as service objects using the existing generator pattern.

        4. **BACKGROUND PROCESSING**: Any heavy processing, email sending, or external API calls must use Sidekiq background jobs.

        5. **REAL-TIME FEATURES**: If the application requires real-time features, leverage the existing ActionCable infrastructure and patterns.

        6. **AUTHENTICATION & AUTHORIZATION**: Use the existing Devise authentication and extend with Pundit policies for authorization.

        7. **DATABASE DESIGN**: All new models must use UUID primary keys. Follow Rails conventions and use concerns for shared behavior.

        8. **TESTING STRATEGY**: Follow the existing test patterns with RSpec, FactoryBot, and component testing.

        9. **API DEVELOPMENT**: Use the existing API controller generator for any API endpoints.

        10. **DEPLOYMENT**: Leverage the existing Docker and Heroku deployment configurations.

        Format the response in clear markdown with proper headings, bullet points, and structured content. Focus on being specific, actionable, and comprehensive while maintaining clarity. Emphasize how existing template features can be leveraged and extended rather than rebuilt.
      PROMPT
    end

    def call_llm_provider(prompt)
      # Use the existing LLM adapter
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

      app_project.update!(
        generated_prd: result[:content],
        status: "completed",
        generation_metadata: app_project.generation_metadata.merge(
          "prd_generated_at" => Time.current.iso8601,
          "prd_generation_id" => ai_generation.id,
          "prd_provider" => provider,
          "prd_model" => result[:model]
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
      Rails.logger.error("PRD Generation Error: #{error.message}")
      Rails.logger.error(error.backtrace.join("\n"))

      ai_generation.update!(
        status: "failed",
        error_message: "#{error.class}: #{error.message}"
      )
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
      # Cost calculation based on provider and model
      # This is a simplified version - adjust based on actual pricing
      case provider.to_s
      when "openai"
        input_cost = usage[:prompt_tokens] * 0.00001  # $0.01 per 1K tokens
        output_cost = usage[:completion_tokens] * 0.00003  # $0.03 per 1K tokens
        input_cost + output_cost
      when "claude"
        input_cost = usage[:prompt_tokens] * 0.00001  # $0.01 per 1K tokens
        output_cost = usage[:completion_tokens] * 0.00003  # $0.03 per 1K tokens
        input_cost + output_cost
      when "gemini"
        total_tokens = usage[:total_tokens] || (usage[:prompt_tokens] + usage[:completion_tokens])
        total_tokens * 0.000001  # $0.001 per 1K tokens
      else
        0.0
      end
    end
  end
end
