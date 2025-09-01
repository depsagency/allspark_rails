# frozen_string_literal: true

class Ui::BadgeComponent < BaseComponent
  option :variant, default: -> { "success" }
  option :size, default: -> { "md" }
  option :disabled, default: -> { false }
  option :text, default: -> { "" }
  option :html_content, optional: true
  option :css_class, optional: true
  option :data, default: -> { {} }

  VALID_VARIANTS = %w[success warning error info].freeze
  VALID_SIZES = %w[xs sm md lg].freeze

  private

  def component_classes
    classes = [ "badge" ]

    # Add variant
    validated_variant = validate_variant(variant, VALID_VARIANTS, "success")
    classes << "badge-#{validated_variant}"

    # Add size
    validated_size = validate_variant(size, VALID_SIZES, "md")
    classes << "badge-#{validated_size}"

    # Add state classes
    classes << "badge-disabled" if disabled

    # Add custom classes
    classes << css_class if css_class.present?

    classes.join(" ")
  end

  def component_attributes
    attrs = data_attributes(data)
    attrs["data-controller"] = "badge" if data.any?
    attrs
  end

  def content
    if html_content.present?
      html_content.html_safe
    elsif text.present?
      text
    else
      super&.strip
    end
  end
end
