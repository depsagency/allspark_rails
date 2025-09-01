# frozen_string_literal: true

# Modal component with DaisyUI styling
#
# Provides a flexible modal dialog with backdrop and close functionality
#
# Example usage:
#   <%= render Ui::ModalComponent.new(
#         id: "my-modal",
#         size: :lg,
#         closable: true
#       ) do |modal| %>
#     <%= modal.with_header do %>
#       <h3 class="font-bold text-lg">Modal Title</h3>
#     <% end %>
#     <%= modal.with_body do %>
#       Modal content goes here
#     <% end %>
#     <%= modal.with_footer do %>
#       <%= render Ui::ButtonComponent.new { "Close" } %>
#     <% end %>
#   <% end %>
#
class Ui::ModalComponent < BaseComponent
  renders_one :header, lambda { |css_class: nil|
    ModalHeaderComponent.new(css_class: css_class)
  }
  renders_one :body, lambda { |css_class: nil|
    ModalBodyComponent.new(css_class: css_class)
  }
  renders_one :footer, lambda { |css_class: nil|
    ModalFooterComponent.new(css_class: css_class)
  }

  option :id, default: -> { component_id("modal") }
  option :size, default: -> { "md" }
  option :closable, default: -> { true }
  option :backdrop_blur, default: -> { true }
  option :responsive, default: -> { true }
  option :css_class, optional: true
  option :data, default: -> { {} }

  VALID_SIZES = %w[sm md lg xl].freeze

  private

  def modal_classes
    classes = [ "modal" ]
    classes << css_class if css_class.present?
    classes.join(" ")
  end

  def modal_box_classes
    classes = [ "modal-box" ]

    # Add size
    validated_size = validate_variant(size, VALID_SIZES, "md")
    case validated_size
    when "sm"
      classes << "w-32 max-w-sm"
    when "lg"
      classes << "w-11/12 max-w-4xl"
    when "xl"
      classes << "w-11/12 max-w-6xl"
    else
      classes << "w-11/12 max-w-2xl"
    end

    # Add responsive classes
    if responsive
      classes << "max-h-screen"
      classes << "overflow-y-auto"
    end

    classes.join(" ")
  end

  def backdrop_classes
    classes = [ "modal-backdrop" ]
    classes << "backdrop-blur-sm" if backdrop_blur
    classes.join(" ")
  end

  def close_button_classes
    "btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
  end

  def modal_attributes
    attrs = data_attributes(data)
    attrs[:id] = id
    attrs
  end

  def show_default_layout?
    header.blank? && body.blank? && footer.blank?
  end

  def content
    @content ||= super&.strip
  end

  # Inner component for modal header
  class ModalHeaderComponent < BaseComponent
    option :css_class, optional: true

    private

    def header_classes
      classes = [ "modal-header", "pb-4" ]
      classes << css_class if css_class.present?
      classes.join(" ")
    end
  end

  # Inner component for modal body
  class ModalBodyComponent < BaseComponent
    option :css_class, optional: true

    private

    def body_classes
      classes = [ "modal-body", "py-4" ]
      classes << css_class if css_class.present?
      classes.join(" ")
    end
  end

  # Inner component for modal footer
  class ModalFooterComponent < BaseComponent
    option :css_class, optional: true

    private

    def footer_classes
      classes = [ "modal-action", "pt-4" ]
      classes << css_class if css_class.present?
      classes.join(" ")
    end
  end
end
