# frozen_string_literal: true

module Chat
  class ThreadComponent < ::BaseComponent
    def initialize(thread:, user:)
      @thread = thread
      @user = user
    end
    
    private
    
    def messages
      @messages ||= @thread.recent_messages.reverse
    end
    
    def participant_list
      @thread.users.where.not(id: @user.id).map(&:display_name).join(", ")
    end
    
    def thread_id
      @thread.id
    end
    
    def current_user_id
      @user.id
    end
  end
end