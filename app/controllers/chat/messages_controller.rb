# frozen_string_literal: true

module Chat
  class MessagesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_thread
    before_action :check_participant
    before_action :set_message, only: [:update, :destroy]
    before_action :check_message_owner, only: [:update, :destroy]
    
    def create
      @message = @thread.messages.build(message_params)
      @message.user = current_user
      
      if @message.save
        render json: ChatMessageSerializer.new(@message).serializable_hash, status: :created
      else
        render json: { errors: @message.errors }, status: :unprocessable_entity
      end
    end
    
    def update
      if @message.update(message_params.merge(edited: true, edited_at: Time.current))
        render json: ChatMessageSerializer.new(@message).serializable_hash
      else
        render json: { errors: @message.errors }, status: :unprocessable_entity
      end
    end
    
    def destroy
      @message.destroy
      head :no_content
    end
    
    private
    
    def set_thread
      @thread = ChatThread.find(params[:thread_id])
    end
    
    def set_message
      @message = @thread.messages.find(params[:id])
    end
    
    def check_participant
      unless @thread.participant?(current_user)
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end
    
    def check_message_owner
      unless @message.user == current_user
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end
    
    def message_params
      params.require(:chat_message).permit(:content)
    end
  end
end