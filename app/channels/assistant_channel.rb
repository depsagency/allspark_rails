# frozen_string_literal: true

class AssistantChannel < ApplicationCable::Channel
  def subscribed
    if params[:assistant_id].present?
      @assistant_id = params[:assistant_id]
      stream_from "assistant_#{@assistant_id}"
      stream_from "assistant_#{@assistant_id}_user_#{current_user.id}"
      logger.info "Subscribed to assistant channels for assistant_id: #{@assistant_id}, user_id: #{current_user.id}"
    else
      logger.error "No assistant_id provided to AssistantChannel"
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def send_message(data)
    logger.info "send_message called with data: #{data.inspect}"
    
    begin
      assistant = Assistant.find(@assistant_id || params[:assistant_id])
      logger.info "Found assistant: #{assistant.name} (#{assistant.id})"
      
      # Process message in background for streaming
      job = StreamingAssistantMessageJob.perform_later(
        assistant_id: assistant.id,
        message: data['message'],
        user_id: current_user.id,
        run_id: data['run_id'] || SecureRandom.uuid
      )
      logger.info "Enqueued StreamingAssistantMessageJob with job_id: #{job.job_id}"
    rescue => e
      logger.error "Error in send_message: #{e.message}"
      logger.error e.backtrace.join("\n")
      
      # Send error back to user
      transmit({
        type: 'assistant_error',
        error: "Failed to send message: #{e.message}"
      })
    end
  end

  def typing(data)
    # Broadcast typing indicator
    ActionCable.server.broadcast(
      "assistant_#{params[:assistant_id]}",
      {
        type: 'typing',
        user_id: current_user.id,
        typing: data['typing']
      }
    )
  end
end