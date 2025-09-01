class WorkflowTask < ApplicationRecord
  belongs_to :workflow_execution
  belongs_to :assistant, optional: true
  
  validates :node_id, presence: true
  validates :status, inclusion: { in: %w[pending running completed failed cancelled] }
  
  scope :pending, -> { where(status: 'pending') }
  scope :running, -> { where(status: 'running') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  
  # Status check methods
  def pending?
    status == 'pending'
  end
  
  def running?
    status == 'running'
  end
  
  def completed?
    status == 'completed'
  end
  
  def failed?
    status == 'failed'
  end
  
  def cancelled?
    status == 'cancelled'
  end
  
  def assign_to_assistant(assistant)
    update!(assistant: assistant)
  end
  
  def execute!
    return false unless status == 'pending'
    return false unless assistant
    
    transaction do
      update!(
        status: 'running',
        started_at: Time.current
      )
      
      # Broadcast task start
      broadcast_status_update
      
      # Queue job for async execution with appropriate timeout
      timeout_seconds = SimpleWorkflowTaskExecutor.determine_timeout(self, assistant)
      WorkflowTaskJob.set(timeout: timeout_seconds).perform_later(self)
    end
    
    true
  end
  
  def mark_complete(result_data = {})
    Rails.logger.info "[TASK_COMPLETE] Starting mark_complete for task #{id}"
    Rails.logger.info "[TASK_COMPLETE] Current status before reload: #{status}"
    
    # Reload to ensure we have the latest status
    reload
    Rails.logger.info "[TASK_COMPLETE] Current status after reload: #{status}"
    
    unless status == 'running'
      Rails.logger.error "[TASK_COMPLETE] Cannot mark task #{id} as complete - status is #{status}, not running"
      return false
    end
    
    Rails.logger.info "[TASK_COMPLETE] Using update_columns to update task #{id}"
    
    # Use update_columns to bypass any potential transaction issues
    success = update_columns(
      status: 'completed',
      completed_at: Time.current,
      result_data: result_data,
      updated_at: Time.current
    )
    
    Rails.logger.info "[TASK_COMPLETE] update_columns returned: #{success}"
    
    if success
      Rails.logger.info "[TASK_COMPLETE] Update successful, reloading task #{id}"
      
      # Reload to ensure we have the updated record
      reload
      
      Rails.logger.info "[TASK_COMPLETE] After reload, status is: #{status}"
      
      # Small delay to ensure database write is visible to other connections
      sleep 0.1
      
      # Broadcast task completion
      broadcast_status_update
      
      # Trigger next tasks in workflow (outside of transaction)
      trigger_next_tasks_internal
      
      Rails.logger.info "[TASK_COMPLETE] Task #{id} marked as complete successfully, final status: #{status}"
      true
    else
      Rails.logger.error "[TASK_COMPLETE] Failed to update task #{id} status to completed"
      false
    end
  rescue => e
    Rails.logger.error "[TASK_COMPLETE] Exception in mark_complete for task #{id}: #{e.message}"
    Rails.logger.error "[TASK_COMPLETE] Backtrace: #{e.backtrace.first(5).join("\n")}"
    false
  end
  
  def mark_failed(error_message)
    return false unless status == 'running'
    
    update!(
      status: 'failed',
      completed_at: Time.current,
      result_data: { 'error' => error_message }
    )
    
    # Broadcast task failure
    broadcast_status_update
    
    # Optionally fail the entire workflow execution
    workflow_execution.fail!("Task #{title} failed: #{error_message}")
    
    true
  end
  
  def elapsed_time
    return nil unless started_at
    
    end_time = completed_at || Time.current
    end_time - started_at
  end
  
  def workflow
    workflow_execution.workflow
  end
  
  def broadcast_status_update
    broadcast_status_update_internal
  end
  
  def trigger_next_tasks
    trigger_next_tasks_internal
  end
  
  private
  
  def broadcast_status_update_internal
    Rails.logger.info "[BROADCAST] Broadcasting status update for task #{id} with status #{status}"
    
    # Broadcast to workflow execution channel
    execution_channel = "workflow_execution_#{workflow_execution_id}"
    execution_payload = {
      type: 'task_update',
      task_id: id,
      node_id: node_id,
      status: status,
      completed_at: completed_at,
      result_data: result_data,
      progress: workflow_execution.progress_percentage
    }
    
    Rails.logger.info "[BROADCAST] Broadcasting to #{execution_channel}: #{execution_payload.inspect}"
    ActionCable.server.broadcast(execution_channel, execution_payload)
    
    # Also broadcast to specific task channel for dependent tasks
    task_channel = "workflow_task_#{id}"
    task_payload = {
      type: 'status_update',
      status: status,
      completed: completed?
    }
    
    Rails.logger.info "[BROADCAST] Broadcasting to #{task_channel}: #{task_payload.inspect}"
    ActionCable.server.broadcast(task_channel, task_payload)
    
    Rails.logger.info "[BROADCAST] Broadcast complete"
  rescue => e
    Rails.logger.error "[BROADCAST] Error broadcasting status update: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
  
  def trigger_next_tasks_internal
    Rails.logger.info "[NEXT_TASKS] Starting trigger_next_tasks for task #{id}"
    
    begin
      flow_definition = workflow.flow_definition
      nodes = flow_definition['nodes'] || []
      edges = flow_definition['edges'] || []
      
      # Find edges from this node
      outgoing_edges = edges.select { |e| e['source'] == node_id }
      Rails.logger.info "[NEXT_TASKS] Found #{outgoing_edges.count} outgoing edges"
      
      outgoing_edges.each do |edge|
        target_node_id = edge['target']
        target_node = nodes.find { |n| n['id'] == target_node_id }
        
        next unless target_node
        
        Rails.logger.info "[NEXT_TASKS] Checking dependencies for target node #{target_node_id}"
        
        # Check if all dependencies are met for target node
        if dependencies_met_for?(target_node_id, edges)
          Rails.logger.info "[NEXT_TASKS] Dependencies met, creating task for node #{target_node_id}"
          create_next_task(target_node)
        else
          Rails.logger.info "[NEXT_TASKS] Dependencies not met for node #{target_node_id}"
        end
      end
      
      # Check if all tasks are complete
      if workflow_execution.workflow_tasks.pending.empty? && workflow_execution.workflow_tasks.running.empty?
        Rails.logger.info "[NEXT_TASKS] All tasks complete, marking execution as complete"
        workflow_execution.complete!
      end
      
      Rails.logger.info "[NEXT_TASKS] Finished trigger_next_tasks for task #{id}"
    rescue => e
      Rails.logger.error "[NEXT_TASKS] Error in trigger_next_tasks: #{e.message}"
      Rails.logger.error "[NEXT_TASKS] Backtrace: #{e.backtrace.first(5).join("\n")}"
      # Don't re-raise - we don't want to rollback the task completion
    end
  end
  
  def dependencies_met_for?(node_id, edges)
    # Find all incoming edges to this node
    incoming_edges = edges.select { |e| e['target'] == node_id }
    
    # Check if all source nodes have completed tasks
    incoming_edges.all? do |edge|
      source_task = workflow_execution.workflow_tasks.find_by(node_id: edge['source'])
      source_task && source_task.completed?
    end
  end
  
  def create_next_task(node)
    # Don't create if task already exists
    return if workflow_execution.workflow_tasks.exists?(node_id: node['id'])
    
    # Don't create end nodes as tasks
    return if node['type'] == 'end'
    
    node_data = node['data'] || {}
    
    # Extract assistant_id from assignee data
    assistant_id = if node_data['assignee'].is_a?(Hash)
                     node_data['assignee']['id']
                   elsif node_data['assignee'].is_a?(String)
                     node_data['assignee']
                   else
                     nil
                   end
    
    # For assistant nodes, the instructions might be in the task field
    instructions = node_data['instructions']
    if node['type'] == 'assistant' && node_data['task']
      instructions = node_data['task']['title'] || instructions
    end
    
    task = workflow_execution.workflow_tasks.create!(
      node_id: node['id'],
      title: node_data['title'] || node['type'].humanize,
      instructions: instructions,
      assistant_id: assistant_id,
      status: 'pending'
    )
    
    # Broadcast task creation
    assistant_name = task.assistant&.name || 'Unassigned'
    ActionCable.server.broadcast(
      "workflow_execution_#{workflow_execution.id}",
      {
        type: 'task_created',
        task: {
          id: task.id,
          node_id: task.node_id,
          title: task.title,
          instructions: task.instructions,
          assistant_name: assistant_name,
          status: task.status,
          started_at: task.started_at,
          completed_at: task.completed_at
        }
      }
    )
    
    Rails.logger.info "[NEXT_TASKS] Broadcast task creation for task #{task.id}"
    
    task
  end
end