# frozen_string_literal: true

module Agents
  class TeamExecutionsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_execution
    
    def show
      # Execution is loaded in before_action
    end
    
    private
    
    def set_execution
      @execution = current_user.agent_teams
                              .joins(:agent_team_executions)
                              .find_by!(agent_team_executions: { id: params[:id] })
                              .agent_team_executions
                              .find(params[:id])
    end
  end
end