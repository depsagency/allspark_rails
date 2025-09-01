# frozen_string_literal: true

class ChatThreadParticipantSerializer
  include JSONAPI::Serializer
  
  attributes :last_read_at, :created_at, :updated_at, :user_id
  
  attribute :user_name do |participant|
    participant.user.display_name
  end
  
  attribute :unread_count do |participant|
    participant.unread_count
  end
  
  attribute :has_unread do |participant|
    participant.has_unread?
  end
end