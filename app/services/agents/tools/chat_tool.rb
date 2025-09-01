# frozen_string_literal: true

module Agents
  module Tools
    class ChatTool
      extend Langchain::ToolDefinition
      
      NAME = "chat"
      ANNOTATIONS_PATH = Pathname.new(__dir__).join("../../../schemas/agents/tools/chat_tool.json").to_s
      
      def self.description
        <<~DESC
        Send a message to a chat thread. Use this tool to communicate with users in a specific chat thread.
        The tool will handle formatting and real-time delivery of messages.
      DESC
      end
      
      # Define the chat function with parameters
      define_function :execute, description: "Send a message to a chat thread" do
        property :message, type: "string", description: "Message to send", required: true
        property :thread_id, type: "string", description: "Chat thread ID", required: false
      end
      
      def initialize(thread_id: nil)
        @thread_id = thread_id
      end
      
      # Send a message to the chat thread
      def execute(message:, thread_id: nil)
        thread_id ||= @thread_id
        
        return { error: "No thread_id provided" } unless thread_id
        
        thread = ChatThread.find_by(id: thread_id)
        return { error: "Thread not found" } unless thread
        
        # Create the message (this will broadcast via ActionCable)
        chat_message = thread.messages.create!(
          user: assistant_user,
          content: message,
          metadata: { agent: true }
        )
        
        {
          success: true,
          message_id: chat_message.id,
          thread_id: thread.id,
          sent_at: chat_message.created_at
        }
      rescue => e
        { error: e.message }
      end
      
      private
      
      def assistant_user
        @assistant_user ||= User.find_or_create_by(email: 'assistant@allspark.ai') do |user|
          user.name = 'AI Assistant'
          user.password = SecureRandom.hex(32)
        end
      end
    end
  end
end