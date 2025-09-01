class WorkflowTaskExecutor
  attr_reader :task
  
  def initialize(task)
    @task = task
  end
  
  def execute
    # The task might already be running if it was force-started
    unless task.pending? || task.running?
      Rails.logger.warn "Task #{task.id} is not in a valid state to execute (status: #{task.status})"
      return false
    end
    
    unless task.assistant
      Rails.logger.error "Task #{task.id} has no assistant assigned"
      handle_failure("No assistant assigned to this task")
      return false
    end
    
    begin
      # Update task status if not already running
      if task.pending?
        task.update!(status: 'running', started_at: Time.current)
      end
      
      # Execute the task with the assistant
      Rails.logger.info "Executing task #{task.id} with assistant #{task.assistant.name}"
      
      # Use the assistant's execute_workflow_task method
      result = task.assistant.execute_workflow_task(task)
      
      # Give the database a moment to settle
      sleep 0.1
      
      # Reload task to check status
      task.reload
      
      if task.completed?
        Rails.logger.info "Task #{task.id} marked as completed successfully"
        broadcast_status_update('completed')
        return true
      elsif task.failed?
        Rails.logger.error "Task #{task.id} marked as failed"
        return false
      else
        Rails.logger.error "Task #{task.id} execution finished but status is #{task.status}, attempting manual completion"
        
        # If the assistant said it succeeded but status isn't updated, force it
        if result && task.running?
          Rails.logger.info "Assistant returned success but task still running, forcing completion"
          
          # Use direct SQL update to ensure it works
          updated = task.class.where(id: task.id, status: 'running').update_all(
            status: 'completed',
            completed_at: Time.current,
            updated_at: Time.current
          )
          
          if updated > 0
            Rails.logger.info "Task #{task.id} forcefully marked as complete"
            task.reload
            task.broadcast_status_update
            task.trigger_next_tasks
            return true
          else
            Rails.logger.error "Failed to force update task #{task.id}"
            raise "Failed to update task status to completed"
          end
        else
          raise "Task execution failed - unexpected status: #{task.status}"
        end
      end
      
    rescue => e
      Rails.logger.error "Error in task executor: #{e.message}"
      handle_failure(e.message)
      false
    end
  end
  
  def notify_assistant
    # Send notification to assistant about new task
    # This could be via ActionCable, webhook, or other mechanism
    broadcast_status_update('assigned')
  end
  
  def wait_for_completion
    timeout = task.workflow_execution.workflow.flow_definition.dig('settings', 'task_timeout') || 300
    start_time = Time.current
    
    while task.running? && (Time.current - start_time) < timeout
      sleep 1
      task.reload
    end
    
    handle_timeout if task.running?
  end
  
  def handle_timeout
    task.mark_failed("Task timed out after #{timeout} seconds")
    broadcast_status_update('timeout')
  end
  
  def update_task_status(status, data = {})
    case status
    when 'completed'
      task.mark_complete(data)
    when 'failed'
      task.mark_failed(data[:error] || "Unknown error")
    end
    
    broadcast_status_update(status)
  end
  
  private
  
  def broadcast_status_update(status)
    # Broadcast task status update via ActionCable
    ActionCable.server.broadcast(
      "workflow_execution_#{task.workflow_execution_id}",
      {
        type: 'task_update',
        task_id: task.id,
        node_id: task.node_id,
        status: status,
        progress: task.workflow_execution.progress_percentage,
        timestamp: Time.current
      }
    )
  end
  
  def handle_failure(error_message)
    task.mark_failed(error_message)
    broadcast_status_update('failed')
    
    # Optionally fail the entire workflow
    if should_fail_workflow?
      task.workflow_execution.fail!(error_message)
    end
  end
  
  def should_fail_workflow?
    # Check workflow settings for failure handling
    settings = task.workflow.flow_definition['settings'] || {}
    settings['fail_on_task_error'] != false
  end
  
  def timeout
    @timeout ||= begin
      # Get timeout from task, workflow, or default
      task_timeout = task.workflow.flow_definition.dig('nodes')
        &.find { |n| n['id'] == task.node_id }
        &.dig('data', 'timeout')
      
      workflow_timeout = task.workflow.flow_definition.dig('settings', 'default_task_timeout')
      
      (task_timeout || workflow_timeout || 300).to_i
    end
  end
end