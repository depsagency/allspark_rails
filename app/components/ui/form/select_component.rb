# frozen_string_literal: true

# Select component with DaisyUI styling
#
# Provides styled select dropdowns with:
# - Option groups
# - Multiple selection
# - Search functionality
# - Validation states
# - Custom styling
#
# Example usage:
#   <%= render Ui::Form::SelectComponent.new(
#         name: "country",
#         label: "Country",
#         options: [
#           ["United States", "US"],
#           ["Canada", "CA"],
#           ["Mexico", "MX"]
#         ],
#         selected: "US",
#         prompt: "Choose a country"
#       ) %>
#
class Ui::Form::SelectComponent < BaseComponent
  option :name, reader: :private
  option :options, default: -> { [] }
  option :selected, optional: true
  option :label, optional: true
  option :prompt, optional: true
  option :multiple, default: -> { false }
  option :size, default: -> { :md }
  option :state, optional: true
  option :error, optional: true
  option :help_text, optional: true
  option :required, default: -> { false }
  option :disabled, default: -> { false }
  option :searchable, default: -> { false }
  option :clearable, default: -> { false }
  option :css_class, optional: true
  option :select_class, optional: true
  option :data, default: -> { {} }

  VALID_SIZES = %w[xs sm md lg].freeze
  VALID_STATES = %w[success warning error].freeze

  private

  def select_id
    @select_id ||= name.to_s.parameterize
  end

  def select_name
    if multiple
      "#{name}[]"
    else
      name.to_s
    end
  end

  def container_classes
    classes = [ "form-control", "w-full" ]
    classes << css_class if css_class.present?
    classes.join(" ")
  end

  def select_classes
    classes = [ "select", "select-bordered", "w-full" ]

    # Size
    validated_size = validate_variant(size, VALID_SIZES, "md")
    classes << "select-#{validated_size}" unless validated_size == "md"

    # State
    if error.present?
      classes << "select-error"
    elsif state.present?
      validated_state = validate_variant(state, VALID_STATES, nil)
      classes << "select-#{validated_state}" if validated_state
    end

    # Additional classes
    classes << select_class if select_class.present?

    classes.join(" ")
  end

  def select_attributes
    attrs = data_attributes(data)

    attrs[:id] = select_id
    attrs[:name] = select_name
    attrs[:required] = true if required
    attrs[:disabled] = true if disabled
    attrs[:multiple] = true if multiple

    # ARIA attributes
    attrs[:'aria-describedby'] = "#{select_id}-help" if help_text.present? || error.present?
    attrs[:'aria-invalid'] = "true" if error.present?
    attrs[:'aria-required'] = "true" if required

    # Enhanced select attributes
    if searchable
      attrs[:'data-controller'] = "enhanced-select"
      attrs[:'data-enhanced-select-searchable-value'] = "true"
      attrs[:'data-enhanced-select-clearable-value'] = clearable.to_s
    end

    attrs
  end

  def label_classes
    classes = [ "label" ]
    classes << "cursor-pointer"
    classes.join(" ")
  end

  def has_label?
    label.present?
  end

  def has_help_text?
    help_text.present?
  end

  def has_error?
    error.present?
  end

  def help_text_id
    "#{select_id}-help"
  end

  def error_text_id
    "#{select_id}-error"
  end

  def processed_options
    @processed_options ||= normalize_options(options)
  end

  def normalize_options(opts)
    return [] if opts.blank?

    if opts.is_a?(Hash)
      # Handle grouped options: { "Group 1" => [["Option 1", "value1"]], "Group 2" => [...] }
      opts.map do |group_label, group_options|
        {
          group: group_label,
          options: normalize_simple_options(group_options)
        }
      end
    else
      # Handle simple array of options
      [ {
        group: nil,
        options: normalize_simple_options(opts)
      } ]
    end
  end

  def normalize_simple_options(opts)
    opts.map do |option|
      case option
      when Array
        # ["Label", "value"] or ["Label", "value", { disabled: true }]
        {
          label: option[0],
          value: option[1],
          attributes: option[2] || {}
        }
      when Hash
        # { label: "Label", value: "value", disabled: true }
        {
          label: option[:label] || option[:text],
          value: option[:value],
          attributes: option.except(:label, :text, :value)
        }
      else
        # Simple string/value
        {
          label: option.to_s,
          value: option.to_s,
          attributes: {}
        }
      end
    end
  end

  def option_selected?(option_value)
    if multiple && selected.is_a?(Array)
      selected.include?(option_value.to_s)
    else
      selected.to_s == option_value.to_s
    end
  end

  def option_attributes(option)
    attrs = option[:attributes].dup
    attrs[:value] = option[:value]
    attrs[:selected] = true if option_selected?(option[:value])
    attrs
  end
end
