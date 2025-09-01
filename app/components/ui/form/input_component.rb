# frozen_string_literal: true

# Input component with DaisyUI styling and validation
#
# Provides styled form inputs with:
# - Validation states and error messages
# - Various input types (text, email, password, etc.)
# - Sizes and states
# - Icons and labels
# - Accessibility features
#
# Example usage:
#   <%= render Ui::Form::InputComponent.new(
#         name: "email",
#         label: "Email Address",
#         type: :email,
#         placeholder: "Enter your email",
#         required: true,
#         error: @user.errors[:email].first
#       ) %>
#
class Ui::Form::InputComponent < BaseComponent
  option :name, reader: :private
  option :value, optional: true
  option :label, optional: true
  option :placeholder, optional: true
  option :type, default: -> { :text }
  option :size, default: -> { :md }
  option :state, optional: true # :success, :warning, :error
  option :error, optional: true
  option :help_text, optional: true
  option :required, default: -> { false }
  option :disabled, default: -> { false }
  option :readonly, default: -> { false }
  option :autocomplete, optional: true
  option :maxlength, optional: true
  option :minlength, optional: true
  option :pattern, optional: true
  option :step, optional: true
  option :min, optional: true
  option :max, optional: true
  option :rows, optional: true # for textarea
  option :icon_left, optional: true
  option :icon_right, optional: true
  option :css_class, optional: true
  option :input_class, optional: true
  option :data, default: -> { {} }

  VALID_TYPES = %w[text email password tel url search number date datetime-local time month week color range file textarea].freeze
  VALID_SIZES = %w[xs sm md lg].freeze
  VALID_STATES = %w[success warning error].freeze

  private

  def input_id
    @input_id ||= name.to_s.parameterize
  end

  def input_name
    name.to_s
  end

  def container_classes
    classes = [ "form-control", "w-full" ]
    classes << css_class if css_class.present?
    classes.join(" ")
  end

  def label_classes
    classes = [ "label" ]
    classes << "cursor-pointer"
    classes.join(" ")
  end

  def input_wrapper_classes
    classes = []

    if has_icons?
      classes << "relative"
    end

    classes.join(" ")
  end

  def input_classes
    classes = []

    # Base input class
    if textarea?
      classes << "textarea"
    else
      classes << "input"
    end

    classes << "input-bordered"

    # Size
    validated_size = validate_variant(size, VALID_SIZES, "md")
    classes << "input-#{validated_size}" unless validated_size == "md"

    # State
    if error.present?
      classes << "input-error"
    elsif state.present?
      validated_state = validate_variant(state, VALID_STATES, nil)
      classes << "input-#{validated_state}" if validated_state
    end

    # Icons padding
    classes << "pl-10" if icon_left.present?
    classes << "pr-10" if icon_right.present?

    # Additional classes
    classes << input_class if input_class.present?

    classes.join(" ")
  end

  def input_attributes
    attrs = data_attributes(data)

    attrs[:id] = input_id
    attrs[:name] = input_name
    attrs[:value] = value if value.present? && !textarea? && !file_input?
    attrs[:placeholder] = placeholder if placeholder.present?
    attrs[:required] = true if required
    attrs[:disabled] = true if disabled
    attrs[:readonly] = true if readonly
    attrs[:autocomplete] = autocomplete if autocomplete.present?
    attrs[:maxlength] = maxlength if maxlength.present?
    attrs[:minlength] = minlength if minlength.present?
    attrs[:pattern] = pattern if pattern.present?
    attrs[:step] = step if step.present?
    attrs[:min] = min if min.present?
    attrs[:max] = max if max.present?
    attrs[:rows] = rows if textarea? && rows.present?

    # ARIA attributes
    attrs[:'aria-describedby'] = "#{input_id}-help" if help_text.present? || error.present?
    attrs[:'aria-invalid'] = "true" if error.present?
    attrs[:'aria-required'] = "true" if required

    attrs
  end

  def input_type
    return nil if textarea?
    validate_variant(type, VALID_TYPES, "text")
  end

  def textarea?
    type.to_s == "textarea"
  end

  def file_input?
    type.to_s == "file"
  end

  def has_label?
    label.present?
  end

  def has_icons?
    icon_left.present? || icon_right.present?
  end

  def has_help_text?
    help_text.present?
  end

  def has_error?
    error.present?
  end

  def icon_classes(position)
    classes = [ "absolute", "top-1/2", "transform", "-translate-y-1/2", "text-base-content/40", "pointer-events-none" ]

    if position == :left
      classes << "left-3"
    else
      classes << "right-3"
    end

    classes.join(" ")
  end

  def help_text_id
    "#{input_id}-help"
  end

  def error_text_id
    "#{input_id}-error"
  end
end
