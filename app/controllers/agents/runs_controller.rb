# frozen_string_literal: true

module Agents
  class RunsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_run, only: [:show]
    
    def index
      @runs = AgentRun.joins(:assistant)
                      .where(assistants: { user_id: current_user.id })
                      .includes(:assistant)
      
      # Filter by assistant if provided
      if params[:assistant_id].present?
        @assistant = current_user.assistants.find(params[:assistant_id])
        @runs = @runs.where(assistant_id: @assistant.id)
      end
      
      # Apply filters
      @runs = @runs.where(status: params[:status]) if params[:status].present?
      
      # Ordering
      @runs = @runs.order(created_at: :desc)
      
      # Simple pagination
      @page = (params[:page] || 1).to_i
      @per_page = 50
      @total_count = @runs.count
      @runs = @runs.limit(@per_page).offset((@page - 1) * @per_page)
    end
    
    def show
      @messages = @run.messages.includes(:assistant)
      @assistant = @run.assistant
      
      # Parse metadata for display
      @tools_used = @run.tools_called || []
      @duration = @run.duration_seconds
      @error_details = parse_error_details if @run.failed?
    end
    
    private
    
    def set_run
      @run = AgentRun.joins(:assistant)
                     .where(assistants: { user_id: current_user.id })
                     .find(params[:id])
    end
    
    def parse_error_details
      {
        message: @run.error_message,
        timestamp: @run.completed_at || @run.updated_at,
        duration_before_error: @run.duration_ms
      }
    end
  end
end