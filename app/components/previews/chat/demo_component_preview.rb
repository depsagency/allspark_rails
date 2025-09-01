# frozen_string_literal: true

module Chat
  # @label Chat Demo
  class DemoComponentPreview < Lookbook::Preview
    # @label Default Chat
    def default
      render Chat::DemoComponent.new(variant: :default)
    end
    
    # @label Empty Conversation
    def empty
      render Chat::DemoComponent.new(variant: :empty)
    end
    
    # @label With Edited Messages
    def edited_messages
      render Chat::DemoComponent.new(variant: :edited)
    end
    
    # @label Long Conversation
    def long_conversation
      render Chat::DemoComponent.new(variant: :long_conversation)
    end
    
    # @label With Typing Indicator
    def typing_indicator
      render Chat::DemoComponent.new(variant: :typing)
    end
  end
end