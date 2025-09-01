# frozen_string_literal: true

# Base component class for all ViewComponents
#
# Provides common functionality and utilities for all components including:
# - CSS class helpers
# - Data attribute helpers
# - Common rendering utilities
#
class BaseComponent < ViewComponent::Base
  extend Dry::Initializer
  include ApplicationHelper

  private

  # Merge CSS classes with defaults
  #
  # @param default_classes [String, Array] Default CSS classes
  # @param additional_classes [String, Array, nil] Additional CSS classes
  # @return [String] Merged CSS classes
  def css_classes(default_classes, additional_classes = nil)
    classes = Array(default_classes)
    classes.concat(Array(additional_classes)) if additional_classes.present?
    classes.compact.join(" ")
  end

  # Build data attributes hash
  #
  # @param data [Hash] Data attributes
  # @return [Hash] Formatted data attributes
  def data_attributes(data = {})
    return {} if data.blank?

    data.transform_keys { |key| "data-#{key.to_s.dasherize}" }
  end

  # Generate unique component ID
  #
  # @param prefix [String] ID prefix
  # @return [String] Unique ID
  def component_id(prefix = "component")
    @component_id ||= "#{prefix}_#{SecureRandom.hex(4)}"
  end

  # Check if variant is valid
  #
  # @param variant [String, Symbol] Variant to check
  # @param valid_variants [Array] Valid variants
  # @return [String] Valid variant or default
  def validate_variant(variant, valid_variants, default = valid_variants.first)
    variant = variant&.to_s
    valid_variants.include?(variant) ? variant : default
  end

  # Generate DaisyUI classes for component variants
  #
  # @param base_class [String] Base CSS class
  # @param variant [String] Variant modifier
  # @param size [String] Size modifier
  # @return [String] Complete CSS class string
  def daisy_classes(base_class, variant: nil, size: nil)
    classes = [ base_class ]
    classes << "#{base_class}-#{variant}" if variant.present?
    classes << "#{base_class}-#{size}" if size.present?
    classes.join(" ")
  end

  # Render content with optional wrapper
  #
  # @param tag [Symbol] HTML tag
  # @param css_class [String] CSS classes
  # @param attributes [Hash] Additional attributes
  # @yield Block content
  def render_with_wrapper(tag: :div, css_class: nil, **attributes, &block)
    if css_class || attributes.any?
      content_tag(tag, class: css_class, **attributes, &block)
    else
      capture(&block)
    end
  end

  # Safely render icon
  #
  # @param icon_name [String] Icon name (can be emoji or icon class)
  # @param css_class [String] Additional CSS classes
  # @return [String] Rendered icon
  def render_icon(icon_name, css_class: nil)
    return "" if icon_name.blank?

    # If it's an emoji, render directly
    if icon_name.match(/^\p{Emoji}/)
      content_tag(:span, icon_name, class: css_class)
    else
      # Assume it's an icon class
      content_tag(:i, "", class: css_classes(icon_name, css_class))
    end
  end

  # Format boolean attributes for HTML
  #
  # @param value [Boolean] Boolean value
  # @return [Hash] HTML-safe boolean attribute
  def boolean_attribute(value)
    value ? {} : { style: "display: none;" }
  end

  # Format attributes hash for HTML output
  #
  # @param attributes [Hash] HTML attributes
  # @return [String] HTML-safe formatted attributes
  def html_attributes(attributes = {})
    return "" if attributes.blank?

    attributes.map { |k, v| "#{k}=\"#{ERB::Util.html_escape(v)}\"" }.join(" ").html_safe
  end
end
