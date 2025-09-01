# frozen_string_literal: true

# Modal demo component for Lookbook previews
#
# Encapsulates both trigger buttons and modal components to provide
# fully interactive modal demonstrations in Lookbook
#
class Ui::ModalDemoComponent < BaseComponent
  option :variant, default: -> { "basic" }
  option :size, default: -> { "md" }
  option :title, default: -> { "Modal Title" }
  option :content, default: -> { "Modal content goes here." }
  option :button_text, default: -> { "Open Modal" }
  option :button_variant, default: -> { "primary" }

  VALID_VARIANTS = %w[basic form confirmation terms compact].freeze
  VALID_SIZES = %w[sm md lg xl].freeze
  VALID_BUTTON_VARIANTS = %w[primary secondary accent ghost link error warning info success].freeze

  private

  def demo_id
    @demo_id ||= "modal-demo-#{SecureRandom.hex(4)}"
  end

  def modal_id
    "#{demo_id}-modal"
  end

  def validated_variant
    validate_variant(variant, VALID_VARIANTS, "basic")
  end

  def validated_size
    validate_variant(size, VALID_SIZES, "md")
  end

  def validated_button_variant
    validate_variant(button_variant, VALID_BUTTON_VARIANTS, "primary")
  end

  def trigger_button_classes
    "btn btn-#{validated_button_variant}"
  end

  def trigger_onclick
    "document.getElementById('#{modal_id}').showModal()"
  end
end
