# frozen_string_literal: true

module Agents
  class AssistantChatComponent < ViewComponent::Base
    attr_reader :assistant, :current_user

    def initialize(assistant:, current_user:, height: "600px")
      @assistant = assistant
      @current_user = current_user
      @height = height
    end

    def messages
      @messages ||= assistant.assistant_messages
                            .order(:created_at)
                            .last(50)
    end

    def tools_enabled?
      assistant.tools.present? && assistant.tools.any?
    end

    def tool_badges
      return [] unless tools_enabled?
      
      assistant.tools.map do |tool|
        case tool['type']
        when 'calculator'
          { icon: 'calculator', label: 'Calculator', color: 'primary' }
        when 'ruby_code', 'ruby_code_interpreter'
          { icon: 'code', label: 'Code', color: 'secondary' }
        when 'web_search', 'google_search'
          { icon: 'search', label: 'Web Search', color: 'accent' }
        when 'chat'
          { icon: 'chat-bubble-left-right', label: 'Chat', color: 'info' }
        when 'claude_code'
          { icon: 'terminal', label: 'Claude Code', color: 'success' }
        else
          { icon: 'puzzle-piece', label: tool['type'].humanize, color: 'neutral' }
        end
      end
    end
  end
end