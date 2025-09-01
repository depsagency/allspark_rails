# frozen_string_literal: true

class ChatThread < ApplicationRecord
  self.table_name = 'allspark_chat_threads'
  belongs_to :created_by, class_name: 'User'
  belongs_to :context, polymorphic: true, optional: true
  
  has_many :messages, class_name: 'ChatMessage', dependent: :destroy
  has_many :participants, class_name: 'ChatThreadParticipant', dependent: :destroy
  has_many :users, through: :participants
  
  validates :name, presence: true
  
  scope :global, -> { where(context_type: 'global') }
  scope :for_context, ->(context) { where(context: context) }
  
  def add_participant(user)
    participants.find_or_create_by(user: user)
  end
  
  def remove_participant(user)
    participants.find_by(user: user)&.destroy
  end
  
  def unread_count_for(user)
    participant = participants.find_by(user: user)
    return 0 unless participant
    
    messages.where('created_at > ?', participant.last_read_at || Time.at(0)).count
  end
  
  def mark_as_read_for(user)
    participant = participants.find_by(user: user)
    participant&.mark_as_read!
  end
  
  def recent_messages(limit = 50)
    messages.includes(:user).order(created_at: :desc).limit(limit)
  end
  
  def participant?(user)
    participants.exists?(user: user)
  end
end