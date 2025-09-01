# frozen_string_literal: true

# Checkbox component with DaisyUI styling
#
# Provides styled checkboxes with:
# - Various sizes and colors
# - Indeterminate state
# - Labels and descriptions
# - Validation states
# - Accessibility features
#
# Example usage:
#   <%= render Ui::Form::CheckboxComponent.new(
#         name: "terms",
#         label: "I agree to the terms and conditions",
#         checked: true,
#         required: true
#       ) %>
#
class Ui::Form::CheckboxComponent < BaseComponent
  option :name, reader: :private
  option :value, default: -> { "1" }
  option :checked, default: -> { false }
  option :label, optional: true
  option :description, optional: true
  option :size, default: -> { :md }
  option :color, default: -> { :primary }
  option :indeterminate, default: -> { false }
  option :required, default: -> { false }
  option :disabled, default: -> { false }
  option :error, optional: true
  option :css_class, optional: true
  option :checkbox_class, optional: true
  option :data, default: -> { {} }

  VALID_SIZES = %w[xs sm md lg].freeze
  VALID_COLORS = %w[primary secondary accent success warning error info].freeze

  private

  def checkbox_id
    @checkbox_id ||= "#{name.to_s.parameterize}-#{SecureRandom.hex(4)}"
  end

  def checkbox_name
    name.to_s
  end

  def container_classes
    classes = [ "form-control" ]
    classes << css_class if css_class.present?
    classes.join(" ")
  end

  def label_classes
    classes = [ "label", "cursor-pointer", "justify-start", "gap-3" ]
    classes << "label-disabled" if disabled
    classes.join(" ")
  end

  def checkbox_classes
    classes = [ "checkbox" ]

    # Size
    validated_size = validate_variant(size, VALID_SIZES, "md")
    classes << "checkbox-#{validated_size}" unless validated_size == "md"

    # Color
    validated_color = validate_variant(color, VALID_COLORS, "primary")
    classes << "checkbox-#{validated_color}" unless validated_color == "primary"

    # Error state
    classes << "checkbox-error" if error.present?

    # Additional classes
    classes << checkbox_class if checkbox_class.present?

    classes.join(" ")
  end

  def checkbox_attributes
    attrs = data_attributes(data)

    attrs[:id] = checkbox_id
    attrs[:name] = checkbox_name
    attrs[:value] = value
    attrs[:checked] = true if checked
    attrs[:required] = true if required
    attrs[:disabled] = true if disabled

    # ARIA attributes
    attrs[:'aria-describedby'] = "#{checkbox_id}-error" if error.present?
    attrs[:'aria-invalid'] = "true" if error.present?
    attrs[:'aria-required'] = "true" if required

    # Indeterminate state (handled by JavaScript)
    if indeterminate
      attrs[:'data-indeterminate'] = "true"
      attrs[:'data-controller'] = [ attrs[:'data-controller'], "checkbox" ].compact.join(" ")
    end

    attrs
  end

  def has_label?
    label.present?
  end

  def has_description?
    description.present?
  end

  def has_error?
    error.present?
  end

  def error_text_id
    "#{checkbox_id}-error"
  end

  def hidden_field_name
    # For unchecked checkboxes, Rails expects a hidden field with value "0"
    checkbox_name
  end
end
