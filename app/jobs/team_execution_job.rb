# frozen_string_literal: true

class TeamExecutionJob < ApplicationJob
  queue_as :default

  def perform(team, execution)
    # Update status to running
    execution.update!(status: :running)
    
    # Create coordinator and execute
    coordinator = team.create_coordinator
    
    begin
      result = coordinator.execute(execution.task, execution: execution)
      
      execution.update!(
        status: result[:status] == :completed ? :completed : :failed,
        completed_at: Time.current,
        result_data: result
      )
    rescue => e
      Rails.logger.error "Team execution failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      execution.update!(
        status: :failed,
        completed_at: Time.current,
        error_message: e.message
      )
      
      # Broadcast failure
      ActionCable.server.broadcast(
        "team_execution_#{execution.id}",
        {
          event: 'failed',
          execution_id: execution.id,
          timestamp: Time.current.iso8601,
          data: { error: e.message }
        }
      )
    end
  end
end