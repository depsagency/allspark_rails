# frozen_string_literal: true

namespace :browser do
  desc "Take all screenshots needed for the product presentation"
  task screenshot_all: :environment do
    screenshots = [
      { path: '/', name: 'Homepage/Dashboard' },
      { path: '/instances', name: 'Instance Dashboard' },
      { path: '/app_projects', name: 'Projects List' },
      { path: '/app_projects/new', name: 'Project Builder' },
      { path: '/assistants', name: 'AI Assistants' },
      { path: '/agent_teams', name: 'Agent Teams' },
      { path: '/knowledge_documents', name: 'Knowledge Base' },
      { path: '/chat', name: 'Chat Interface' },
      { path: '/mcp_configs', name: 'MCP Configurations' },
      { path: '/claude_cli_sessions', name: 'Claude Code Sessions' },
      { path: '/oauth_integrations', name: 'Integrations' },
      { path: '/monitoring', name: 'Monitoring Dashboard' }
    ]
    
    puts "📸 Taking screenshots for AllSpark product presentation..."
    puts "=" * 60
    
    success_count = 0
    failed_count = 0
    
    screenshots.each_with_index do |screenshot, index|
      puts "\n[#{index + 1}/#{screenshots.length}] #{screenshot[:name]}"
      puts "URL: #{screenshot[:path]}"
      
      begin
        # Use system call to avoid output pollution
        result = system("docker-compose exec -T web bundle exec rake 'browser:screenshot[#{screenshot[:path]}]' > /dev/null 2>&1")
        
        if result
          puts "✅ Success"
          success_count += 1
        else
          puts "❌ Failed"
          failed_count += 1
        end
      rescue => e
        puts "❌ Error: #{e.message}"
        failed_count += 1
      end
      
      # Small delay between screenshots
      sleep 1
    end
    
    puts "\n" + "=" * 60
    puts "📊 Summary:"
    puts "✅ Successful: #{success_count}"
    puts "❌ Failed: #{failed_count}"
    puts "\nScreenshots saved to: docs/strategy/allspark-product-deck/assets/"
  end
  
  desc "Login and take screenshots of authenticated pages"
  task screenshot_authenticated: :environment do
    # This would require implementing login functionality in the browser testing framework
    puts "Note: For authenticated screenshots, you'll need to:"
    puts "1. Login with admin@example.com / password123"
    puts "2. Navigate to each page manually"
    puts "3. Use browser developer tools to capture screenshots"
    puts "\nOr implement automated login in the browser testing framework."
  end
end