# frozen_string_literal: true

# @label Form Checkbox
class CheckboxComponentPreview < Lookbook::Preview
  # @label Basic Checkbox
  # @param label text "Checkbox Label"
  # @param checked toggle
  # @param disabled toggle
  def default(label: "I agree to the terms", checked: false, disabled: false)
    render Ui::Form::CheckboxComponent.new(
      name: "agreement",
      label: label,
      checked: checked,
      disabled: disabled
    )
  end

  # @label Checked Checkbox
  def checked
    render Ui::Form::CheckboxComponent.new(
      name: "newsletter",
      label: "Subscribe to newsletter",
      checked: true
    )
  end

  # @label Checkbox with Error
  def with_error
    render Ui::Form::CheckboxComponent.new(
      name: "terms",
      label: "Accept terms and conditions",
      error: "You must accept the terms to continue"
    )
  end

  # @label Checkbox with Hint
  def with_hint
    render Ui::Form::CheckboxComponent.new(
      name: "notifications",
      label: "Enable email notifications",
      hint: "You can change this later in settings",
      checked: true
    )
  end

  # @label Required Checkbox
  def required
    render Ui::Form::CheckboxComponent.new(
      name: "privacy",
      label: "I have read and accept the privacy policy",
      required: true
    )
  end

  # @label Disabled Checkbox
  def disabled
    render Ui::Form::CheckboxComponent.new(
      name: "readonly",
      label: "This option is disabled",
      checked: true,
      disabled: true
    )
  end

  # @label Checkbox Sizes
  def sizes
    render Ui::Form::CheckboxComponent.new(
      name: "medium",
      label: "Medium Checkbox (Default Size)",
      size: "md"
    )
  end

  # @label Checkbox Colors
  def colors
    render Ui::Form::CheckboxComponent.new(
      name: "primary",
      label: "Primary Color Checkbox",
      color: "primary",
      checked: true
    )
  end

  # @label Multiple Checkboxes
  def multiple_options
    render Ui::Form::CheckboxComponent.new(
      name: "interests[]",
      value: "technology",
      label: "Technology (checked)",
      checked: true
    )
  end
end
