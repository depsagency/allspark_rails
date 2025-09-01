# frozen_string_literal: true

class ChatThreadParticipant < ApplicationRecord
  self.table_name = 'allspark_chat_thread_participants'
  belongs_to :chat_thread
  belongs_to :user
  
  validates :user_id, uniqueness: { scope: :chat_thread_id }
  
  def mark_as_read!
    update!(last_read_at: Time.current)
  end
  
  def unread_count
    chat_thread.messages.where('created_at > ?', last_read_at || Time.at(0)).count
  end
  
  def has_unread?
    unread_count > 0
  end
end