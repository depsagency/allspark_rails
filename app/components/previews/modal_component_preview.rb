# frozen_string_literal: true

# @label Modal
class ModalComponentPreview < Lookbook::Preview
  # @label Basic Modal
  # @param title text "Modal title"
  # @param content text "Modal content"
  # @param button_text text "Button text"
  def default(title: "Basic Modal", content: "This is a basic modal with a title and content.", button_text: "Open Basic Modal")
    render Ui::ModalDemoComponent.new(
      variant: "basic",
      title: title,
      content: content,
      button_text: button_text
    )
  end

  # @label Modal with Form
  def with_form
    render Ui::ModalDemoComponent.new(
      variant: "form",
      size: "lg",
      button_text: "Open Form Modal (Large)"
    )
  end

  # @label Large Modal
  def large_modal
    render Ui::ModalDemoComponent.new(
      variant: "terms",
      size: "xl",
      button_text: "Open Large Modal (XL)"
    )
  end

  # @label Confirmation Modal
  def with_actions
    render Ui::ModalDemoComponent.new(
      variant: "confirmation",
      button_text: "Open Confirmation Modal",
      button_variant: "error"
    )
  end

  # @label Compact Modal
  def compact
    render Ui::ModalDemoComponent.new(
      variant: "compact",
      size: "sm",
      button_text: "Open Compact Modal (Small)",
      button_variant: "secondary"
    )
  end

  # @label Size Variants
  # @param size select { choices: [sm, md, lg, xl] }
  def size_variants(size: "md")
    render Ui::ModalDemoComponent.new(
      variant: "basic",
      size: size,
      title: "#{size.upcase} Modal",
      content: "This modal demonstrates the #{size} size variant.",
      button_text: "Open #{size.upcase} Modal"
    )
  end

  # @label Interactive Demo
  # @param variant select { choices: [basic, form, confirmation, terms, compact] }
  # @param size select { choices: [sm, md, lg, xl] }
  # @param button_variant select { choices: [primary, secondary, accent, ghost, error] }
  # @param title text "Modal title"
  # @param button_text text "Button text"
  def interactive(variant: "basic", size: "md", button_variant: "primary", title: "Interactive Modal", button_text: "Open Modal")
    render Ui::ModalDemoComponent.new(
      variant: variant,
      size: size,
      button_variant: button_variant,
      title: title,
      button_text: button_text,
      content: "This is an interactive modal demo where you can test different configurations."
    )
  end
end
