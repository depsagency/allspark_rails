class WorkflowExecutionChannel < ApplicationCable::Channel
  def subscribed
    execution = WorkflowExecution.find(params[:execution_id])
    
    # Verify user has access
    if can_access_execution?(execution)
      stream_from "workflow_execution_#{execution.id}"
      
      # Send current status
      transmit({
        type: 'initial_status',
        execution: execution_status(execution)
      })
    else
      reject
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
  
  private
  
  def can_access_execution?(execution)
    # Check if user owns the team
    execution.workflow.team.user_id == current_user.id
  end
  
  def execution_status(execution)
    {
      id: execution.id,
      status: execution.status,
      progress_percentage: execution.progress_percentage,
      started_at: execution.started_at,
      elapsed_time: execution.elapsed_time,
      tasks: execution.workflow_tasks.map { |task|
        {
          id: task.id,
          node_id: task.node_id,
          title: task.title,
          status: task.status,
          started_at: task.started_at,
          completed_at: task.completed_at
        }
      }
    }
  end
end