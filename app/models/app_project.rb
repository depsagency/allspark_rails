# frozen_string_literal: true

class AppProject < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :ai_generations, dependent: :destroy
  has_one_attached :generated_logo
  belongs_to :generated_marketing_page, class_name: "Page", optional: true

  # Status enum for project lifecycle
  enum :status, {
    draft: "draft",
    generating: "generating",
    completed: "completed",
    error: "error"
  }, default: :draft
  
  # Project type enum
  enum :project_type, {
    project_kickoff: "project_kickoff",
    feature: "feature",
    bug: "bug",
    copy_edit: "copy_edit"
  }, default: :project_kickoff

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :slug, presence: true, uniqueness: true
  validates :user_id, presence: true
  validates :project_type, presence: true

  # Callbacks
  before_validation :generate_slug, if: -> { name.present? && slug.blank? }
  before_validation :update_slug, if: -> { name_changed? && persisted? }

  # Configuration response fields
  RESPONSE_FIELDS = %w[
    vision_response users_response journeys_response features_response
    technical_response integrations_response success_response competition_response
    design_response challenges_response
  ].freeze

  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :completed_projects, -> { where(status: :completed) }
  scope :recent, -> { order(updated_at: :desc) }
  scope :by_completion, -> { order(Arel.sql("(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) DESC, updated_at DESC")) }

  def completion_percentage
    completed_responses = RESPONSE_FIELDS.count { |field| send(field).present? }
    return 0 if RESPONSE_FIELDS.empty?

    (completed_responses.to_f / RESPONSE_FIELDS.count * 100).round
  end

  def ready_for_generation?
    completion_percentage >= 70
  end

  def can_generate?
    ready_for_generation? && (draft? || error?)
  end

  def all_responses
    RESPONSE_FIELDS.index_with { |field| send(field) }
  end

  def completed_responses
    all_responses.select { |_field, value| value.present? }
  end

  def missing_responses
    all_responses.select { |_field, value| value.blank? }.keys
  end

  def has_ai_outputs?
    generated_prd.present? || generated_tasks.present? || generated_claude_prompt.present? ||
      generated_logo.attached? || has_marketing_page? || has_claude_md?
  end

  def has_logo?
    attached = generated_logo.attached?
    url_present = generated_logo_url.present?
    data_present = logo_data.present?
    logo_generated = ai_generations.where(generation_type: "logo", status: "completed").exists?

    Rails.logger.debug "AppProject.has_logo? - attached: #{attached}, url_present: #{url_present}, data_present: #{data_present}, logo_generated: #{logo_generated}"

    attached || url_present || data_present || logo_generated
  end

  def logo_ready_for_generation?
    generated_prd.present?
  end

  def logo_generation_cost
    generation_metadata&.dig("logo_generation_metadata", "cost") || 0
  end

  def logo_generation_metadata
    generation_metadata&.dig("logo_generation_metadata") || {}
  end

  def has_marketing_page?
    generated_marketing_page.present? ||
      ai_generations.where(generation_type: "marketing_page", status: "completed").exists?
  end

  def marketing_page_ready_for_generation?
    generated_prd.present?
  end

  def marketing_page_generation_cost
    generation_metadata&.dig("marketing_page_metadata", "cost") || 0
  end

  def marketing_page_metadata
    generation_metadata&.dig("marketing_page_metadata") || {}
  end

  def has_claude_md?
    generated_claude_md.present? ||
      ai_generations.where(generation_type: "claude_md", status: "completed").exists?
  end

  def claude_md_ready_for_generation?
    generated_prd.present? && generated_tasks.present?
  end

  def claude_md_generation_cost
    generation_metadata&.dig("claude_md_metadata", "cost") || 0
  end

  def claude_md_metadata
    generation_metadata&.dig("claude_md_metadata") || {}
  end

  def generation_cost
    ai_generations.sum(:cost) || 0
  end

  def last_generation_at
    ai_generations.order(:created_at).last&.created_at
  end

  def generation_status_summary
    return "Not started" if ai_generations.empty?

    latest = ai_generations.order(:created_at).last
    case latest.status
    when "pending"
      "In progress..."
    when "completed"
      "Completed #{ActionController::Base.helpers.time_ago_in_words(latest.created_at)} ago"
    when "failed"
      "Generation failed"
    else
      "Unknown status"
    end
  end

  def trigger_generation!
    return false unless can_generate?

    update!(status: :generating)
    AppProjectGenerationJob.perform_later(id)
    true
  rescue => e
    update!(status: :error)
    Rails.logger.error "Failed to trigger generation for AppProject #{id}: #{e.message}"
    false
  end

  def mark_generation_complete!(prd:, tasks:, prompt:)
    update!(
      status: :completed,
      generated_prd: prd,
      generated_tasks: tasks,
      generated_claude_prompt: prompt,
      generation_metadata: generation_metadata.merge(
        completed_at: Time.current,
        version: (generation_metadata["version"] || 0) + 1
      )
    )
  end

  def mark_generation_failed!(error_message)
    update!(
      status: :error,
      generation_metadata: generation_metadata.merge(
        failed_at: Time.current,
        error: error_message
      )
    )
  end

  def to_param
    slug
  end

  private

  def generate_slug
    base_slug = name.parameterize
    candidate_slug = base_slug
    counter = 1

    while self.class.exists?(slug: candidate_slug)
      candidate_slug = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = candidate_slug
  end

  def update_slug
    generate_slug
  end
end
