# frozen_string_literal: true

class AgentTeamExecution < ApplicationRecord
  belongs_to :agent_team
  
  # Status enum
  enum :status, {
    pending: 0,
    running: 1,
    completed: 2,
    failed: 3,
    cancelled: 4
  }, default: :pending
  
  # Validations
  validates :task, presence: true
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { completed }
  
  # Calculate duration
  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end
  
  # Get summary of results
  def summary
    return nil unless result_data.present?
    
    {
      total_steps: result_data['plan']&.dig('steps')&.size || 0,
      completed_steps: result_data['results']&.count { |r| r['status'] == 'completed' } || 0,
      agents_used: result_data['results']&.map { |r| r['agent'] }&.uniq || []
    }
  end
end