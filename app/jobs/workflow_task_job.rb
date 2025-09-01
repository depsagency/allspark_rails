class WorkflowTaskJob < ApplicationJob
  queue_as :default

  def perform(task)
    Rails.logger.info "Starting workflow task #{task.id}: #{task.title}"
    
    # Use the simpler executor to avoid complex transaction issues
    result = SimpleWorkflowTaskExecutor.execute_task(task)
    
    if result
      Rails.logger.info "Workflow task #{task.id} completed successfully"
    else
      Rails.logger.error "Workflow task #{task.id} failed"
    end
    
    result
  rescue => e
    Rails.logger.error "Error executing workflow task #{task.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Try to mark as failed
    WorkflowTask.where(id: task.id, status: 'running').update_all(
      status: 'failed',
      completed_at: Time.current,
      result_data: { error: e.message },
      updated_at: Time.current
    )
    
    false
  end
end