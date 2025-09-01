# frozen_string_literal: true

class TeamExecutionChannel < ApplicationCable::Channel
  def subscribed
    execution = AgentTeamExecution.find_by(id: params[:execution_id])
    
    if execution && execution.agent_team.user == current_user
      stream_from "team_execution_#{execution.id}"
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end
end