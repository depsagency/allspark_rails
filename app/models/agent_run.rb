# frozen_string_literal: true

class AgentRun < ApplicationRecord
  belongs_to :assistant
  belongs_to :user, optional: true
  
  # Status tracking
  enum :status, {
    pending: 0,
    running: 1,
    completed: 2,
    failed: 3,
    cancelled: 4
  }, default: :pending
  
  # Store run data
  store_accessor :metadata, :error_message, :duration_ms, :tokens_used, :tools_called
  
  # Validations
  validates :run_id, presence: true, uniqueness: true
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  
  # Start the run
  def start!
    update!(
      status: :running,
      started_at: Time.current
    )
  end
  
  # Complete the run
  def complete!(tokens: nil, tools: [])
    duration = started_at ? ((Time.current - started_at) * 1000).round : 0
    
    update!(
      status: :completed,
      completed_at: Time.current,
      duration_ms: duration,
      tokens_used: tokens,
      tools_called: tools
    )
  end
  
  # Fail the run
  def fail!(error_message)
    update!(
      status: :failed,
      completed_at: Time.current,
      error_message: error_message
    )
  end
  
  # Cancel the run
  def cancel!
    update!(
      status: :cancelled,
      completed_at: Time.current
    )
  end
  
  # Get all messages for this run
  def messages
    assistant.assistant_messages.where(run_id: run_id).order(:created_at)
  end
  
  # Check if run is active
  def active?
    pending? || running?
  end
  
  # Get duration in seconds
  def duration_seconds
    return nil unless duration_ms
    duration_ms / 1000.0
  end
end