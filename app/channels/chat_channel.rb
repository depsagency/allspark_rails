# frozen_string_literal: true

class ChatChannel < ApplicationCable::Channel
  def subscribed
    chat_thread = ChatThread.find(params[:thread_id])
    
    # Verify user has access to this thread
    if chat_thread.participant?(current_user)
      stream_from "chat_thread_#{chat_thread.id}"
      stream_from "chat_thread_#{chat_thread.id}_typing"
      
      # Notify others that user joined
      ActionCable.server.broadcast(
        "chat_thread_#{chat_thread.id}",
        {
          type: 'user_joined',
          user: user_data(current_user)
        }
      )
    else
      reject
    end
  end
  
  def unsubscribed
    # Clean up typing indicators
    stop_typing if @chat_thread
    
    # Notify others that user left
    if @chat_thread
      ActionCable.server.broadcast(
        "chat_thread_#{@chat_thread.id}",
        {
          type: 'user_left',
          user: user_data(current_user)
        }
      )
    end
  end
  
  def send_message(data)
    @chat_thread = ChatThread.find(params[:thread_id])
    
    return unless @chat_thread.participant?(current_user)
    
    message = @chat_thread.messages.create!(
      user: current_user,
      content: data['content']
    )
    
    # Mark thread as read for sender
    @chat_thread.mark_as_read_for(current_user)
  end
  
  def edit_message(data)
    @chat_thread = ChatThread.find(params[:thread_id])
    message = @chat_thread.messages.find(data['message_id'])
    
    # Only allow editing own messages
    if message.user == current_user
      message.edit!(data['content'])
    end
  end
  
  def delete_message(data)
    @chat_thread = ChatThread.find(params[:thread_id])
    message = @chat_thread.messages.find(data['message_id'])
    
    # Only allow deleting own messages
    if message.user == current_user
      message.destroy!
      
      ActionCable.server.broadcast(
        "chat_thread_#{@chat_thread.id}",
        {
          type: 'message_deleted',
          message_id: message.id
        }
      )
    end
  end
  
  def typing(data)
    @chat_thread = ChatThread.find(params[:thread_id])
    
    return unless @chat_thread.participant?(current_user)
    
    ActionCable.server.broadcast(
      "chat_thread_#{@chat_thread.id}_typing",
      {
        type: 'typing',
        user: user_data(current_user),
        is_typing: data['is_typing']
      }
    )
  end
  
  def mark_as_read
    @chat_thread = ChatThread.find(params[:thread_id])
    @chat_thread.mark_as_read_for(current_user)
    
    # Broadcast read receipt
    ActionCable.server.broadcast(
      "chat_thread_#{@chat_thread.id}",
      {
        type: 'read_receipt',
        user_id: current_user.id,
        read_at: Time.current
      }
    )
  end
  
  private
  
  def stop_typing
    return unless @chat_thread
    
    ActionCable.server.broadcast(
      "chat_thread_#{@chat_thread.id}_typing",
      {
        type: 'typing',
        user: user_data(current_user),
        is_typing: false
      }
    )
  end
  
  def user_data(user)
    {
      id: user.id,
      name: user.display_name,
      avatar_url: user_avatar_url(user)
    }
  end
  
  def user_avatar_url(user)
    # Return avatar URL if user has one attached
    # This would integrate with Active Storage if avatars are implemented
    nil
  end
end