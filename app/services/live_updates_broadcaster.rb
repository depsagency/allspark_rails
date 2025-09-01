# frozen_string_literal: true

# Service for broadcasting live updates via ActionCable
#
# Handles real-time broadcasting of model changes, notifications,
# and other live updates to connected clients
#
class LiveUpdatesBroadcaster
  class << self
    # Broadcast resource update
    def broadcast_resource_update(resource, action: :updated, changes: nil, user: nil)
      return unless should_broadcast?(resource)

      resource_type = resource.class.name.underscore

      data = {
        type: "resource_#{action}",
        resource_type: resource_type,
        resource_id: resource.id,
        resource_data: serialize_resource(resource),
        changes: changes || resource.previous_changes,
        user: user ? serialize_user(user) : nil,
        timestamp: Time.current.iso8601
      }

      # Broadcast to specific resource stream
      ActionCable.server.broadcast("#{resource_type}_#{resource.id}_updates", data)

      # Broadcast to global model stream
      ActionCable.server.broadcast("#{resource_type.pluralize}_updates", data)
    end

    # Broadcast resource creation
    def broadcast_resource_created(resource, user: nil)
      broadcast_resource_update(resource, action: :created, user: user)
    end

    # Broadcast resource deletion
    def broadcast_resource_deleted(resource, user: nil)
      resource_type = resource.class.name.underscore

      data = {
        type: "resource_deleted",
        resource_type: resource_type,
        resource_id: resource.id,
        user: user ? serialize_user(user) : nil,
        timestamp: Time.current.iso8601
      }

      # Broadcast to specific resource stream
      ActionCable.server.broadcast("#{resource_type}_#{resource.id}_updates", data)

      # Broadcast to global model stream
      ActionCable.server.broadcast("#{resource_type.pluralize}_updates", data)
    end

    # Broadcast notification
    def broadcast_notification(notification)
      return unless notification.user.present?

      ActionCable.server.broadcast(
        "user_#{notification.user.id}_notifications",
        {
          type: "new_notification",
          notification: notification.serialize_for_broadcast,
          unread_count: notification.user.notifications.unread.count
        }
      )
    end

    # Broadcast user-specific update
    def broadcast_user_update(user, data)
      ActionCable.server.broadcast(
        "user_#{user.id}_updates",
        {
          type: "user_update",
          data: data,
          timestamp: Time.current.iso8601
        }
      )
    end

    # Broadcast system announcement
    def broadcast_system_announcement(title:, message:, type: "info", **options)
      data = {
        type: "system_announcement",
        title: title,
        message: message,
        announcement_type: type,
        timestamp: Time.current.iso8601,
        **options
      }

      ActionCable.server.broadcast("system_announcements", data)
    end

    # Broadcast bulk operation result
    def broadcast_bulk_operation(user:, operation:, resource_type:, count:, success: true)
      data = {
        type: "bulk_operation_complete",
        operation: operation,
        resource_type: resource_type,
        count: count,
        success: success,
        timestamp: Time.current.iso8601
      }

      broadcast_user_update(user, data)
    end

    # Broadcast dashboard metrics update
    def broadcast_metrics_update(users: nil, data: {})
      message = {
        type: "metrics_update",
        data: data,
        timestamp: Time.current.iso8601
      }

      if users
        Array(users).each do |user|
          broadcast_user_update(user, message)
        end
      else
        # Broadcast to all admins
        User.system_admin.find_each do |admin|
          broadcast_user_update(admin, message)
        end
      end
    end

    # Broadcast progress update for long-running operations
    def broadcast_progress_update(user:, operation_id:, progress:, message: nil)
      data = {
        type: "progress_update",
        operation_id: operation_id,
        progress: progress, # 0-100
        message: message,
        timestamp: Time.current.iso8601
      }

      broadcast_user_update(user, data)
    end

    # Broadcast file upload progress
    def broadcast_upload_progress(user:, upload_id:, progress:, filename: nil)
      data = {
        type: "upload_progress",
        upload_id: upload_id,
        progress: progress,
        filename: filename,
        timestamp: Time.current.iso8601
      }

      broadcast_user_update(user, data)
    end

    # Broadcast real-time search results
    def broadcast_search_results(user:, query:, results:, search_id: nil)
      data = {
        type: "search_results",
        query: query,
        results: results,
        search_id: search_id,
        timestamp: Time.current.iso8601
      }

      broadcast_user_update(user, data)
    end

    private

    def should_broadcast?(resource)
      # Skip broadcasting for certain conditions
      return false if Rails.env.test? && !Rails.application.config.action_cable.test_broadcasting
      return false if resource.nil?
      return false if resource.respond_to?(:skip_broadcasting?) && resource.skip_broadcasting?

      true
    end

    def serialize_resource(resource)
      # Basic serialization - can be customized per model
      if resource.respond_to?(:as_live_update_json)
        resource.as_live_update_json
      elsif resource.respond_to?(:as_json)
        resource.as_json(only: safe_attributes(resource))
      else
        { id: resource.id }
      end
    end

    def serialize_user(user)
      return nil unless user

      {
        id: user.id,
        name: user.full_name || user.email,
        email: user.email,
        role: user.role,
        avatar_url: user.avatar.attached? ? Rails.application.routes.url_helpers.url_for(user.avatar) : nil
      }
    end

    def safe_attributes(resource)
      # Define safe attributes to broadcast for each model type
      case resource.class.name
      when "User"
        %i[id first_name last_name email role created_at updated_at]
      when "Notification"
        %i[id title message notification_type read_at created_at action_url]
      else
        # Default safe attributes
        %i[id name title status created_at updated_at]
      end
    end
  end
end
