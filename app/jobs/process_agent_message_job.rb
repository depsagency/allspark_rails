# frozen_string_literal: true

class ProcessAgentMessageJob < ApplicationJob
  queue_as :default

  def perform(chat_message_id)
    message = ChatMessage.find(chat_message_id)
    
    # Only process user messages, not agent messages
    return if message.metadata['agent'] == true
    
    # Check if the thread has an active agent
    thread = message.chat_thread
    return unless thread_has_active_agent?(thread)
    
    # Process the message with the agent
    agent = Agents::ChatBotAgent.new(thread_id: thread.id)
    agent.process_message(message)
    
  rescue => e
    Rails.logger.error "Failed to process agent message: #{e.message}"
    # Could notify error handling service here
  end

  private

  def thread_has_active_agent?(thread)
    # Check if this thread has an active agent
    # This could be stored in thread metadata or a separate model
    thread.metadata['agent_enabled'] == true
  end
end