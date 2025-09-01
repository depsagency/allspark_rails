# frozen_string_literal: true

module Chat
  # @label AI Assistant Chat
  class AiAssistantChatPreview < Lookbook::Preview
    # Interactive demo of chat with AI assistant functionality
    # @label Interactive AI Chat Demo
    def interactive_demo
      render template: 'lookbook/chat/ai_assistant_demo'
    end

    # Shows a chat thread with AI enabled
    # @label AI Enabled Thread
    def ai_enabled_thread
      render_chat_interface(ai_enabled: true, show_ai_messages: true)
    end

    # Shows a chat thread without AI
    # @label Regular Thread
    def regular_thread
      render_chat_interface(ai_enabled: false, show_ai_messages: false)
    end

    private

    def render_chat_interface(ai_enabled:, show_ai_messages:)
      if ai_enabled && show_ai_messages
        render template: 'lookbook/chat/ai_enabled_demo'
      else
        render template: 'lookbook/chat/regular_chat_demo'
      end
    end
  end
end