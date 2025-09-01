# frozen_string_literal: true

class ChatMessageSerializer
  include JSONAPI::Serializer
  
  attributes :content, :edited, :edited_at, :created_at, :updated_at, :user_id, :chat_thread_id
  
  attribute :user_name do |message|
    message.user.display_name
  end
  
  attribute :user_avatar_url do |message|
    # Return avatar URL if user has one attached
    # This would integrate with Active Storage if avatars are implemented
    nil
  end
end