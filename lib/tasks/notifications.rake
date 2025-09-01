# frozen_string_literal: true

namespace :notifications do
  desc "Clean up expired and old notifications"
  task cleanup: :environment do
    puts "Starting notifications cleanup..."

    expired_count = Notification.cleanup_expired
    puts "Removed #{expired_count} expired notifications"

    old_count = Notification.mark_old_as_read(older_than: 30.days.ago)
    puts "Marked #{old_count} old notifications as read"

    puts "Notifications cleanup completed!"
  end

  desc "Send test notification to a user"
  task :send_test, [ :user_email ] => :environment do |task, args|
    user_email = args[:user_email]

    if user_email.blank?
      puts "Usage: rake notifications:send_test[user@example.com]"
      exit 1
    end

    user = User.find_by(email: user_email)
    unless user
      puts "User with email '#{user_email}' not found"
      exit 1
    end

    notification = Notification.create!(
      user: user,
      title: "Test Notification",
      message: "This is a test notification sent via rake task.",
      notification_type: "info"
    )

    puts "Test notification sent to #{user.email} (ID: #{notification.id})"
  end

  desc "Send system announcement to all users"
  task :send_announcement, [ :title, :message ] => :environment do |task, args|
    title = args[:title] || "System Announcement"
    message = args[:message] || "This is a system announcement."

    notifications = Notification.create_system_announcement(
      title: title,
      message: message
    )

    puts "System announcement sent to #{notifications.count} users"
    puts "Title: #{title}"
    puts "Message: #{message}"
  end

  desc "Show notification statistics"
  task stats: :environment do
    total = Notification.count
    unread = Notification.unread.count
    read = Notification.read.count
    expired = Notification.where("expires_at < ?", Time.current).count

    puts "Notification Statistics:"
    puts "======================"
    puts "Total notifications: #{total}"
    puts "Unread notifications: #{unread}"
    puts "Read notifications: #{read}"
    puts "Expired notifications: #{expired}"
    puts ""

    # Top notification types
    puts "Top notification types:"
    Notification.group(:notification_type).count.each do |type, count|
      puts "  #{type}: #{count}"
    end
    puts ""

    # Recent activity
    recent = Notification.where("created_at > ?", 24.hours.ago).count
    puts "Notifications sent in last 24 hours: #{recent}"
  end

  desc "Mark all notifications as read for a user"
  task :mark_all_read, [ :user_email ] => :environment do |task, args|
    user_email = args[:user_email]

    if user_email.blank?
      puts "Usage: rake notifications:mark_all_read[user@example.com]"
      exit 1
    end

    user = User.find_by(email: user_email)
    unless user
      puts "User with email '#{user_email}' not found"
      exit 1
    end

    count = user.notifications.unread.update_all(read_at: Time.current)
    puts "Marked #{count} notifications as read for #{user.email}"
  end

  desc "Delete all notifications for a user"
  task :delete_all, [ :user_email ] => :environment do |task, args|
    user_email = args[:user_email]

    if user_email.blank?
      puts "Usage: rake notifications:delete_all[user@example.com]"
      exit 1
    end

    user = User.find_by(email: user_email)
    unless user
      puts "User with email '#{user_email}' not found"
      exit 1
    end

    count = user.notifications.count
    user.notifications.destroy_all
    puts "Deleted #{count} notifications for #{user.email}"
  end

  desc "Test real-time broadcasting"
  task :test_broadcast, [ :user_email ] => :environment do |task, args|
    user_email = args[:user_email]

    if user_email.blank?
      puts "Usage: rake notifications:test_broadcast[user@example.com]"
      exit 1
    end

    user = User.find_by(email: user_email)
    unless user
      puts "User with email '#{user_email}' not found"
      exit 1
    end

    # Test notification broadcast
    notification = Notification.create!(
      user: user,
      title: "Broadcast Test",
      message: "Testing real-time notification broadcasting.",
      notification_type: "info"
    )

    # Test direct user update broadcast
    LiveUpdatesBroadcaster.broadcast_user_update(user, {
      type: "test_update",
      message: "Testing direct user update broadcasting",
      timestamp: Time.current.iso8601
    })

    # Test system announcement
    LiveUpdatesBroadcaster.broadcast_system_announcement(
      title: "Broadcast Test",
      message: "Testing system announcement broadcasting"
    )

    puts "Test broadcasts sent to #{user.email}"
    puts "Check the browser console and UI for real-time updates"
  end
end
