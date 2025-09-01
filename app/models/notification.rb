# frozen_string_literal: true

# Notification model for real-time notifications system
#
# Handles various types of notifications with real-time delivery
# via ActionCable and optional persistence
#
class Notification < ApplicationRecord
  include LiveUpdates

  belongs_to :user
  belongs_to :sender, class_name: "User", optional: true

  validates :title, presence: true, length: { maximum: 255 }
  validates :message, presence: true, length: { maximum: 1000 }
  validates :notification_type, presence: true
  validates :priority, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }

  enum :notification_type, {
    info: "info",
    success: "success",
    warning: "warning",
    error: "error",
    system: "system",
    mention: "mention",
    follow: "follow",
    like: "like",
    comment: "comment",
    message: "message",
    task_assigned: "task_assigned",
    task_completed: "task_completed",
    deadline_reminder: "deadline_reminder",
    system_maintenance: "system_maintenance",
    security_alert: "security_alert"
  }

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_priority, -> { order(priority: :desc, created_at: :desc) }
  scope :unexpired, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :for_user, ->(user) { where(user: user) }
  scope :of_type, ->(type) { where(notification_type: type) }

  # Callbacks
  after_create :broadcast_notification
  after_update :broadcast_update, if: :saved_change_to_read_at?
  before_save :set_delivered_at, if: :will_save_change_to_id?

  class << self
    # Create and deliver notification
    def create_and_deliver!(attributes)
      notification = create!(attributes)
      notification.deliver_now
      notification
    end

    # Create notification for multiple users
    def create_for_users(users, attributes)
      notifications = []

      Array(users).each do |user|
        notifications << create!(attributes.merge(user: user))
      end

      notifications
    end

    # Create system announcement for all users
    def create_system_announcement(title:, message:, **options)
      User.find_each do |user|
        create!(
          user: user,
          title: title,
          message: message,
          notification_type: :system,
          persistent: true,
          priority: 8,
          **options
        )
      end
    end

    # Cleanup expired notifications
    def cleanup_expired
      expired = where("expires_at < ?", Time.current)
      count = expired.count
      expired.delete_all
      Rails.logger.info "Cleaned up #{count} expired notifications"
      count
    end

    # Mark old notifications as read
    def mark_old_as_read(older_than: 30.days.ago)
      unread.where("created_at < ?", older_than).update_all(
        read_at: Time.current,
        updated_at: Time.current
      )
    end
  end

  # Instance methods
  def read?
    read_at.present?
  end

  def unread?
    !read?
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def mark_as_read!
    return if read?

    update!(read_at: Time.current)
  end

  def mark_as_unread!
    return unless read?

    update!(read_at: nil)
  end

  def deliver_now
    return if delivered_at.present?

    # Mark as delivered
    update_column(:delivered_at, Time.current)

    # Broadcast via ActionCable
    broadcast_notification

    # Additional delivery methods can be added here:
    # - Email notifications
    # - Push notifications
    # - SMS notifications
  end

  def icon
    case notification_type
    when "success"
      "✅"
    when "warning"
      "⚠️"
    when "error"
      "❌"
    when "info"
      "ℹ️"
    when "system"
      "🔧"
    when "mention"
      "👤"
    when "follow"
      "👥"
    when "like"
      "❤️"
    when "comment"
      "💬"
    when "message"
      "📩"
    when "task_assigned"
      "📋"
    when "task_completed"
      "✅"
    when "deadline_reminder"
      "⏰"
    when "system_maintenance"
      "🔧"
    when "security_alert"
      "🔒"
    else
      "📱"
    end
  end

  def color_class
    case notification_type
    when "success", "task_completed"
      "text-success"
    when "warning", "deadline_reminder"
      "text-warning"
    when "error", "security_alert"
      "text-error"
    when "info"
      "text-info"
    when "system", "system_maintenance"
      "text-base-content"
    else
      "text-primary"
    end
  end

  def time_ago
    return "just now" unless created_at.present?

    if created_at > 1.day.ago
      "#{ActionController::Base.helpers.time_ago_in_words(created_at)} ago"
    else
      created_at.strftime("%m/%d/%Y at %I:%M %p")
    end
  end

  private

  def broadcast_notification
    return unless user.present?

    ActionCable.server.broadcast(
      "user_#{user.id}_notifications",
      {
        type: "new_notification",
        notification: serialize_for_broadcast,
        unread_count: user.notifications.unread.count
      }
    )
  end

  def broadcast_update
    return unless user.present?

    ActionCable.server.broadcast(
      "user_#{user.id}_notifications",
      {
        type: "notification_updated",
        notification_id: id,
        read: read?,
        unread_count: user.notifications.unread.count
      }
    )
  end

  def set_delivered_at
    self.delivered_at ||= Time.current
  end

  def serialize_for_broadcast
    {
      id: id,
      title: title,
      message: message,
      type: notification_type,
      icon: icon,
      color_class: color_class,
      read: read?,
      time_ago: time_ago,
      created_at: created_at.iso8601,
      action_url: action_url,
      metadata: metadata,
      sender: sender ? {
        id: sender.id,
        name: sender.full_name,
        avatar_url: sender.avatar.attached? ? Rails.application.routes.url_helpers.url_for(sender.avatar) : nil
      } : nil
    }
  end
end
