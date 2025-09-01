# frozen_string_literal: true

# Live updates channel for real-time data synchronization
#
# Handles:
# - Model updates (create, update, delete)
# - Live data feeds
# - Collaborative editing
# - Real-time dashboard updates
#
# Usage:
#   // JavaScript
#   consumer.subscriptions.create("LiveUpdatesChannel", {
#     received(data) {
#       // Handle live updates
#     }
#   })
#
class LiveUpdatesChannel < ApplicationCable::Channel
  def subscribed
    return reject_subscription unless authorized?

    log_subscription
  end

  def unsubscribed
    log_subscription("unsubscribed")
  end

  # Subscribe to a specific resource
  def follow_resource(data)
    resource_type = data["resource_type"]
    resource_id = data["resource_id"]

    return unless valid_resource_type?(resource_type)
    return unless authorized_for_resource?(resource_type, resource_id)

    stream_name = "#{resource_type}_#{resource_id}_updates"
    stream_from stream_name

    transmit({
      type: "subscribed_to_resource",
      resource_type: resource_type,
      resource_id: resource_id,
      stream: stream_name
    })
  end

  # Unsubscribe from a specific resource
  def unfollow_resource(data)
    resource_type = data["resource_type"]
    resource_id = data["resource_id"]

    return unless valid_resource_type?(resource_type)

    stream_name = "#{resource_type}_#{resource_id}_updates"
    stop_stream_from stream_name

    transmit({
      type: "unsubscribed_from_resource",
      resource_type: resource_type,
      resource_id: resource_id,
      stream: stream_name
    })
  end

  # Subscribe to global updates for a model type
  def follow_model(data)
    model_type = data["model_type"]

    return unless valid_resource_type?(model_type)
    return unless authorized_for_model?(model_type)

    stream_name = "#{model_type.pluralize}_updates"
    stream_from stream_name

    transmit({
      type: "subscribed_to_model",
      model_type: model_type,
      stream: stream_name
    })
  end

  # Unsubscribe from global model updates
  def unfollow_model(data)
    model_type = data["model_type"]

    return unless valid_resource_type?(model_type)

    stream_name = "#{model_type.pluralize}_updates"
    stop_stream_from stream_name

    transmit({
      type: "unsubscribed_from_model",
      model_type: model_type,
      stream: stream_name
    })
  end

  # Subscribe to user-specific updates
  def follow_user_updates
    stream_from user_stream_name(current_user, "updates")

    transmit({
      type: "subscribed_to_user_updates",
      user_id: current_user.id
    })
  end

  # Real-time collaboration - cursor position updates
  def update_cursor_position(data)
    resource_type = data["resource_type"]
    resource_id = data["resource_id"]
    position = data["position"]

    return unless valid_resource_type?(resource_type)
    return unless authorized_for_resource?(resource_type, resource_id)

    # Broadcast cursor position to other collaborators
    ActionCable.server.broadcast(
      "#{resource_type}_#{resource_id}_collaboration",
      {
        type: "cursor_update",
        user: {
          id: current_user.id,
          name: current_user.full_name,
          color: user_cursor_color
        },
        position: position,
        timestamp: Time.current.iso8601
      }
    )
  end

  # Real-time collaboration - selection updates
  def update_selection(data)
    resource_type = data["resource_type"]
    resource_id = data["resource_id"]
    selection = data["selection"]

    return unless valid_resource_type?(resource_type)
    return unless authorized_for_resource?(resource_type, resource_id)

    # Broadcast selection to other collaborators
    ActionCable.server.broadcast(
      "#{resource_type}_#{resource_id}_collaboration",
      {
        type: "selection_update",
        user: {
          id: current_user.id,
          name: current_user.full_name,
          color: user_cursor_color
        },
        selection: selection,
        timestamp: Time.current.iso8601
      }
    )
  end

  private

  def valid_resource_type?(resource_type)
    # Define allowed resource types for security
    allowed_types = %w[
      user
      notification
      document
      project
      task
      comment
      file
    ]

    allowed_types.include?(resource_type.to_s.downcase)
  end

  def authorized_for_resource?(resource_type, resource_id)
    # Basic authorization - implement more sophisticated logic as needed
    return true if current_user.system_admin?

    case resource_type.downcase
    when "user"
      # Users can only access their own updates
      resource_id.to_s == current_user.id.to_s
    when "notification"
      # Users can only access their own notifications
      notification = Notification.find_by(id: resource_id)
      notification&.user_id == current_user.id
    else
      # For other resources, implement specific authorization logic
      # For now, allow all authenticated users
      true
    end
  end

  def authorized_for_model?(model_type)
    # Basic model-level authorization
    return true if current_user.system_admin?

    case model_type.downcase
    when "user"
      # Only admins can see all user updates
      current_user.system_admin?
    else
      # For other models, allow all authenticated users
      true
    end
  end

  def user_cursor_color
    # Generate consistent color for user based on ID
    colors = [
      "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4",
      "#FECA57", "#FF9FF3", "#54A0FF", "#5F27CD",
      "#00D2D3", "#FF9F43", "#10AC84", "#EE5A24"
    ]

    colors[current_user.id % colors.length]
  end
end
