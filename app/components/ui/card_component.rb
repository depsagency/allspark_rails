# frozen_string_literal: true

# Card component with DaisyUI styling
#
# Provides a flexible card layout with optional image, title, body, and actions
#
# Example usage:
#   <%= render Ui::CardComponent.new(
#         title: "Card Title",
#         shadow: true,
#         compact: false
#       ) do |card| %>
#     <%= card.with_image(src: "/image.jpg", alt: "Description") %>
#     <%= card.with_body do %>
#       Card content goes here
#     <% end %>
#     <%= card.with_actions do %>
#       <%= render Ui::ButtonComponent.new(variant: :primary) { "Action" } %>
#     <% end %>
#   <% end %>
#
class Ui::CardComponent < BaseComponent
  renders_one :image, lambda { |src:, alt: "", css_class: nil|
    CardImageComponent.new(src: src, alt: alt, css_class: css_class)
  }
  renders_one :body, lambda { |css_class: nil|
    CardBodyComponent.new(css_class: css_class)
  }
  renders_one :actions, lambda { |css_class: nil|
    CardActionsComponent.new(css_class: css_class)
  }

  option :title, optional: true
  option :shadow, default: -> { true }
  option :compact, default: -> { false }
  option :bordered, default: -> { false }
  option :glass, default: -> { false }
  option :image_full, default: -> { false }
  option :side, default: -> { false }
  option :css_class, optional: true

  private

  def card_classes
    classes = [ "card" ]

    # Add background
    classes << "bg-base-100"

    # Add modifiers
    classes << "shadow-xl" if shadow
    classes << "card-compact" if compact
    classes << "card-bordered" if bordered
    classes << "glass" if glass
    classes << "image-full" if image_full
    classes << "card-side" if side

    # Add custom classes
    classes << css_class if css_class.present?

    classes.join(" ")
  end

  def body_classes
    classes = [ "card-body" ]
    classes << "items-center text-center" if image_full
    classes.join(" ")
  end

  def show_default_body?
    body.blank? && (title.present? || content.present?)
  end

  def content
    @content ||= super
  end

  # Inner component for card image
  class CardImageComponent < BaseComponent
    option :src
    option :alt, default: -> { "" }
    option :css_class, optional: true

    private

    def image_classes
      classes = []
      classes << css_class if css_class.present?
      classes.join(" ")
    end
  end

  # Inner component for card body
  class CardBodyComponent < BaseComponent
    option :css_class, optional: true

    private

    def body_classes
      classes = [ "card-body" ]
      classes << css_class if css_class.present?
      classes.join(" ")
    end
  end

  # Inner component for card actions
  class CardActionsComponent < BaseComponent
    option :css_class, optional: true

    private

    def actions_classes
      classes = [ "card-actions" ]
      classes << "justify-end"
      classes << css_class if css_class.present?
      classes.join(" ")
    end
  end
end
