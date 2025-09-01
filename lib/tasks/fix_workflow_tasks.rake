namespace :workflow do
  desc "Fix existing workflow tasks that don't have assistants assigned"
  task fix_missing_assistants: :environment do
    # Find all workflow tasks without assistants
    tasks_without_assistant = WorkflowTask.where(assistant_id: nil)
    
    puts "Found #{tasks_without_assistant.count} tasks without assistants"
    
    fixed_count = 0
    failed_count = 0
    
    tasks_without_assistant.each do |task|
      begin
        workflow = task.workflow
        node = workflow.flow_definition['nodes'].find { |n| n['id'] == task.node_id }
        
        if node && node['data'] && node['data']['assignee']
          assignee = node['data']['assignee']
          assistant_id = assignee.is_a?(Hash) ? assignee['id'] : assignee
          
          if assistant_id
            # Check if assistant exists
            assistant = Assistant.find_by(id: assistant_id)
            if assistant
              task.update!(assistant_id: assistant_id)
              puts "✓ Fixed task #{task.id} (#{task.title}) - assigned assistant: #{assistant.name}"
              fixed_count += 1
            else
              puts "✗ Task #{task.id} (#{task.title}) - assistant not found: #{assistant_id}"
              failed_count += 1
            end
          else
            puts "✗ Task #{task.id} (#{task.title}) - no assistant ID in assignee data"
            failed_count += 1
          end
        else
          puts "✗ Task #{task.id} (#{task.title}) - no assignee data found in node"
          failed_count += 1
        end
      rescue => e
        puts "✗ Task #{task.id} - Error: #{e.message}"
        failed_count += 1
      end
    end
    
    puts "\nSummary:"
    puts "  Fixed: #{fixed_count} tasks"
    puts "  Failed: #{failed_count} tasks"
    puts "  Total: #{tasks_without_assistant.count} tasks"
  end
end