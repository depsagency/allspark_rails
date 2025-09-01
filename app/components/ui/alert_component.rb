# frozen_string_literal: true

# Alert component with DaisyUI styling
#
# Provides alert messages with different types and dismissible functionality
#
# Example usage:
#   <%= render Ui::AlertComponent.new(
#         type: :success,
#         dismissible: true,
#         auto_dismiss: 5000,  # Auto-dismiss after 5 seconds
#         icon: "✓"
#       ) do %>
#     Your changes have been saved successfully!
#   <% end %>
#
class Ui::AlertComponent < BaseComponent
  option :type, default: -> { "info" }
  option :dismissible, default: -> { false }
  option :auto_dismiss, optional: true  # Time in milliseconds
  option :icon, optional: true
  option :title, optional: true
  option :css_class, optional: true
  option :data, default: -> { {} }

  VALID_TYPES = %w[info success warning error].freeze

  private

  def alert_classes
    classes = [ "alert" ]

    # Add type
    validated_type = validate_variant(type, VALID_TYPES, "info")
    classes << "alert-#{validated_type}"

    # Add custom classes
    classes << css_class if css_class.present?

    classes.join(" ")
  end

  def alert_attributes
    attrs = data_attributes(data)
    
    if dismissible || auto_dismiss
      attrs["data-controller"] = "alert"
      attrs["data-alert-auto-dismiss-value"] = auto_dismiss.to_i if auto_dismiss
      attrs["data-alert-animation-value"] = "fade"
    end
    
    attrs
  end

  def default_icon
    case type.to_s
    when "success"
      "✓"
    when "warning"
      "⚠"
    when "error"
      "✕"
    else
      "ℹ"
    end
  end

  def alert_icon
    icon.present? ? icon : default_icon
  end

  def content
    @content ||= super&.strip
  end
end
