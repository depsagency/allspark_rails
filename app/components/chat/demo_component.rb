# frozen_string_literal: true

module Chat
  class DemoComponent < ::BaseComponent
    def initialize(variant: :default)
      @variant = variant
    end
    
    private
    
    def demo_messages
      case @variant
      when :empty
        []
      when :edited
        [
          { id: 1, user: "John Doe", content: "This message has been edited", time: "2 hours ago", edited: true, is_own: true },
          { id: 2, user: "Alice Johnson", content: "I see you edited your message", time: "1 hour ago", is_own: false },
          { id: 3, user: "John Doe", content: "Yes, I fixed a typo", time: "45 minutes ago", is_own: true }
        ]
      when :long_conversation
        messages = []
        20.times do |i|
          messages << {
            id: i + 1,
            user: i.even? ? "John Doe" : "Alice Johnson",
            content: "Message #{i + 1}: This is a test message in the conversation",
            time: "#{20 - i} minutes ago",
            is_own: i.even?
          }
        end
        messages
      else # :default
        [
          { id: 1, user: "John Doe", content: "Hello! How are you today?", time: "10 minutes ago", is_own: true },
          { id: 2, user: "Alice Johnson", content: "I'm doing great, thanks! How about you?", time: "8 minutes ago", is_own: false },
          { id: 3, user: "John Doe", content: "Pretty good! Working on the new chat feature 🚀", time: "5 minutes ago", is_own: true },
          { id: 4, user: "Alice Johnson", content: "That sounds exciting! Need any help?", time: "3 minutes ago", is_own: false },
          { id: 5, user: "John Doe", content: "Sure! Let me share the design mockups...", time: "1 minute ago", is_own: true }
        ]
      end
    end
    
    def demo_threads
      [
        { id: 1, name: "General Discussion", last_message: "Sure! Let me share the design...", time: "1 min", unread: 0, active: true },
        { id: 2, name: "Project Updates", last_message: "The deployment went smoothly", time: "1 hour", unread: 3 },
        { id: 3, name: "Team Chat", last_message: "See you at the standup!", time: "2 hours", unread: 0 },
        { id: 4, name: "Bug Reports", last_message: "Fixed the login issue", time: "1 day", unread: 1 }
      ]
    end
  end
end