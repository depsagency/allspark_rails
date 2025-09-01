# frozen_string_literal: true

module Chat
  class ThreadsController < ApplicationController
    layout 'chat'
    
    before_action :authenticate_user!
    before_action :set_thread, only: [:show, :update, :destroy, :add_participant, :remove_participant, :mark_as_read]
    before_action :check_participant, only: [:show, :update, :add_participant, :remove_participant]
    
    def index
      @threads = current_user.chat_threads.includes(:users, :messages)
      @current_thread = @threads.find_by(id: params[:thread_id]) || @threads.first
      
      respond_to do |format|
        format.html
        format.json { render json: ChatThreadSerializer.new(@threads, params: { current_user: current_user }).serializable_hash }
      end
    end
    
    def show
      @thread.mark_as_read_for(current_user)
      
      respond_to do |format|
        format.html # Render the show view
        format.json { render json: ChatThreadSerializer.new(@thread, params: { current_user: current_user }).serializable_hash }
      end
    end
    
    def create
      @thread = ChatThread.new(thread_params)
      @thread.created_by = current_user
      
      if @thread.save
        @thread.add_participant(current_user)
        
        respond_to do |format|
          format.html { redirect_to chat_thread_path(@thread) }
          format.json { render json: ChatThreadSerializer.new(@thread, params: { current_user: current_user }).serializable_hash, status: :created }
        end
      else
        respond_to do |format|
          format.html { 
            flash[:error] = @thread.errors.full_messages.join(", ")
            redirect_to chat_threads_path 
          }
          format.json { render json: { errors: @thread.errors }, status: :unprocessable_entity }
        end
      end
    end
    
    def update
      if @thread.update(thread_params)
        respond_to do |format|
          format.html { redirect_to chat_thread_path(@thread) }
          format.json { render json: ChatThreadSerializer.new(@thread, params: { current_user: current_user }).serializable_hash }
        end
      else
        respond_to do |format|
          format.html { 
            flash[:error] = @thread.errors.full_messages.join(", ")
            redirect_to chat_thread_path(@thread) 
          }
          format.json { render json: { errors: @thread.errors }, status: :unprocessable_entity }
        end
      end
    end
    
    def destroy
      @thread.destroy
      
      respond_to do |format|
        format.html { redirect_to chat_threads_path }
        format.json { head :no_content }
      end
    end
    
    def add_participant
      user = User.find(params[:user_id])
      @thread.add_participant(user)
      
      respond_to do |format|
        format.html { redirect_to chat_thread_path(@thread) }
        format.json { render json: { success: true } }
      end
    end
    
    def remove_participant
      user = User.find(params[:user_id])
      @thread.remove_participant(user)
      
      respond_to do |format|
        format.html { redirect_to chat_thread_path(@thread) }
        format.json { render json: { success: true } }
      end
    end
    
    def mark_as_read
      @thread.mark_as_read_for(current_user)
      
      respond_to do |format|
        format.html { redirect_to chat_thread_path(@thread) }
        format.json { render json: { success: true } }
      end
    end
    
    private
    
    def set_thread
      @thread = ChatThread.find(params[:id])
    end
    
    def check_participant
      unless @thread.participant?(current_user)
        respond_to do |format|
          format.html { 
            flash[:error] = "You are not a participant in this conversation"
            redirect_to chat_threads_path 
          }
          format.json { render json: { error: "Unauthorized" }, status: :unauthorized }
        end
      end
    end
    
    def thread_params
      params.require(:chat_thread).permit(:name, :context_type, :context_id)
    end
  end
end