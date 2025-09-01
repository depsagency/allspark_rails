# frozen_string_literal: true

# Job for cleaning up old and expired notifications
#
# Runs periodically to:
# - Remove expired notifications
# - Mark old notifications as read
# - Clean up orphaned notification data
#
class NotificationsCleanupJob < ApplicationJob
  queue_as :low

  def perform
    Rails.logger.info "Starting notifications cleanup..."

    expired_count = cleanup_expired_notifications
    old_count = mark_old_notifications_as_read

    Rails.logger.info "Notifications cleanup completed: #{expired_count} expired, #{old_count} marked as read"

    # Update metrics if available
    if defined?(Rails.cache)
      Rails.cache.write("notifications_cleanup_last_run", Time.current, expires_in: 1.week)
      Rails.cache.write("notifications_cleanup_stats", {
        expired_count: expired_count,
        old_count: old_count,
        last_run: Time.current
      }, expires_in: 1.week)
    end
  end

  private

  def cleanup_expired_notifications
    Notification.cleanup_expired
  end

  def mark_old_notifications_as_read
    # Mark notifications older than 30 days as read
    Notification.mark_old_as_read(older_than: 30.days.ago)
  end
end
