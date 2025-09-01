# frozen_string_literal: true

# Notifications channel for real-time user notifications
#
# Handles:
# - Personal notifications for individual users
# - System-wide announcements
# - Real-time updates for notifications
#
# Usage:
#   // JavaScript
#   consumer.subscriptions.create("NotificationsChannel", {
#     received(data) {
#       // Handle notification
#     }
#   })
#
class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    return reject_subscription unless authorized?

    # Stream personal notifications
    stream_from user_stream_name(current_user, "notifications")

    # Stream system announcements if user is admin
    if current_user.system_admin?
      stream_from "system_announcements"
    end

    log_subscription

    # Send current unread count
    transmit({
      type: "unread_count",
      count: current_user.notifications.unread.count
    })
  end

  def unsubscribed
    log_subscription("unsubscribed")
  end

  # Mark notification as read
  def mark_as_read(data)
    notification_id = data["notification_id"]
    return unless notification_id

    notification = current_user.notifications.find_by(id: notification_id)
    if notification&.update(read_at: Time.current)
      transmit({
        type: "marked_as_read",
        notification_id: notification_id,
        unread_count: current_user.notifications.unread.count
      })
    end
  end

  # Mark all notifications as read
  def mark_all_as_read
    current_user.notifications.unread.update_all(read_at: Time.current)

    transmit({
      type: "all_marked_as_read",
      unread_count: 0
    })
  end

  # Get recent notifications
  def get_recent_notifications(data)
    limit = [ data["limit"]&.to_i || 20, 50 ].min

    notifications = current_user.notifications
                               .includes(:sender)
                               .recent
                               .limit(limit)

    transmit({
      type: "recent_notifications",
      notifications: notifications.map { |n| serialize_notification(n) }
    })
  end

  private

  def serialize_notification(notification)
    {
      id: notification.id,
      title: notification.title,
      message: notification.message,
      type: notification.notification_type,
      read: notification.read?,
      created_at: notification.created_at.iso8601,
      sender: notification.sender ? {
        id: notification.sender.id,
        name: notification.sender.full_name,
        avatar_url: notification.sender.avatar.attached? ? url_for(notification.sender.avatar) : nil
      } : nil,
      action_url: notification.action_url,
      metadata: notification.metadata
    }
  end
end
