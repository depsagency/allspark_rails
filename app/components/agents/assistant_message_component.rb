# frozen_string_literal: true

module Agents
  class AssistantMessageComponent < ViewComponent::Base
    attr_reader :message, :current_user

    def initialize(message:, current_user:)
      @message = message
      @current_user = current_user
    end

    def user_message?
      message.role == 'user'
    end

    def system_message?
      message.role == 'system'
    end

    def tool_message?
      message.role == 'tool'
    end

    def assistant_message?
      message.role == 'assistant'
    end

    def message_user
      return current_user if user_message? && message.metadata&.dig('user_id') == current_user.id
      
      # For assistant messages or other users
      if message.metadata&.dig('user_id')
        User.find_by(id: message.metadata['user_id'])
      else
        OpenStruct.new(
          display_name: assistant_message? ? 'AI Assistant' : message.role.capitalize,
          initials: assistant_message? ? 'AI' : message.role[0].upcase
        )
      end
    end

    def has_tool_calls?
      message.tool_calls.present? && message.tool_calls.any?
    end

    def formatted_content
      return '' if message.content.blank?
      
      if assistant_message? || message.metadata&.dig('markdown')
        helpers.markdown(message.content)
      else
        helpers.simple_format(message.content)
      end
    end

    def chat_position_class
      if user_message? && message.metadata&.dig('user_id') == current_user.id
        'chat-end'
      else
        'chat-start'
      end
    end

    def bubble_color_class
      case message.role
      when 'user'
        message.metadata&.dig('user_id') == current_user.id ? 'chat-bubble-primary' : 'chat-bubble'
      when 'assistant'
        'chat-bubble-secondary'
      when 'system'
        'chat-bubble-info'
      when 'tool'
        'chat-bubble-accent'
      else
        'chat-bubble'
      end
    end
  end
end