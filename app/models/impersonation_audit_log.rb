# frozen_string_literal: true

class ImpersonationAuditLog < ApplicationRecord
  belongs_to :impersonator, class_name: 'User', foreign_key: 'impersonator_id'
  belongs_to :impersonated_user, class_name: 'User', foreign_key: 'impersonated_user_id'

  # Action types
  ACTIONS = {
    start: 'start',
    end: 'end',
    timeout: 'timeout',
    forced_end: 'forced_end'
  }.freeze

  validates :action, presence: true, inclusion: { in: ACTIONS.values }
  validates :ip_address, presence: true
  validates :user_agent, presence: true
  validates :session_id, presence: true
  validates :started_at, presence: true

  scope :recent, -> { order(started_at: :desc) }
  scope :active, -> { where(ended_at: nil) }
  scope :for_user, ->(user) { where(impersonated_user: user) }
  scope :by_impersonator, ->(user) { where(impersonator: user) }

  def active?
    ended_at.nil?
  end

  def duration
    return nil unless ended_at
    ended_at - started_at
  end

  def duration_in_words
    return 'Active' if active?
    return 'N/A' unless duration

    if duration < 60
      "#{duration.to_i} seconds"
    elsif duration < 3600
      "#{(duration / 60).to_i} minutes"
    else
      "#{(duration / 3600).to_i} hours"
    end
  end

  def self.create_start_log(impersonator:, impersonated_user:, request:, reason: nil)
    create!(
      impersonator: impersonator,
      impersonated_user: impersonated_user,
      action: ACTIONS[:start],
      reason: reason,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      session_id: request.session_options[:id],
      started_at: Time.current
    )
  end

  def end_impersonation!(reason: nil)
    return if ended_at.present?

    update!(
      ended_at: Time.current,
      metadata: metadata.merge(
        end_reason: reason || 'manual',
        duration: Time.current - started_at
      )
    )
  end
end
