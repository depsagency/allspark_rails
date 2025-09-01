# frozen_string_literal: true

class AiGeneration < ApplicationRecord
  # Associations
  belongs_to :app_project

  # Enums
  enum :status, {
    pending: "pending",
    completed: "completed",
    failed: "failed"
  }, default: :pending

  enum :generation_type, {
    prd: "prd",
    tasks: "tasks",
    prompts: "prompts",
    logo: "logo",
    marketing_page: "marketing_page",
    claude_md: "claude_md",
    analysis: "analysis",
    enhancement: "enhancement"
  }

  # Validations
  validates :generation_type, presence: true
  validates :llm_provider, presence: true
  validates :input_prompt, presence: true
  validates :cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :token_count, numericality: { greater_than: 0 }, allow_nil: true
  validates :processing_time_seconds, numericality: { greater_than: 0 }, allow_nil: true

  # Scopes
  scope :successful, -> { where(status: :completed) }
  scope :failed, -> { where(status: :failed) }
  scope :by_provider, ->(provider) { where(llm_provider: provider) }
  scope :by_type, ->(type) { where(generation_type: type) }
  scope :recent, -> { order(created_at: :desc) }

  # Cost calculation constants (cost per 1K tokens)
  PROVIDER_COSTS = {
    "openai" => {
      "gpt-4-turbo" => 0.02,
      "gpt-4o-mini" => 0.001,
      "gpt-4" => 0.03
    },
    "claude" => {
      "claude-3-5-sonnet-20241022" => 0.01,
      "claude-3-sonnet" => 0.01,
      "claude-3-haiku" => 0.005
    },
    "gemini" => {
      "gemini-1.5-flash" => 0.001,
      "gemini-pro" => 0.005
    }
  }.freeze

  def execute!
    update!(status: :pending, error_message: nil)

    start_time = Time.current

    begin
      service = LLM::AdapterService.new(provider: llm_provider)

      result = service.generate_text(
        prompt: input_prompt,
        model: model_used,
        max_tokens: determine_max_tokens
      )

      self.raw_output = result
      self.token_count = estimate_tokens(input_prompt + result.to_s)
      self.cost = calculate_cost
      self.processing_time_seconds = Time.current - start_time
      self.status = :completed

      save!
      result

    rescue => e
      self.processing_time_seconds = Time.current - start_time
      self.status = :failed
      self.error_message = e.message
      save!

      Rails.logger.error "AI Generation failed for #{id}: #{e.message}"
      raise e
    end
  end

  def successful?
    completed?
  end

  def cost_per_token
    return 0 if token_count.nil? || token_count.zero? || cost.nil?

    cost / token_count
  end

  def formatted_cost
    return "$0.00" if cost.nil?

    "$#{cost.round(4)}"
  end

  def duration_display
    return "N/A" if processing_time_seconds.nil?

    if processing_time_seconds < 60
      "#{processing_time_seconds.round(1)}s"
    else
      minutes = (processing_time_seconds / 60).floor
      seconds = (processing_time_seconds % 60).round
      "#{minutes}m #{seconds}s"
    end
  end

  def provider_display
    case llm_provider
    when "openai"
      "OpenAI"
    when "claude"
      "Anthropic Claude"
    when "gemini"
      "Google Gemini"
    else
      llm_provider.humanize
    end
  end

  def model_display
    model_used || "Default model"
  end

  def generation_type_display
    generation_type.humanize
  end

  private

  def estimate_tokens(text)
    # Rough estimation: ~4 characters per token for English text
    (text.length / 4.0).ceil
  end

  def calculate_cost
    return 0 if token_count.nil? || token_count.zero?

    provider_costs = PROVIDER_COSTS[llm_provider]
    return 0 unless provider_costs

    model_cost = provider_costs[model_used] || provider_costs.values.first
    return 0 unless model_cost

    # Cost is per 1K tokens
    (token_count / 1000.0) * model_cost
  end

  def determine_max_tokens
    case generation_type
    when "prd"
      8000
    when "tasks"
      4000
    when "prompts"
      2000
    when "logo"
      1000 # Logo prompts are shorter
    when "marketing_page"
      4000 # Marketing pages need substantial content
    when "claude_md"
      6000 # CLAUDE.md files need comprehensive content
    when "analysis", "enhancement"
      1000
    else
      2000
    end
  end
end
