class WorkflowExecutionJob < ApplicationJob
  queue_as :default

  def perform(execution)
    Rails.logger.info "Starting workflow execution #{execution.id}"
    
    # Get the workflow
    workflow = execution.workflow
    
    # Parse the flow definition
    service = WorkflowExecutionService.new(workflow, execution.user)
    execution_plan = service.create_execution_plan
    
    # Execute each level of tasks
    execution_plan.each_with_index do |level_tasks, level|
      Rails.logger.info "Executing level #{level} with #{level_tasks.size} tasks"
      Rails.logger.info "Level tasks: #{level_tasks.map { |t| "#{t[:node_id]} (#{t[:node]['type']})" }.join(', ')}"
      
      # Create and execute tasks for this level
      created_tasks = []
      level_tasks.each do |task_data|
        task = create_and_execute_task(execution, task_data)
        # Only add tasks that need to be waited for (not already completed)
        if task && !task.completed? && !task.failed?
          created_tasks << task
        end
      end
      
      # Only wait if we actually have tasks to wait for
      if created_tasks.any?
        Rails.logger.info "Waiting for #{created_tasks.size} tasks to complete..."
        wait_for_created_tasks(execution, created_tasks)
      else
        Rails.logger.info "No tasks to wait for in this level, moving to next"
      end
      
      # Check if execution should continue
      break if execution.reload.failed? || execution.cancelled?
    end
    
    # After all levels are processed, check for pending tasks and force execute them
    pending_tasks = execution.workflow_tasks.pending.reload
    if pending_tasks.any?
      Rails.logger.warn "Found #{pending_tasks.count} pending tasks after level processing - force starting all"
      pending_tasks.each do |task|
        Rails.logger.info "Force executing pending task #{task.id} (#{task.title})"
        task.update!(status: 'running', started_at: Time.current)
        timeout_seconds = SimpleWorkflowTaskExecutor.determine_timeout(task, task.assistant)
        WorkflowTaskJob.set(timeout: timeout_seconds).perform_later(task)
      end
      
      # Wait for these tasks to complete
      Rails.logger.info "Waiting for force-started tasks to complete"
      wait_for_created_tasks(execution, pending_tasks.to_a)
    end
    
    # Mark execution as complete if all tasks finished
    execution.reload
    if execution.workflow_tasks.failed.none? && execution.workflow_tasks.pending.none? && execution.workflow_tasks.running.none?
      execution.complete!
      Rails.logger.info "Workflow execution completed successfully"
    elsif execution.workflow_tasks.failed.any?
      failed_count = execution.workflow_tasks.failed.count
      execution.fail!("#{failed_count} task(s) failed")
      Rails.logger.info "Workflow execution failed with #{failed_count} failed tasks"
    end
    
    Rails.logger.info "Workflow execution #{execution.id} finished with status: #{execution.status}"
  rescue => e
    Rails.logger.error "Error in workflow execution #{execution.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    execution.fail!(e.message)
  end
  
  private
  
  def create_and_execute_task(execution, task_data)
    node = task_data[:node]
    node_data = node['data'] || {}
    
    # Skip start/end nodes
    return nil if ['start', 'end'].include?(node['type'])
    
    # Check if task already exists
    existing_task = execution.workflow_tasks.find_by(node_id: node['id'])
    if existing_task
      Rails.logger.info "Task already exists for node #{node['id']}, checking if it needs execution"
      # If the task is pending and dependencies are met, execute it
      if existing_task.pending? && dependencies_met?(execution, task_data[:dependencies])
        Rails.logger.info "Starting existing pending task #{existing_task.id}"
        existing_task.update!(status: 'running', started_at: Time.current)
        WorkflowTaskJob.perform_later(existing_task)
      end
      return existing_task
    end
    
    # Debug logging
    Rails.logger.info "Creating task for node: #{node.inspect}"
    Rails.logger.info "Node data: #{node_data.inspect}"
    Rails.logger.info "Node type: #{node['type']}"
    Rails.logger.info "Assignee data: #{node_data['assignee'].inspect}"
    
    # Extract assistant_id - handle different possible field names and structures
    assistant_id = if node_data['assignee'].is_a?(Hash)
                     node_data['assignee']['id']
                   elsif node_data['assignee'].is_a?(String)
                     node_data['assignee']
                   else
                     node_data['assignee_id'] || 
                     node_data['assistant_id'] ||
                     node_data['assistantId']
                   end
    
    Rails.logger.info "Extracted assistant_id: #{assistant_id}"
    
    # For assistant nodes, the instructions might be in the task field
    instructions = node_data['instructions']
    if node['type'] == 'assistant' && node_data['task']
      instructions = node_data['task']['title'] || instructions
    end
    
    task = execution.workflow_tasks.create!(
      node_id: node['id'],
      title: node_data['title'] || node['type'].humanize,
      instructions: instructions,
      assistant_id: assistant_id,
      status: 'pending'
    )
    
    # Check if dependencies are met
    if dependencies_met?(execution, task_data[:dependencies])
      Rails.logger.info "Dependencies met for task #{task.id}, starting execution"
      # Start the task execution
      task.update!(status: 'running', started_at: Time.current)
      # Queue task execution job
      timeout_seconds = SimpleWorkflowTaskExecutor.determine_timeout(task, task.assistant)
      WorkflowTaskJob.set(timeout: timeout_seconds).perform_later(task)
    else
      Rails.logger.info "Dependencies not met for task #{task.id}, waiting"
    end
    
    task
  end
  
  def dependencies_met?(execution, dependency_node_ids)
    return true if dependency_node_ids.empty?
    
    dependency_node_ids.all? do |dep_id|
      # Check if the dependency is a start node - these don't create tasks
      dep_node = execution.workflow.flow_definition['nodes'].find { |n| n['id'] == dep_id }
      if dep_node && dep_node['type'] == 'start'
        Rails.logger.info "Dependency #{dep_id} is a start node, considering it met"
        return true
      end
      
      # Otherwise check for completed task
      dep_task = execution.workflow_tasks.find_by(node_id: dep_id)
      if dep_task
        Rails.logger.info "Dependency #{dep_id} task status: #{dep_task.status}"
        dep_task.completed?
      else
        Rails.logger.warn "Dependency #{dep_id} has no task created"
        false
      end
    end
  end
  
  def wait_for_created_tasks(execution, created_tasks)
    max_wait = 5.minutes
    start_time = Time.current
    task_ids = created_tasks.map(&:id)
    
    loop do
      # Reload execution to ensure we have fresh data
      execution.reload
      
      # Reload tasks to get current status
      tasks = execution.workflow_tasks.where(id: task_ids).reload
      
      # Log current status
      status_counts = tasks.pluck(:status).tally
      Rails.logger.info "Waiting for #{tasks.count} tasks. Status: #{status_counts}"
      
      # Check for pending tasks that might need to be started
      pending_tasks = tasks.where(status: 'pending')
      if pending_tasks.any?
        Rails.logger.info "Checking dependencies for #{pending_tasks.count} pending tasks"
        pending_tasks.each do |task|
          # Find the task's dependencies from the workflow
          node = execution.workflow.flow_definition['nodes'].find { |n| n['id'] == task.node_id }
          edges = execution.workflow.flow_definition['edges'] || []
          dependency_node_ids = edges.select { |e| e['target'] == task.node_id }.map { |e| e['source'] }
          
          if dependencies_met?(execution, dependency_node_ids)
            Rails.logger.info "Dependencies now met for task #{task.id}, starting execution"
            task.update!(status: 'running', started_at: Time.current)
            timeout_seconds = SimpleWorkflowTaskExecutor.determine_timeout(task, task.assistant)
        WorkflowTaskJob.set(timeout: timeout_seconds).perform_later(task)
          end
        end
      end
      
      # Only count running/completed/failed tasks, not pending
      active_tasks = tasks.where.not(status: 'pending')
      if active_tasks.any? && active_tasks.all? { |t| t.completed? || t.failed? || t.cancelled? }
        Rails.logger.info "All active tasks finished"
        break
      end
      
      # If we only have pending tasks and they've been pending for too long, force start them
      if tasks.all? { |t| t.status == 'pending' } && (Time.current - start_time > 30.seconds)
        Rails.logger.warn "All tasks still pending after 30 seconds, force starting them"
        tasks.each do |task|
          Rails.logger.info "Force starting task #{task.id} (#{task.title})"
          task.update!(status: 'running', started_at: Time.current)
          timeout_seconds = SimpleWorkflowTaskExecutor.determine_timeout(task, task.assistant)
        WorkflowTaskJob.set(timeout: timeout_seconds).perform_later(task)
        end
        # Wait a moment for the status to update
        sleep 1
      end
      
      # Timeout check
      if Time.current - start_time > max_wait
        Rails.logger.warn "Timeout waiting for tasks completion in execution #{execution.id}"
        # Mark running tasks as failed
        tasks.where(status: 'running').update_all(
          status: 'failed',
          completed_at: Time.current,
          result_data: { error: 'Execution timeout' }
        )
        # Mark pending tasks as cancelled
        tasks.where(status: 'pending').update_all(
          status: 'cancelled',
          completed_at: Time.current
        )
        break
      end
      
      # Wait a bit before checking again
      # Using a shorter interval since tasks will broadcast their completion
      sleep 0.5
    end
  end
  
  def wait_for_level_completion(execution, level_tasks)
    max_wait = 5.minutes
    start_time = Time.current
    
    # Skip waiting if no actual tasks to wait for (e.g., only start/end nodes)
    actual_task_nodes = level_tasks.reject { |t| ['start', 'end'].include?(t[:node]['type']) }
    if actual_task_nodes.empty?
      Rails.logger.info "No actual tasks to wait for in this level"
      return
    end
    
    loop do
      # Check if all tasks in this level are complete
      level_node_ids = actual_task_nodes.map { |t| t[:node]['id'] }
      level_workflow_tasks = execution.workflow_tasks.where(node_id: level_node_ids)
      
      # Log current status
      Rails.logger.info "Waiting for #{level_workflow_tasks.count} tasks. Status: #{level_workflow_tasks.pluck(:status).tally}"
      
      # If no tasks were created, break
      if level_workflow_tasks.empty?
        Rails.logger.warn "No workflow tasks found for nodes: #{level_node_ids}"
        break
      end
      
      # All done if all are completed or failed
      break if level_workflow_tasks.all? { |t| t.completed? || t.failed? || t.cancelled? }
      
      # Timeout check
      if Time.current - start_time > max_wait
        Rails.logger.warn "Timeout waiting for level completion in execution #{execution.id}"
        break
      end
      
      # Wait a bit before checking again
      # Using a shorter interval since tasks will broadcast their completion
      sleep 0.5
    end
  end
end