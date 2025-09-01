# frozen_string_literal: true

module Agents
  class TeamsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_team, only: [:show, :edit, :update, :destroy, :execute]
    
    def index
      @teams = current_user.agent_teams.includes(:assistants)
    end
    
    def show
      @executions = @team.agent_team_executions.recent.limit(10)
    end
    
    def new
      @team = current_user.agent_teams.build
      @available_assistants = current_user.assistants.active
    end
    
    def create
      @team = current_user.agent_teams.build(team_params)
      
      if @team.save
        update_team_assistants
        redirect_to agents_team_path(@team), notice: 'Team created successfully.'
      else
        @available_assistants = current_user.assistants.active
        render :new
      end
    end
    
    def edit
      @available_assistants = current_user.assistants.active
    end
    
    def update
      if @team.update(team_params)
        update_team_assistants
        redirect_to agents_team_path(@team), notice: 'Team updated successfully.'
      else
        @available_assistants = current_user.assistants.active
        render :edit
      end
    end
    
    def destroy
      @team.destroy
      redirect_to agents_teams_path, notice: 'Team deleted successfully.'
    end
    
    def execute
      task = params[:task]
      
      if task.present?
        # Create the execution record immediately
        execution = @team.agent_team_executions.create!(
          task: task,
          status: :pending,
          started_at: Time.current
        )
        
        # Execute in background job for better performance
        TeamExecutionJob.perform_later(@team, execution)
        
        redirect_to agents_team_path(@team, execution_id: execution.id), 
                    notice: 'Task execution started. Progress will be shown below.'
      else
        redirect_to agents_team_path(@team), alert: 'Please provide a task.'
      end
    end
    
    private
    
    def set_team
      @team = current_user.agent_teams.find(params[:id])
    end
    
    def team_params
      params.require(:agent_team).permit(:name, :purpose, :workflow, :active, 
        assistant_ids: [],
        configuration: [:coordination_mode, :max_iterations, :timeout_seconds])
    end
    
    def update_team_assistants
      if params[:agent_team].key?(:assistant_ids)
        assistant_ids = params[:agent_team][:assistant_ids].reject(&:blank?)
        @team.assistant_ids = assistant_ids
      end
    end
  end
end