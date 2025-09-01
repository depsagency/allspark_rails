# frozen_string_literal: true

module Chat
  class AgentsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_thread

    def enable
      @thread.metadata ||= {}
      @thread.metadata['agent_enabled'] = true
      @thread.metadata['assistant_id'] = params[:assistant_id] if params[:assistant_id].present?
      
      if @thread.save
        # Send a welcome message from the agent
        agent = Agents::ChatBotAgent.new(thread_id: @thread.id)
        agent.send_to_chat("Hello! I'm your AI assistant. How can I help you today?")
        
        redirect_to chat_thread_path(@thread), notice: 'AI Assistant enabled for this thread.'
      else
        redirect_to chat_thread_path(@thread), alert: 'Failed to enable AI Assistant.'
      end
    end

    def disable
      @thread.metadata ||= {}
      @thread.metadata['agent_enabled'] = false
      
      if @thread.save
        redirect_to chat_thread_path(@thread), notice: 'AI Assistant disabled for this thread.'
      else
        redirect_to chat_thread_path(@thread), alert: 'Failed to disable AI Assistant.'
      end
    end

    private

    def set_thread
      @thread = current_user.participating_threads.find(params[:thread_id])
    end
  end
end