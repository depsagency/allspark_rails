# frozen_string_literal: true

module Llm
  class MarketingPageGeneratorService
    include ActiveModel::Model
    include ActiveModel::Attributes

    # Custom error class
    class MarketingPageGenerationError < StandardError; end

    attribute :app_project
    attribute :provider, default: "gemini"
    attribute :target_audience
    attribute :tone, default: "professional"

    validates :app_project, presence: true
    validate :prd_must_exist

    def initialize(app_project:, provider: nil, target_audience: nil, tone: "professional")
      @app_project = app_project
      @provider = provider || "gemini"
      @target_audience = target_audience
      @tone = tone
    end

    def generate
      validate!

      ai_generation = create_generation_record

      begin
        prompt = build_marketing_prompt

        # Call Gemini 2.5 Pro API
        result = call_marketing_provider(prompt)

        if result.present?
          # Create the marketing page
          page = create_marketing_page(result)

          if page
            # Process successful generation
            process_successful_generation(ai_generation, result, page)
            true
          else
            # Handle page creation failure
            process_failed_generation(ai_generation, "Failed to create marketing page")
            false
          end
        else
          # Handle generation failure
          process_failed_generation(ai_generation, "Marketing content generation returned empty result")
          false
        end

      rescue => e
        process_failed_generation(ai_generation, e.message)
        false
      end
    end

    private

    attr_reader :app_project, :provider, :target_audience, :tone

    def validate!
      raise MarketingPageGenerationError, "App project is required" unless app_project
      raise MarketingPageGenerationError, "PRD must be generated before creating marketing page" unless app_project.generated_prd.present?
    end

    def prd_must_exist
      errors.add(:app_project, "must have a generated PRD") unless app_project&.generated_prd&.present?
    end

    def create_generation_record
      prompt = build_marketing_prompt
      app_project.ai_generations.create!(
        generation_type: "marketing_page",
        llm_provider: provider,
        status: "pending",
        input_prompt: prompt,
        raw_output: nil
      )
    end

    def build_marketing_prompt
      # Sophisticated prompt engineering for marketing page generation
      <<~PROMPT
        You are an expert marketing copywriter with 15+ years of experience in SaaS and tech product marketing. You specialize in conversion rate optimization, psychological triggers, and data-driven landing page design.

        CONTEXT:
        I need you to create compelling marketing copy for a landing page for this product:

        **Product Information:**
        #{extract_product_context}

        **Product Requirements Document:**
        #{app_project.generated_prd.truncate(3000)}

        **Target Audience:** #{determine_target_audience}
        **Tone:** #{tone.capitalize} but engaging and conversion-focused
        **Brand Context:** #{extract_brand_context}

        TASK:
        Create a complete marketing landing page with the following sections.#{' '}

        CRITICAL INSTRUCTIONS:
        1. Do NOT include any meta-commentary, explanations, or introductory text
        2. Do NOT mention that you are a copywriter or explain the task
        3. Start IMMEDIATELY with the hero section content
        4. Use "Get Started" as the primary CTA text throughout
        5. For logo placement, use the text: "LOGO_PLACEHOLDER_HERE" (this will be replaced automatically)

        Create these sections in clean Markdown format:

        ## Hero Section
        - Compelling headline (6-12 words, focuses on main benefit)
        - Supporting subheadline (explains value proposition in 1-2 sentences)
        - Primary CTA: "Get Started" button

        ## Value Proposition
        - Core benefits (3-4 key points with benefit-focused language)
        - What makes this solution unique
        - Main problem it solves

        ## How It Works
        - Simple 3-step process
        - Each step should be clear and actionable
        - Focus on ease of use

        ## Key Features
        - 4-6 feature highlights
        - Frame each as a benefit to the user
        - Include specific value propositions

        ## Social Proof Section
        - Framework for testimonials
        - Trust indicators
        - Success metrics or claims

        ## FAQ Section
        - 5-6 common questions potential customers would ask
        - Address objections and concerns
        - Provide clear, helpful answers

        ## Final Call to Action
        - Strong conversion-focused section
        - Reinforce main benefit
        - "Get Started" CTA

        REQUIREMENTS:
        - Write for #{determine_target_audience}
        - Use #{tone} tone but keep it engaging
        - Focus on benefits over features
        - Include psychological triggers (urgency, social proof, authority)
        - Optimize for conversions and sign-ups
        - Make it mobile-friendly
        - Use action-oriented language
        - Address pain points from the PRD
        - NO meta-text, explanations, or introductory content
        - Start directly with marketing content

        OUTPUT FORMAT:
        Provide ONLY the marketing page content in clean Markdown. Start immediately with the hero section. Do not include any preamble, explanations, or commentary.
      PROMPT
    end

    def extract_product_context
      context = []
      context << "**Name:** #{app_project.name}"
      context << "**Vision:** #{app_project.vision_response}" if app_project.vision_response.present?
      context << "**Target Users:** #{app_project.users_response}" if app_project.users_response.present?
      context << "**Key Features:** #{app_project.features_response}" if app_project.features_response.present?
      context << "**User Journeys:** #{app_project.journeys_response}" if app_project.journeys_response.present?
      context.join("\n")
    end

    def determine_target_audience
      return target_audience if target_audience.present?

      if app_project.users_response.present?
        app_project.users_response.truncate(200)
      else
        "professionals and businesses looking for efficient solutions"
      end
    end

    def extract_brand_context
      brand_info = []

      if app_project.has_logo?
        brand_info << "Professional logo available - incorporate prominently in hero section"
      end

      if app_project.design_response.present?
        brand_info << "Design preferences: #{app_project.design_response.truncate(100)}"
      end

      brand_info.any? ? brand_info.join(". ") : "Clean, professional, modern tech brand"
    end

    def call_marketing_provider(prompt)
      case provider
      when "gemini"
        call_gemini_api(prompt)
      else
        raise MarketingPageGenerationError, "Unsupported provider: #{provider}"
      end
    end

    def call_gemini_api(prompt)
      adapter = Llm::AdapterFactory.create # Use default provider from config

      Rails.logger.info "Generating marketing page with #{adapter.model_name}, prompt length: #{prompt.length}"

      start_time = Time.current
      result = adapter.generate(
        prompt,
        max_tokens: 20000,
        temperature: 0.7
      )
      processing_time = Time.current - start_time

      Rails.logger.info "Marketing page generation successful, processing time: #{processing_time}s"

      {
        content: result,
        model: "gemini-2.5-pro",
        cost: calculate_cost(prompt.length, result&.length || 0),
        processing_time: processing_time
      }
    end

    def calculate_cost(input_tokens, output_tokens)
      # Gemini 2.5 Pro pricing estimation
      # Input: ~$1.25 per 1M tokens, Output: ~$2.50 per 1M tokens
      input_cost = (input_tokens / 1_000_000.0) * 1.25
      output_cost = (output_tokens / 1_000_000.0) * 2.50
      input_cost + output_cost
    end

    def create_marketing_page(result)
      content = result[:content]
      return nil unless content.present?

      # Update existing page or create new one
      if app_project.generated_marketing_page.present?
        # Update existing page content
        page = app_project.generated_marketing_page
        page.update!(content: content)
        Rails.logger.info "Updated existing marketing page with ID: #{page.id}"
      else
        # Create a new Page record for the marketing content
        page = Page.create!(
          title: "#{app_project.name} - Marketing Page",
          content: content
        )

        # Link it to the app project
        app_project.update!(generated_marketing_page: page)
        Rails.logger.info "Created new marketing page with ID: #{page.id}"
      end

      page
    rescue => e
      Rails.logger.error "Failed to create/update marketing page: #{e.message}"
      nil
    end

    def process_successful_generation(ai_generation, result, page)
      ai_generation.update!(
        status: "completed",
        raw_output: result[:content],
        model_used: result[:model] || "gemini-2.5-pro",
        cost: result[:cost] || 0.0,
        processing_time_seconds: result[:processing_time] || 0.0
      )

      app_project.update!(
        marketing_page_prompt: ai_generation.input_prompt,
        marketing_page_metadata: {
          "generated_at" => Time.current.iso8601,
          "model" => result[:model] || "gemini-2.5-pro",
          "cost" => result[:cost] || 0.0,
          "processing_time" => result[:processing_time] || 0.0,
          "page_id" => page.id,
          "ai_generation_id" => ai_generation.id,
          "target_audience" => target_audience,
          "tone" => tone
        }
      )

      Rails.logger.info "Successfully generated marketing page for app_project #{app_project.id}"
    end

    def process_failed_generation(ai_generation, error_message)
      ai_generation.update!(
        status: "failed",
        error_message: error_message
      )

      Rails.logger.error "Marketing page generation failed for app_project #{app_project.id}: #{error_message}"
    end
  end
end
