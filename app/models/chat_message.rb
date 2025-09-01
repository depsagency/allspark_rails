# frozen_string_literal: true

class ChatMessage < ApplicationRecord
  self.table_name = 'allspark_chat_messages'
  belongs_to :chat_thread
  belongs_to :user
  
  validates :content, presence: true
  
  after_create_commit :broadcast_message
  after_create_commit :process_with_agent
  after_update_commit :broadcast_update
  
  scope :recent, -> { order(created_at: :desc).limit(50) }
  
  def edit!(new_content)
    update!(
      content: new_content,
      edited: true,
      edited_at: Time.current
    )
  end
  
  private
  
  def broadcast_message
    channel = "chat_thread_#{chat_thread.id}"
    data = {
      type: 'new_message',
      message: message_data
    }
    
    ActionCable.server.broadcast(channel, data)
    Rails.logger.info "Broadcasting to #{channel}: #{data.to_json}"
  end
  
  def broadcast_update
    channel = "chat_thread_#{chat_thread.id}"
    data = {
      type: 'message_updated',
      message: message_data
    }
    
    ActionCable.server.broadcast(channel, data)
    Rails.logger.info "Broadcasting update to #{channel}: #{data.to_json}"
  end
  
  def message_data
    {
      id: id,
      chat_thread_id: chat_thread_id,
      user_id: user_id,
      user_name: user.display_name,
      user_avatar_url: user_avatar_url,
      content: content,
      edited: edited,
      edited_at: edited_at,
      created_at: created_at
    }
  end
  
  def user_avatar_url
    # Return avatar URL if user has one attached
    # This would integrate with Active Storage if avatars are implemented
    nil
  end
  
  def process_with_agent
    # Only process if not already from an agent and thread has agent enabled
    return if metadata&.dig('agent') == true
    return unless chat_thread.metadata&.dig('agent_enabled') == true
    
    ProcessAgentMessageJob.perform_later(id)
  end
end