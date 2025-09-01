# frozen_string_literal: true

class AssistantMessage < ApplicationRecord
  # Associations
  belongs_to :assistant
  
  # Validations
  validates :role, presence: true, inclusion: { in: %w[system user assistant tool] }
  
  # Scopes
  scope :by_role, ->(role) { where(role: role) }
  scope :for_run, ->(run_id) { where(run_id: run_id) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Check if message has tool calls
  def has_tool_calls?
    tool_calls.present? && tool_calls.any?
  end
  
  # Format for LangChain
  def to_langchain_format
    {
      role: role,
      content: content,
      tool_calls: tool_calls,
      tool_call_id: tool_call_id
    }.compact
  end
end
