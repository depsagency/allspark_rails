# frozen_string_literal: true

class StreamingAssistantMessageJob < ApplicationJob
  queue_as :default

  def perform(assistant_id:, message:, user_id:, run_id:)
    assistant = Assistant.find(assistant_id)
    user = User.find(user_id)
    
    # Start assistant response
    broadcast_message(assistant_id, user_id, {
      type: 'assistant_start',
      run_id: run_id
    })
    
    # Stream the response
    response_content = ""
    assistant_message = nil
    
    begin
      # Run the assistant (this creates both user and assistant messages)
      response = assistant.run(content: message, user: user, run_id: run_id)
      response_content = response.content || "" if response.respond_to?(:content)
      
      # Find the messages that were created
      messages = assistant.assistant_messages.where(run_id: run_id).order(:created_at)
      user_message = messages.find { |m| m.role == 'user' }
      assistant_message = messages.find { |m| m.role == 'assistant' }
      
      # Broadcast the user message with its real ID so frontend can update the temporary one
      if user_message
        broadcast_message(assistant_id, user_id, {
          type: 'user_message_saved',
          run_id: run_id,
          message: format_message(user_message)
        })
      end
      
      # For real-time experience, we'll use streaming chunks
      # The actual message is already saved in the database
      if response_content.present?
        # Simulate streaming by sending in chunks
        response_content.scan(/.{1,50}/).each do |chunk|
          broadcast_message(assistant_id, user_id, {
            type: 'assistant_chunk',
            chunk: chunk,
            run_id: run_id
          })
          sleep 0.05 # Small delay to simulate streaming
        end
      end
      
      # Signal completion and send the formatted message
      if assistant_message
        broadcast_message(assistant_id, user_id, {
          type: 'assistant_stream_complete',
          run_id: run_id,
          formatted_content: ApplicationController.helpers.markdown(assistant_message.content)
        })
      else
        broadcast_message(assistant_id, user_id, {
          type: 'assistant_stream_complete',
          run_id: run_id
        })
      end
      
    rescue => e
      Rails.logger.error "Streaming assistant error: #{e.message}"
      
      broadcast_message(assistant_id, user_id, {
        type: 'assistant_error',
        error: e.message,
        run_id: run_id
      })
    end
  end
  
  private
  
  def broadcast_message(assistant_id, user_id, data)
    ActionCable.server.broadcast(
      "assistant_#{assistant_id}_user_#{user_id}",
      data
    )
  end
  
  def format_message(message)
    {
      id: message.id,
      role: message.role,
      content: message.content,
      created_at: message.created_at,
      metadata: message.metadata
    }
  end
  
  def build_prompt(assistant, run_id)
    # Build prompt from conversation history
    messages = assistant.conversation_for_run(run_id)
    messages.map { |m| "#{m.role}: #{m.content}" }.join("\n")
  end
end