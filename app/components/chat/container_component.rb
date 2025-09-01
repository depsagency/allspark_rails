# frozen_string_literal: true

module Chat
  class ContainerComponent < ::BaseComponent
    def initialize(user:, context: nil, thread_id: nil)
      @user = user
      @context = context
      @thread_id = thread_id
    end
    
    private
    
    def current_thread
      @current_thread ||= if @thread_id
        @user.chat_threads.find_by(id: @thread_id)
      else
        # Get the first thread or create a default one
        @user.chat_threads.first
      end
    end
    
    def show_thread_list?
      # Always show on desktop, can be toggled on mobile
      true
    end
  end
end