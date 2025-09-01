namespace :workflow do
  desc "Debug workflow task execution"
  task debug_task: :environment do
    # Find the most recent workflow task
    task = WorkflowTask.order(created_at: :desc).first
    
    if task
      puts "Most recent task:"
      puts "  ID: #{task.id}"
      puts "  Title: #{task.title}"
      puts "  Status: #{task.status}"
      puts "  Node ID: #{task.node_id}"
      puts "  Assistant: #{task.assistant&.name || 'None'}"
      puts "  Created: #{task.created_at}"
      puts "  Started: #{task.started_at}"
      puts "  Completed: #{task.completed_at}"
      puts ""
      
      if task.running?
        puts "Task is still running. Attempting to complete it..."
        
        # Try to mark it complete
        result = task.mark_complete(output: "Debug completion")
        puts "Mark complete result: #{result}"
        
        task.reload
        puts "Status after mark_complete: #{task.status}"
        
        if task.running?
          puts "Still running. Trying direct update..."
          updated = WorkflowTask.where(id: task.id, status: 'running').update_all(
            status: 'completed',
            completed_at: Time.current,
            updated_at: Time.current
          )
          puts "Direct update affected #{updated} rows"
          
          task.reload
          puts "Status after direct update: #{task.status}"
        end
      end
    else
      puts "No workflow tasks found"
    end
  end
  
  desc "Force complete stuck workflow tasks"
  task force_complete: :environment do
    stuck_tasks = WorkflowTask.where(status: 'running').where('started_at < ?', 1.minute.ago)
    
    puts "Found #{stuck_tasks.count} stuck tasks"
    
    stuck_tasks.each do |task|
      puts "\nProcessing task #{task.id} (#{task.title})"
      puts "  Started: #{task.started_at}"
      puts "  Status: #{task.status}"
      
      # Force complete the task
      updated = WorkflowTask.where(id: task.id, status: 'running').update_all(
        status: 'completed',
        completed_at: Time.current,
        result_data: { note: 'Force completed due to stuck status' },
        updated_at: Time.current
      )
      
      if updated > 0
        puts "  ✓ Force completed"
        task.reload
        task.broadcast_status_update
        task.trigger_next_tasks
      else
        puts "  ✗ Failed to update"
      end
    end
  end
  
  desc "Show workflow execution status"
  task :status, [:execution_id] => :environment do |t, args|
    if args[:execution_id]
      execution = WorkflowExecution.find(args[:execution_id])
    else
      execution = WorkflowExecution.order(created_at: :desc).first
    end
    
    if execution
      puts "Workflow Execution: #{execution.id}"
      puts "  Status: #{execution.status}"
      puts "  Created: #{execution.created_at}"
      puts "  Workflow: #{execution.workflow.name}"
      puts ""
      puts "Tasks:"
      
      execution.workflow_tasks.order(:created_at).each do |task|
        puts "  #{task.node_id}:"
        puts "    Title: #{task.title}"
        puts "    Status: #{task.status}"
        puts "    Started: #{task.started_at}"
        puts "    Completed: #{task.completed_at}"
        puts "    Assistant: #{task.assistant&.name || 'None'}"
        if task.result_data.present?
          puts "    Result: #{task.result_data.to_json[0..100]}..."
        end
      end
    else
      puts "No workflow execution found"
    end
  end
end