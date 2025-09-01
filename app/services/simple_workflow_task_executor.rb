require 'timeout'

class SimpleWorkflowTaskExecutor
  def self.execute_task(task)
    Rails.logger.info "[SIMPLE_EXECUTOR] Starting execution of task #{task.id}"
    
    # Ensure task is running
    unless task.update(status: 'running', started_at: Time.current)
      Rails.logger.error "[SIMPLE_EXECUTOR] Failed to set task to running"
      return false
    end
    
    Rails.logger.info "[SIMPLE_EXECUTOR] Task set to running"
    
    # Determine timeout for this task
    timeout_seconds = determine_timeout(task, task.assistant)
    Rails.logger.info "[SIMPLE_EXECUTOR] Using timeout of #{timeout_seconds} seconds"
    
    # Execute with assistant
    begin
      assistant = task.assistant
      if assistant.nil?
        Rails.logger.error "[SIMPLE_EXECUTOR] No assistant assigned"
        task.update!(status: 'failed', completed_at: Time.current, result_data: { error: 'No assistant assigned' })
        return false
      end
      
      Rails.logger.info "[SIMPLE_EXECUTOR] Executing with assistant #{assistant.name}"
      
      # Use the timeout we determined earlier
      Rails.logger.info "[SIMPLE_EXECUTOR] Executing with timeout of #{timeout_seconds} seconds"
      
      # Call the assistant's run method directly with a timeout
      result = nil
      Timeout::timeout(timeout_seconds) do
        # Build context with previous task outputs
        full_context = build_task_context(task)
        
        result = assistant.run(
          content: full_context,
          run_id: "workflow-task-#{task.id}",
          user: task.workflow_execution.user
        )
      end
      
      Rails.logger.info "[SIMPLE_EXECUTOR] Assistant run completed"
      
      # Extract content
      content = result.content || ""
      Rails.logger.info "[SIMPLE_EXECUTOR] Got response of #{content.length} characters"
      
      # First try using the model's mark_complete method
      task.reload
      if task.running?
        success = task.mark_complete(output: content)
        if success
          Rails.logger.info "[SIMPLE_EXECUTOR] Task marked complete via model method"
          return true
        end
      end
      
      # If that didn't work, use direct SQL as last resort
      Rails.logger.warn "[SIMPLE_EXECUTOR] Model update failed, using direct SQL"
      updated = WorkflowTask.where(id: task.id, status: 'running').update_all(
        status: 'completed',
        completed_at: Time.current,
        result_data: { output: content },
        updated_at: Time.current
      )
      
      Rails.logger.info "[SIMPLE_EXECUTOR] SQL update affected #{updated} rows"
      
      if updated > 0
        task.reload
        Rails.logger.info "[SIMPLE_EXECUTOR] Task status after update: #{task.status}"
        
        # Manually ensure critical operations happen
        begin
          task.broadcast_status_update
        rescue => e
          Rails.logger.error "[SIMPLE_EXECUTOR] Failed to broadcast: #{e.message}"
        end
        
        begin
          task.trigger_next_tasks
        rescue => e
          Rails.logger.error "[SIMPLE_EXECUTOR] Failed to trigger next tasks: #{e.message}"
        end
        
        Rails.logger.info "[SIMPLE_EXECUTOR] Task #{task.id} completed successfully"
        return true
      else
        Rails.logger.error "[SIMPLE_EXECUTOR] SQL update failed - task may no longer be running"
        return false
      end
      
    rescue Timeout::Error => e
      timeout_minutes = (determine_timeout(task, task.assistant) / 60.0).round(1)
      Rails.logger.error "[SIMPLE_EXECUTOR] Task execution timed out after #{timeout_minutes} minutes"
      
      WorkflowTask.where(id: task.id).update_all(
        status: 'failed',
        completed_at: Time.current,
        result_data: { error: "Task execution timed out after #{timeout_minutes} minutes" },
        updated_at: Time.current
      )
      
      return false
    rescue => e
      Rails.logger.error "[SIMPLE_EXECUTOR] Error during execution: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      WorkflowTask.where(id: task.id).update_all(
        status: 'failed',
        completed_at: Time.current,
        result_data: { error: e.message },
        updated_at: Time.current
      )
      
      return false
    end
  end
  
  def self.build_task_context(task)
    Rails.logger.info "[CONTEXT_BUILDER] Building context for task #{task.id} (#{task.title})"
    
    workflow = task.workflow_execution.workflow
    flow_definition = workflow.flow_definition
    edges = flow_definition['edges'] || []
    
    # Find all incoming edges to this task
    incoming_edges = edges.select { |e| e['target'] == task.node_id }
    Rails.logger.info "[CONTEXT_BUILDER] Found #{incoming_edges.count} incoming edges"
    
    # Build context parts
    context_parts = []
    
    # Add current task instructions
    if task.instructions.present?
      context_parts << "## Your Task:\n#{task.instructions}"
    else
      context_parts << "## Your Task:\nExecute task: #{task.title}"
    end
    
    # Gather outputs from predecessor tasks
    if incoming_edges.any?
      context_parts << "\n## Context from Previous Tasks:"
      
      incoming_edges.each_with_index do |edge, index|
        source_task = task.workflow_execution.workflow_tasks.find_by(node_id: edge['source'])
        
        if source_task && source_task.completed? && source_task.result_data.present?
          output = source_task.result_data['output'] || source_task.result_data[:output]
          
          if output.present?
            context_parts << "\n### Output from \"#{source_task.title}\":"
            context_parts << output.to_s
          else
            Rails.logger.warn "[CONTEXT_BUILDER] Source task #{source_task.id} completed but has no output"
          end
        else
          Rails.logger.warn "[CONTEXT_BUILDER] Source task for edge #{edge.inspect} not found or not completed"
        end
      end
    else
      Rails.logger.info "[CONTEXT_BUILDER] No predecessor tasks - this is likely a starting task"
    end
    
    # Join all context parts
    full_context = context_parts.join("\n\n")
    
    Rails.logger.info "[CONTEXT_BUILDER] Built context of #{full_context.length} characters"
    Rails.logger.debug "[CONTEXT_BUILDER] Context: #{full_context[0..500]}#{'...' if full_context.length > 500}"
    
    full_context
  end
  
  def self.determine_timeout(task, assistant)
    # First check if the node has a specific timeout configured
    workflow = task.workflow_execution.workflow
    node = workflow.flow_definition['nodes'].find { |n| n['id'] == task.node_id }
    
    if node && node['data'] && node['data']['timeout']
      configured_timeout = node['data']['timeout'].to_i
      if configured_timeout > 0
        Rails.logger.info "[SIMPLE_EXECUTOR] Using node-configured timeout: #{configured_timeout} seconds"
        return configured_timeout
      end
    end
    
    # Check workflow-level default timeout
    if workflow.flow_definition['settings'] && workflow.flow_definition['settings']['default_task_timeout']
      default_timeout = workflow.flow_definition['settings']['default_task_timeout'].to_i
      if default_timeout > 0
        Rails.logger.info "[SIMPLE_EXECUTOR] Using workflow default timeout: #{default_timeout} seconds"
        return default_timeout
      end
    end
    
    # Check if task has coding tools
    has_coding_tools = assistant.tools.any? do |tool|
      ['ruby_code_interpreter', 'ruby_code', 'claude_code'].include?(tool['type'])
    end
    
    # Check task instructions for coding keywords
    coding_keywords = ['code', 'implement', 'develop', 'create', 'build', 'write', 'program', 'script', 'function', 'class', 'method']
    instructions = (task.instructions || '').downcase
    appears_to_be_coding = coding_keywords.any? { |keyword| instructions.include?(keyword) }
    
    # Determine timeout based on task type
    if has_coding_tools || appears_to_be_coding
      Rails.logger.info "[SIMPLE_EXECUTOR] Task appears to be coding-related, using extended timeout"
      600  # 10 minutes for coding tasks
    else
      Rails.logger.info "[SIMPLE_EXECUTOR] Task appears to be non-coding, using standard timeout"
      180  # 3 minutes for regular tasks
    end.clamp(60, 1800)  # Ensure timeouts are between 1 minute and 30 minutes
  end
end