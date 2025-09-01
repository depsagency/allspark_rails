# frozen_string_literal: true

# @label Form Input
class InputComponentPreview < Lookbook::Preview
  # @label Basic Input
  # @param label text "Field Label"
  # @param placeholder text "Enter text..."
  # @param type select { choices: [text, email, password, number, tel, url] }
  # @param required toggle
  # @param disabled toggle
  def default(label: "Username", placeholder: "Enter username", type: "text", required: false, disabled: false)
    render Ui::Form::InputComponent.new(
      name: "username",
      label: label,
      placeholder: placeholder,
      type: type,
      required: required,
      disabled: disabled
    )
  end

  # @label Input with Value
  def with_value
    render Ui::Form::InputComponent.new(
      name: "email",
      label: "Email Address",
      type: "email",
      value: "user@example.com",
      placeholder: "your@email.com"
    )
  end

  # @label Input with Error
  def with_error
    render Ui::Form::InputComponent.new(
      name: "password",
      label: "Password",
      type: "password",
      error: "Password must be at least 8 characters",
      placeholder: "Enter password"
    )
  end

  # @label Input with Hint
  def with_hint
    render Ui::Form::InputComponent.new(
      name: "website",
      label: "Website URL",
      type: "url",
      hint: "Include https:// prefix",
      placeholder: "https://example.com"
    )
  end

  # @label Required Input
  def required
    render Ui::Form::InputComponent.new(
      name: "fullname",
      label: "Full Name",
      required: true,
      placeholder: "John Doe"
    )
  end

  # @label Disabled Input
  def disabled
    render Ui::Form::InputComponent.new(
      name: "readonly",
      label: "Read Only Field",
      value: "This field is disabled",
      disabled: true
    )
  end

  # @label Input Sizes
  def sizes
    render Ui::Form::InputComponent.new(
      name: "medium",
      label: "Medium Input (Default Size)",
      size: "md",
      placeholder: "Medium size input"
    )
  end

  # @label Input Types
  def types
    render Ui::Form::InputComponent.new(
      name: "email",
      label: "Email Input Type",
      type: "email",
      placeholder: "email@example.com"
    )
  end
end
