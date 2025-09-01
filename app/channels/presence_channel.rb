# frozen_string_literal: true

# Presence channel for real-time user presence tracking
#
# Handles:
# - User online/offline status
# - Active users list
# - Typing indicators
# - User activity tracking
#
# Usage:
#   // JavaScript
#   consumer.subscriptions.create("PresenceChannel", {
#     received(data) {
#       // Handle presence updates
#     }
#   })
#
class PresenceChannel < ApplicationCable::Channel
  def subscribed
    return reject_subscription unless authorized?

    stream_from "presence"

    # Subscribe to common typing contexts
    stream_from "presence:demo_chat"

    # Add user to online users
    add_user_to_presence

    log_subscription

    # Broadcast user came online
    broadcast_presence_update("user_online", current_user)

    # Send current online users
    transmit({
      type: "online_users",
      users: online_users
    })
  end

  def unsubscribed
    # Remove user from presence
    remove_user_from_presence

    # Broadcast user went offline
    broadcast_presence_update("user_offline", current_user)

    log_subscription("unsubscribed")
  end

  # Update user activity
  def update_activity(data)
    activity = data["activity"] # 'active', 'away', 'busy'
    return unless %w[active away busy].include?(activity)

    update_user_presence(activity: activity)

    broadcast_presence_update("activity_changed", current_user, { activity: activity })
  end

  # Start typing indicator
  def start_typing(data)
    context = data["context"] # e.g., 'chat_room_123', 'comment_section_456'
    return unless context.present?

    broadcast_to_context(context, {
      type: "typing_start",
      user: user_info(current_user)
    })
  end

  # Stop typing indicator
  def stop_typing(data)
    context = data["context"]
    return unless context.present?

    broadcast_to_context(context, {
      type: "typing_stop",
      user: user_info(current_user)
    })
  end

  # Update user status message
  def update_status(data)
    status_message = data["status_message"]
    return if status_message && status_message.length > 100

    update_user_presence(status_message: status_message)

    broadcast_presence_update("status_changed", current_user, {
      status_message: status_message
    })
  end

  private

  def add_user_to_presence
    Rails.cache.write(
      presence_key(current_user),
      {
        user_id: current_user.id,
        connected_at: Time.current,
        last_seen: Time.current,
        activity: "active",
        status_message: nil
      },
      expires_in: 5.minutes
    )

    # Add user ID to online users list
    online_user_ids = Rails.cache.read("presence:online_user_ids") || []
    unless online_user_ids.include?(current_user.id)
      online_user_ids << current_user.id
      Rails.cache.write("presence:online_user_ids", online_user_ids, expires_in: 10.minutes)
    end
  end

  def remove_user_from_presence
    Rails.cache.delete(presence_key(current_user))

    # Remove user ID from online users list
    online_user_ids = Rails.cache.read("presence:online_user_ids") || []
    online_user_ids.delete(current_user.id)
    Rails.cache.write("presence:online_user_ids", online_user_ids, expires_in: 10.minutes)
  end

  def update_user_presence(updates = {})
    current_presence = Rails.cache.read(presence_key(current_user)) || {}

    updated_presence = current_presence.merge(updates).merge(
      last_seen: Time.current
    )

    Rails.cache.write(
      presence_key(current_user),
      updated_presence,
      expires_in: 5.minutes
    )
  end

  def online_users
    # Get all presence keys from cache
    # Since we can't easily pattern match in all cache stores, we'll track online user IDs
    online_user_ids = Rails.cache.read("presence:online_user_ids") || []

    users = []
    online_user_ids.each do |user_id|
      presence_key = "presence:user:#{user_id}"
      if presence_data = Rails.cache.read(presence_key)
        if user = User.find_by(id: presence_data[:user_id])
          users << user_info(user).merge(
            activity: presence_data[:activity],
            status_message: presence_data[:status_message],
            last_seen: presence_data[:last_seen]
          )
        end
      end
    end

    users.sort_by { |u| u[:last_seen] }.reverse
  end

  def broadcast_presence_update(event_type, user, extra_data = {})
    # Get current presence data for the user
    presence_data = Rails.cache.read(presence_key(user)) || {}
    user_data = user_info(user).merge(
      activity: presence_data[:activity] || "active",
      status_message: presence_data[:status_message],
      last_seen: presence_data[:last_seen] || Time.current
    )

    ActionCable.server.broadcast("presence", {
      type: event_type,
      user: user_data,
      timestamp: Time.current.iso8601,
      **extra_data
    })
  end

  def broadcast_to_context(context, data)
    ActionCable.server.broadcast("presence:#{context}", data)
  end

  def user_info(user)
    {
      id: user.id,
      name: user.full_name.presence || user.email.split("@").first.capitalize,
      email: user.email,
      avatar_url: user.avatar.attached? ? url_for(user.avatar) : nil,
      role: user.role
    }
  end

  def presence_key(user)
    "presence:user:#{user.id}"
  end
end
