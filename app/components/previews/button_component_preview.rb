# frozen_string_literal: true

# @label Button
class ButtonComponentPreview < Lookbook::Preview
  # @label Default Button
  # @param text text "Button text"
  # @param variant select { choices: [primary, secondary, accent, ghost, link, outline] }
  # @param size select { choices: [xs, sm, md, lg] }
  # @param disabled toggle
  def default(text: "Click me", variant: :primary, size: :md, disabled: false)
    render Ui::ButtonComponent.new(
      text: text,
      variant: variant.to_sym,
      size: size.to_sym,
      disabled: disabled
    )
  end

  # @label Loading Button
  def loading
    render Ui::ButtonComponent.new(
      text: "Loading...",
      variant: :primary,
      loading: true
    )
  end

  # @label With Icon
  def with_icon
    render Ui::ButtonComponent.new(
      text: "Download",
      variant: :secondary,
      icon: "arrow-down-tray"
    )
  end

  # @label Icon on Right
  def icon_right
    render Ui::ButtonComponent.new(
      text: "Next",
      variant: :primary,
      icon: "arrow-right",
      icon_position: "right"
    )
  end

  # @label Icon Only
  def icon_only
    render Ui::ButtonComponent.new(
      variant: :ghost,
      icon: "heart",
      circle: true
    )
  end

  # @label Link Button
  def link_button
    render Ui::ButtonComponent.new(
      text: "Go to Dashboard",
      variant: :link,
      href: "/dashboard"
    )
  end

  # @label Extra Small Button
  def xs_size
    render Ui::ButtonComponent.new(
      text: "Extra Small",
      variant: :primary,
      size: :xs
    )
  end

  # @label Small Button
  def sm_size
    render Ui::ButtonComponent.new(
      text: "Small",
      variant: :primary,
      size: :sm
    )
  end

  # @label Large Button
  def lg_size
    render Ui::ButtonComponent.new(
      text: "Large",
      variant: :primary,
      size: :lg
    )
  end

  # @label Accent Button
  def accent_variant
    render Ui::ButtonComponent.new(
      text: "Accent Button",
      variant: :accent
    )
  end

  # @label Ghost Button
  def ghost_variant
    render Ui::ButtonComponent.new(
      text: "Ghost Button",
      variant: :ghost
    )
  end
end
