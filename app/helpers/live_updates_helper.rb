# frozen_string_literal: true

# Helper methods for live updates and real-time features
#
module LiveUpdatesHelper
  # Generate data attributes for live resource updates
  def live_resource_attributes(resource, options = {})
    return {} unless resource&.persisted?

    attrs = {
      'data-resource-type': resource.class.name.underscore,
      'data-resource-id': resource.id
    }

    # Add update method if specified
    if options[:update_method]
      attrs["data-update-method"] = options[:update_method]
    end

    # Add specific attributes to watch
    if options[:watch_attributes]
      attrs["data-watch-attributes"] = Array(options[:watch_attributes]).join(",")
    end

    attrs
  end

  # Generate data attributes for resource lists
  def live_resource_list_attributes(model_class, options = {})
    attrs = {
      'data-resource-list': model_class.name.underscore
    }

    # Add sorting information
    if options[:sort_by]
      attrs["data-sort-by"] = options[:sort_by]
    end

    # Add filtering information
    if options[:filter_by]
      attrs["data-filter-by"] = options[:filter_by]
    end

    attrs
  end

  # Create a hidden template for new resources
  def live_resource_template(model_class, &block)
    content_tag :div,
                class: "resource-template hidden",
                data: {
                  resource_template: true,
                  resource_type: model_class.name.underscore
                } do
      yield if block_given?
    end
  end

  # Add live update attributes to an element
  def with_live_updates(resource, options = {}, &block)
    attributes = live_resource_attributes(resource, options)

    content_tag :div, attributes do
      yield if block_given?
    end
  end

  # Generate attributes for collaborative editing
  def collaborative_editor_attributes(resource, options = {})
    return {} unless resource&.persisted?

    {
      'data-collaborative-editor': true,
      'data-resource-type': resource.class.name.underscore,
      'data-resource-id': resource.id,
      'data-collaboration-enabled': options.fetch(:enabled, true)
    }
  end

  # Add typing indicator container
  def typing_indicator(context)
    content_tag :div,
                class: "typing-indicator text-sm text-base-content/60 italic hidden",
                data: { typing_context: context } do
      # Content will be updated by JavaScript
    end
  end

  # Online users indicator
  def online_users_indicator(options = {})
    content_tag :div, class: "online-users-indicator" do
      concat content_tag(:span, "👥", class: "mr-1")
      concat content_tag(:span, "0", id: "online-users-count", class: "font-medium")
      concat content_tag(:span, " online", class: "text-sm")
    end
  end

  # Notification badge
  def notification_badge(user = current_user, options = {})
    return unless user

    unread_count = user.notifications.unread.count
    css_classes = [ "badge", options[:class] ].compact.join(" ")

    content_tag :span,
                unread_count,
                class: css_classes,
                data: { notification_count: true },
                style: (unread_count > 0 ? "" : "display: none;")
  end

  # Presence indicator for a user
  def user_presence_indicator(user, options = {})
    return unless user

    css_classes = [
      "presence-indicator",
      "w-3 h-3 rounded-full border-2 border-white",
      "bg-base-300", # Default offline color
      options[:class]
    ].compact.join(" ")

    content_tag :div,
                "",
                class: css_classes,
                data: { user_id: user.id },
                title: "#{user.full_name} - Offline"
  end

  # Activity status indicator
  def user_activity_indicator(user, options = {})
    return unless user

    content_tag :span,
                "Unknown",
                class: [ "activity-indicator", "text-base-content/60", options[:class] ].compact.join(" "),
                data: { user_id: user.id }
  end

  # Live metrics container
  def live_metrics_container(metrics = {}, options = {})
    content_tag :div,
                class: [ "live-metrics", options[:class] ].compact.join(" "),
                data: { live_metrics: true } do
      metrics.each do |key, value|
        concat content_tag(:div, class: "metric") do
          concat content_tag(:span, key.to_s.humanize, class: "metric-label")
          concat content_tag(:span, value, class: "metric-value", data: { metric: key })
        end
      end
    end
  end

  # Progress bar that updates in real-time
  def live_progress_bar(operation_id, options = {})
    progress = options.fetch(:progress, 0)

    content_tag :div, class: "progress-container" do
      content_tag :progress,
                  "",
                  class: [ "progress", options[:class] ].compact.join(" "),
                  value: progress,
                  max: "100",
                  data: {
                    operation_id: operation_id,
                    live_progress: true
                  }
    end
  end

  # Search results container that updates in real-time
  def live_search_results(search_id = nil, options = {})
    search_id ||= SecureRandom.hex(8)

    content_tag :div,
                class: [ "search-results", options[:class] ].compact.join(" "),
                data: {
                  search_results: true,
                  search_id: search_id
                } do
      if options[:loading]
        content_tag :div, class: "loading" do
          "Searching..."
        end
      else
        yield if block_given?
      end
    end
  end

  # Add CSS for live update animations
  def live_updates_styles
    content_tag :style do
      <<~CSS
        .live-update-flash {
          animation: liveUpdateFlash 1s ease-out;
        }

        @keyframes liveUpdateFlash {
          0% { background-color: rgb(59 130 246 / 0.1); }
          50% { background-color: rgb(59 130 246 / 0.2); }
          100% { background-color: transparent; }
        }

        .collaborative-cursor {
          position: absolute;
          z-index: 1000;
          pointer-events: none;
          transition: all 0.1s ease-out;
        }

        .collaborative-selection {
          position: absolute;
          pointer-events: none;
          opacity: 0.3;
          transition: all 0.1s ease-out;
        }

        .typing-indicator {
          transition: opacity 0.2s ease-in-out;
        }

        .presence-indicator {
          transition: background-color 0.3s ease-in-out;
        }

        .notification-item {
          transition: all 0.2s ease-in-out;
        }

        .notification-item.unread {
          background-color: rgb(59 130 246 / 0.05);
          border-left: 3px solid rgb(59 130 246);
        }

        .resource-template {
          display: none !important;
        }
      CSS
    end
  end

  # Generate meta tags for ActionCable authentication
  def action_cable_meta_tags
    return unless user_signed_in?

    tags = []

    # Add current user ID for JavaScript
    tags << tag(:meta, name: "current-user-id", content: current_user.id)

    # Add CSRF token for ActionCable
    tags << tag(:meta, name: "action-cable-csrf-token", content: form_authenticity_token)

    # Add ActionCable URL
    if Rails.env.development?
      tags << tag(:meta, name: "action-cable-url", content: "ws://localhost:3000/cable")
    else
      tags << tag(:meta, name: "action-cable-url", content: action_cable_url)
    end

    safe_join(tags, "\n")
  end

  # Check if live updates are enabled
  def live_updates_enabled?
    # Can be controlled by feature flags or user preferences
    Rails.application.config.respond_to?(:live_updates_enabled) ?
      Rails.application.config.live_updates_enabled : true
  end

  # Get WebSocket URL for ActionCable
  def action_cable_url
    if request.ssl?
      "wss://#{request.host}/cable"
    else
      "ws://#{request.host}/cable"
    end
  end
end
