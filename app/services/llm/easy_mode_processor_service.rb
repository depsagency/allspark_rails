# frozen_string_literal: true

module Llm
  class EasyModeProcessorService
    def initialize(app_project, description)
      @app_project = app_project
      @description = description
      @adapter = AdapterFactory.create # Use default provider from config
    end

    def process!
      Rails.logger.info "Starting Easy Mode processing for project: #{@app_project.name}"

      begin
        # Generate structured responses from the description
        responses = generate_structured_responses

        # Update the app project with all responses
        update_project_responses(responses)

        # Mark processing as complete
        @app_project.update!(
          status: "draft",
          generation_metadata: @app_project.generation_metadata.merge(
            "easy_mode_completed_at" => Time.current.iso8601,
            "easy_mode_success" => true
          )
        )

        Rails.logger.info "Easy Mode processing completed successfully"
        true
      rescue => e
        Rails.logger.error "Easy Mode processing failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")

        @app_project.update!(
          status: "error",
          generation_metadata: @app_project.generation_metadata.merge(
            "easy_mode_error" => e.message,
            "easy_mode_failed_at" => Time.current.iso8601
          )
        )

        raise
      end
    end

    private

    def generate_structured_responses
      prompt = build_prompt

      Rails.logger.info "Sending Easy Mode prompt to #{@adapter.model_name} with max_tokens: 20000"

      response = @adapter.chat(
        [ { "role" => "user", "content" => prompt } ],
        temperature: 0.7,
        max_tokens: 20000
      )

      Rails.logger.info "Received response length: #{response&.length || 0} characters"

      # Track the generation
      provider_name = Rails.application.config.llm.provider
      @app_project.ai_generations.create!(
        generation_type: "analysis",
        llm_provider: provider_name,
        status: "completed",
        input_prompt: prompt,
        raw_output: response,
        model_used: @adapter.model_name,
        token_count: estimate_tokens(prompt + response.to_s),
        cost: calculate_cost_from_tokens(estimate_tokens(prompt + response.to_s), provider_name)
      )

      # Parse the JSON response
      parse_response(response)
    end

    def build_prompt
      <<~PROMPT
        You are an expert product manager and software architect. A user has provided a project description and you need to structure it into 10 specific categories for a comprehensive project blueprint.

        Project Name: #{@app_project.name}

        User's Description:
        #{@description}

        Please analyze this description and generate detailed responses for each of the following 10 categories. Your responses should be thorough, specific, and actionable.

        CRITICAL: You MUST return ONLY a valid JSON object with NO markdown formatting, NO code blocks, and NO additional text. The response should start with { and end with }

        Generate a JSON object with these exact keys and follow the guidance for each:

        1. "vision_response" - Application Vision
           Describe your application idea in detail. What problem does it solve and for whom?
           Example: A platform connecting freelance UX designers with small businesses that need affordable design help.
           Tips: Clearly explain the problem your app solves, describe your target audience, explain your unique value proposition.

        2. "users_response" - Target Users
           Who are your users? Describe the different types of people who will use your application.
           Example: Small business owners (25-45, tech-savvy, budget-conscious) and freelance designers (22-35, portfolio-focused).
           Create 2-3 detailed user personas with demographics, behaviors, needs, and pain points.

        3. "journeys_response" - User Journeys
           Walk me through the key user journeys. How do your users interact with your application from start to finish?
           Example: Business owners post projects → Designers submit proposals → Clients review and select → Project collaboration begins.
           Include at least 3 major user journeys with specific steps.

        4. "features_response" - Core Features
           What are the core features and functionality your application needs?
           Example: User profiles, project posting, portfolio galleries, messaging system, payment processing, rating system.
           Organize features by priority (MVP, Phase 2, Future).

        5. "technical_response" - Technical Requirements
           Describe your technical requirements and constraints.
           Example: Web-first responsive design, real-time messaging, file upload capabilities, mobile-optimized interface.
           Include platform requirements, performance needs, scalability considerations.

        6. "integrations_response" - Third-party Integrations
           What third-party services do you need to integrate with?
           Example: Stripe for payments, SendGrid for emails, AWS S3 for file storage, Google Analytics for tracking.
           List all external services, APIs, and tools needed.

        7. "success_response" - Success Metrics
           What does success look like for your application? How will you measure it?
           Example: 1000+ active users within 6 months, $10K monthly transaction volume, 4.5+ star user rating.
           Include specific numbers, KPIs, and timeframes.

        8. "competition_response" - Competition Analysis
           Are there any existing solutions or competitors? How is your application different?
           Example: Upwork and Fiverr exist but focus on broader services. We specialize in UX/UI design with better matching.
           Analyze market gaps and competitive advantages.

        9. "design_response" - Design Requirements
           Describe any specific design or user experience requirements.
           Example: Clean, modern interface. Portfolio-focused layouts. Mobile-first approach. Accessibility compliant.
           Include UI/UX principles, branding guidelines, and accessibility needs.

        10. "challenges_response" - Challenges & Concerns
            What are your biggest concerns or potential challenges for this project?
            Example: User acquisition, payment processing complexity, quality control for designers, mobile responsiveness.
            Address technical challenges, business risks, and mitigation strategies.

        Each response should be 150-200 words minimum, extracting and expanding on the user's description while inferring reasonable details where not specified.

        Remember: Return ONLY the JSON object, nothing else. Ensure all strings are properly escaped for JSON.
      PROMPT
    end

    def parse_response(response)
      # Clean the response to ensure it's valid JSON
      cleaned_response = response.strip

      # Remove any markdown code blocks if present
      cleaned_response = cleaned_response.gsub(/```json\n?/, "").gsub(/```\n?/, "")

      # Remove any text before the first { and after the last }
      json_start = cleaned_response.index("{")
      json_end = cleaned_response.rindex("}")

      if json_start && json_end && json_end > json_start
        cleaned_response = cleaned_response[json_start..json_end]
      end

      # Parse the JSON
      begin
        parsed = JSON.parse(cleaned_response)

        # Validate that all required fields are present
        required_fields = %w[
          vision_response users_response journeys_response features_response
          technical_response integrations_response success_response
          competition_response design_response challenges_response
        ]

        missing_fields = required_fields - parsed.keys
        if missing_fields.any?
          Rails.logger.warn "Missing fields in Gemini response: #{missing_fields.join(', ')}"
          # Fill in missing fields with defaults
          missing_fields.each do |field|
            parsed[field] = generate_fallback_response(field)
          end
        end

        parsed
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse Gemini response as JSON: #{e.message}"
        Rails.logger.error "Response length: #{response.length} characters"
        Rails.logger.error "First 500 chars: #{response[0..500]}..."
        Rails.logger.error "Last 500 chars: #{response[-500..-1]}..." if response.length > 500

        # Fallback: try to extract key-value pairs manually
        fallback_parse(response)
      end
    end

    def fallback_parse(response)
      # This is a fallback parser in case the JSON parsing fails
      result = {}

      # Define the fields we're looking for
      fields = %w[
        vision_response users_response journeys_response features_response
        technical_response integrations_response success_response
        competition_response design_response challenges_response
      ]

      fields.each do |field|
        # Try multiple patterns to extract content
        patterns = [
          /"#{field}":\s*"([^"\\]*(\\.[^"\\]*)*)"/m,  # Standard JSON string
          /"#{field}":\s*'([^'\\]*(\\.[^'\\]*)*)'/m,  # Single quotes (non-standard)
          /#{field}['":\s]+([^,}\]]+)/m               # More flexible pattern
        ]

        content = nil
        patterns.each do |pattern|
          match = response.match(pattern)
          if match
            content = match[1]
            # Unescape common JSON escapes
            content = content.gsub(/\\n/, "\n")
                           .gsub(/\\r/, "\r")
                           .gsub(/\\t/, "\t")
                           .gsub(/\\"/, '"')
                           .gsub(/\\\\/, "\\")
            break
          end
        end

        result[field] = content || generate_fallback_response(field)
      end

      extracted_count = result.count { |k, v| v != generate_fallback_response(k) }
      Rails.logger.info "Fallback parser extracted #{extracted_count} fields successfully"
      result
    end

    def generate_fallback_response(field)
      case field
      when "vision_response"
        "Based on the provided description: #{@description[0..200]}..."
      when "users_response"
        "Target users need to be identified based on the project description."
      when "journeys_response"
        "User journeys will be defined based on the core features and user needs."
      when "features_response"
        "Core features include those mentioned in the project description."
      when "technical_response"
        "Technical requirements will be determined based on the project scope."
      when "integrations_response"
        "Third-party integrations will be identified based on feature requirements."
      when "success_response"
        "Success metrics will be defined based on project goals."
      when "competition_response"
        "Competitive analysis pending further market research."
      when "design_response"
        "Design requirements will follow modern UI/UX best practices."
      when "challenges_response"
        "Potential challenges will be identified during the planning phase."
      else
        "To be determined based on project requirements."
      end
    end

    def update_project_responses(responses)
      update_params = {}

      # Map the responses to the project fields
      %w[
        vision_response users_response journeys_response features_response
        technical_response integrations_response success_response
        competition_response design_response challenges_response
      ].each do |field|
        update_params[field] = responses[field] if responses[field].present?
      end

      # Update the project
      @app_project.update!(update_params)

      Rails.logger.info "Updated project with #{update_params.keys.count} fields from Easy Mode"
    end

    def estimate_tokens(text)
      # Rough estimation: ~4 characters per token for English text
      (text.length / 4.0).ceil
    end

    def calculate_cost_from_tokens(token_count, provider)
      # Calculate cost based on token count
      case provider.to_s
      when "gemini"
        token_count * 0.000001  # $0.001 per 1K tokens
      else
        0.0
      end
    end
  end
end
