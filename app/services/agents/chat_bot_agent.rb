# frozen_string_literal: true

module Agents
  class ChatBotAgent
    attr_reader :assistant, :thread

    def initialize(thread_id:, assistant: nil)
      @thread = ChatThread.find(thread_id)
      @assistant = assistant || create_default_assistant
    end

    # Process a message from the chat thread
    def process_message(message)
      # Run the assistant with the message content
      response = assistant.run(
        content: message.content,
        user: message.user,
        run_id: "chat-#{thread.id}-#{Time.current.to_i}"
      )
      
      # Send the response back to the chat
      send_to_chat(response.content)
      
      response
    rescue => e
      Rails.logger.error "ChatBotAgent error: #{e.message}"
      send_to_chat("I apologize, but I encountered an error processing your message.")
      raise
    end

    # Send a message to the chat thread
    def send_to_chat(content)
      chat_tool.execute(message: content)
    end

    # Start monitoring the thread for new messages
    def start_monitoring
      # This would typically be called from a background job
      # For now, we'll just provide the interface
      Rails.logger.info "Starting to monitor thread #{thread.id}"
    end

    # Stop monitoring the thread
    def stop_monitoring
      Rails.logger.info "Stopping monitoring of thread #{thread.id}"
    end

    private

    def create_default_assistant
      Assistant.find_or_create_by(name: 'Chat Bot Assistant') do |asst|
        asst.instructions = <<~INSTRUCTIONS
          You are a helpful AI assistant integrated into a chat system.
          Be friendly, concise, and helpful in your responses.
          You can help users with questions, provide information, and assist with tasks.
          Always maintain a professional and respectful tone.
        INSTRUCTIONS
        
        asst.tools = [
          { type: 'calculator' },
          { type: 'ruby_code_interpreter' },
          { 
            type: 'custom',
            class_name: 'Agents::Tools::ChatTool',
            options: { thread_id: thread.id }
          }
        ]
        
        asst.tool_choice = 'auto'
        asst.active = true
      end
    end

    def chat_tool
      @chat_tool ||= Agents::Tools::ChatTool.new(thread_id: thread.id)
    end
  end
end