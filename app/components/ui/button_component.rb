# frozen_string_literal: true

# Button component with DaisyUI styling
#
# Supports all DaisyUI button variants, sizes, and states
#
# Example usage:
#   <%= render Ui::ButtonComponent.new(variant: :primary, size: :lg) do %>
#     Click me!
#   <% end %>
#
#   <%= render Ui::ButtonComponent.new(
#         variant: :secondary,
#         size: :sm,
#         loading: true,
#         disabled: false,
#         href: "/path"
#       ) do %>
#     Save Changes
#   <% end %>
#
class Ui::ButtonComponent < BaseComponent
  option :variant, default: -> { "primary" }
  option :size, default: -> { "md" }
  option :loading, default: -> { false }
  option :disabled, default: -> { false }
  option :wide, default: -> { false }
  option :block, default: -> { false }
  option :outline, default: -> { false }
  option :glass, default: -> { false }
  option :ghost, default: -> { false }
  option :link, default: -> { false }
  option :circle, default: -> { false }
  option :square, default: -> { false }
  option :href, optional: true
  option :type, default: -> { "button" }
  option :css_class, optional: true
  option :text, optional: true
  option :icon, optional: true
  option :icon_position, default: -> { "left" }
  option :data, default: -> { {} }

  VALID_VARIANTS = %w[
    primary secondary accent ghost info success warning error
    neutral base-100 base-200 base-300
  ].freeze

  VALID_SIZES = %w[xs sm md lg].freeze

  private

  def button_classes
    classes = [ "btn" ]

    # Add variant
    validated_variant = validate_variant(variant, VALID_VARIANTS, "primary")
    classes << "btn-#{validated_variant}" unless validated_variant == "neutral"

    # Add size
    validated_size = validate_variant(size, VALID_SIZES, "md")
    classes << "btn-#{validated_size}" unless validated_size == "md"

    # Add modifiers
    classes << "btn-outline" if outline
    classes << "btn-wide" if wide
    classes << "btn-block" if block
    classes << "glass" if glass
    classes << "btn-ghost" if ghost
    classes << "btn-link" if link
    classes << "btn-circle" if circle
    classes << "btn-square" if square

    # Add state classes
    classes << "loading" if loading
    classes << "btn-disabled" if disabled

    # Add custom classes
    classes << css_class if css_class.present?

    classes.join(" ")
  end

  def button_attributes
    attrs = data_attributes(data)
    attrs[:disabled] = true if disabled && !href
    attrs[:type] = type unless href
    attrs
  end

  def tag_name
    href ? :a : :button
  end

  def link_attributes
    return {} unless href
    { href: href }
  end

  def show_loading_spinner?
    loading
  end

  def show_icon?
    icon.present? && !loading
  end

  def icon_classes
    # No spacing classes needed since we use flexbox gap
    ""
  end

  def content
    @content ||= text.present? ? text : super
  end

  def render_button_icon(icon_name)
    return "" if icon_name.blank?

    # Use the same icon rendering as IconsHelper but without the extra span
    begin
      options = { class: "w-4 h-4 flex-shrink-0" }
      InlineSvg::TransformPipeline.generate_html_from(read_svg_icon(icon_name), options).html_safe
    rescue StandardError
      # Fallback to simple text if icon not found
      tag.span(icon_name.to_s.dasherize, class: "w-4 h-4 flex-shrink-0")
    end
  end

  def read_svg_icon(filename)
    File.read(Rails.public_path.join("assets/icons/heroicons/outline/#{filename.dasherize}.svg"))
  end
end
