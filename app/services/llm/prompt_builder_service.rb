module Llm
  class PromptBuilderService
    include ActiveModel::Model

    attr_accessor :app_project, :provider

    validates :app_project, presence: true

    PROMPT_TEMPLATES = {
      "rails_app" => "Generate a Rails application",
      "react_app" => "Generate a React application",
      "mobile_app" => "Generate a mobile application",
      "api_only" => "Generate an API-only backend",
      "full_stack" => "Generate a full-stack application"
    }.freeze

    def initialize(app_project:, provider: nil)
      @app_project = app_project
      @provider = provider || "gemini"  # Default to Gemini 2.5 Pro for prompt generation
    end

    def generate
      return false unless valid?
      return false unless app_project.generated_prd.present? && app_project.generated_tasks.present?

      # Create a simple, direct prompt without calling LLM
      prompt_content = build_simple_prompt

      # Create generation record for tracking
      ai_generation = app_project.ai_generations.create!(
        generation_type: "prompts",
        llm_provider: "none",
        status: "completed",
        input_prompt: "Simple prompt generation",
        raw_output: prompt_content,
        model_used: "template",
        token_count: 0,
        cost: 0.0,
        processing_time_seconds: 0.001
      )

      # Update app project
      app_project.update!(
        generated_claude_prompt: prompt_content,
        status: "completed",
        generation_metadata: app_project.generation_metadata.merge(
          "prompts_generated_at" => Time.current.iso8601,
          "prompts_generation_id" => ai_generation.id,
          "prompts_provider" => "template",
          "prompts_model" => "none",
          "prompt_count" => 1
        )
      )

      true
    rescue => e
      Rails.logger.error("Prompt Builder Error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      false
    end

    private

    def build_simple_prompt
      <<~PROMPT
Implement the #{app_project.name} application by following the Product Requirements Document (PRD) and Development Tasks list that have been provided.

Start with the first task and work through each task sequentially until the entire project is complete. Follow the technical specifications in the PRD and ensure each task is fully implemented before moving to the next.

If you need any clarification on requirements or run into technical decisions not covered in the documentation, please ask. The goal is to deliver a fully functional application that meets all the requirements specified in the PRD.
      PROMPT
    end

    # Removed unused methods - now using build_simple_prompt directly

    # Removed unused LLM methods - now using template-based generation

    def truncate_content(content, max_length)
      return "" if content.blank?

      if content.length > max_length
        "#{content[0...max_length]}...\n\n[Content truncated for prompt generation]"
      else
        content
      end
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
