# frozen_string_literal: true

class ChatThreadSerializer
  include JSONAPI::Serializer
  
  attributes :name, :context_type, :context_id, :created_at, :updated_at
  
  attribute :unread_count do |thread, params|
    params[:current_user] ? thread.unread_count_for(params[:current_user]) : 0
  end
  
  attribute :last_message do |thread|
    last_msg = thread.messages.last
    return nil unless last_msg
    
    {
      id: last_msg.id,
      content: last_msg.content,
      user_name: last_msg.user.display_name,
      created_at: last_msg.created_at
    }
  end
  
  attribute :participant_count do |thread|
    thread.participants.count
  end
  
  has_many :participants, serializer: ChatThreadParticipantSerializer
  has_many :messages, serializer: ChatMessageSerializer do |thread|
    thread.recent_messages(10)
  end
end