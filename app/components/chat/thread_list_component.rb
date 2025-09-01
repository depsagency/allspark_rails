# frozen_string_literal: true

module Chat
  class ThreadListComponent < ::BaseComponent
    def initialize(user:, context: nil, current_thread: nil)
      @user = user
      @context = context
      @current_thread = current_thread
    end
    
    private
    
    def threads
      @threads ||= if @context
        @user.chat_threads.for_context(@context).includes(:users, :messages)
      else
        @user.chat_threads.includes(:users, :messages)
      end
    end
    
    def thread_classes(thread)
      classes = ["chat-thread-item"]
      classes << "active" if thread == @current_thread
      classes << "has-unread" if thread.unread_count_for(@user) > 0
      classes.join(" ")
    end
    
    def last_message_preview(thread)
      last_message = thread.messages.last
      return "No messages yet" unless last_message
      
      "#{last_message.user.display_name}: #{truncate(last_message.content, length: 50)}"
    end
    
    def time_ago(thread)
      last_message = thread.messages.last
      return "" unless last_message
      
      time_ago_in_words(last_message.created_at)
    end
    
    def unread_badge(thread)
      count = thread.unread_count_for(@user)
      return unless count > 0
      
      content_tag(:span, count, class: "badge badge-primary badge-sm")
    end
  end
end