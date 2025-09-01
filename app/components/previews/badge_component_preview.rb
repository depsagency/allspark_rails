# frozen_string_literal: true

# @label Badge
class BadgeComponentPreview < Lookbook::Preview
  # @label Default
  # @param text text "Badge Text"
  # @param variant select { choices: [primary, secondary, success, warning, error, info] }
  # @param size select { choices: [xs, sm, md, lg] }
  # @param disabled toggle
  def default(text: "Badge", variant: "success", size: "md", disabled: false)
    render Ui::BadgeComponent.new(
      text: text,
      variant: variant.to_sym,
      size: size.to_sym,
      disabled: disabled
    )
  end

  # @label Success Badge
  def success
    render Ui::BadgeComponent.new(
      text: "Success",
      variant: :success
    )
  end

  # @label Warning Badge
  def warning
    render Ui::BadgeComponent.new(
      text: "Warning",
      variant: :warning
    )
  end

  # @label Error Badge
  def error
    render Ui::BadgeComponent.new(
      text: "Error",
      variant: :error
    )
  end

  # @label All Variants
  def all_variants
    render Ui::BadgeComponent.new(
      text: "All Variants Demo",
      variant: :success
    )
  end

  # @label All Sizes
  def all_sizes
    render Ui::BadgeComponent.new(
      text: "All Sizes Demo",
      variant: :success,
      size: :md
    )
  end

  # @label Disabled State
  def disabled_state
    render Ui::BadgeComponent.new(
      text: "Disabled Badge",
      variant: :success,
      disabled: true
    )
  end
end
