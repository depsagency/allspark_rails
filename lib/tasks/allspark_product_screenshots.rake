# frozen_string_literal: true

namespace :allspark do
  desc "Take all screenshots for the AllSpark product presentation (with authentication)"
  task product_screenshots: :environment do
    puts "📸 Starting AllSpark Product Screenshots..."
    puts "=" * 60
    
    # Ensure browser testing dependencies are loaded
    require 'capybara'
    require 'capybara/cuprite'
    
    # Configure Capybara (reuse the config from browser_test.rake)
    load Rails.root.join('lib/tasks/browser_test.rake')
    
    unless defined?(BrowserTesting::TestRunner)
      puts "❌ Browser testing not configured properly"
      exit 1
    end
    
    # Screenshot directory
    screenshot_dir = Rails.root.join('docs', 'strategy', 'allspark-product-deck', 'assets')
    FileUtils.mkdir_p(screenshot_dir)
    
    # Create a custom runner that can handle authentication
    runner = BrowserTesting::TestRunner.new
    
    # Screenshots to capture
    screenshots = [
      { path: '/', name: 'homepage.png', description: 'Dashboard' },
      { path: '/instances', name: 'instance-dashboard.png', description: 'Instances' },
      { path: '/app_projects', name: 'projects-list.png', description: 'Projects List' },
      { path: '/app_projects/new', name: 'project-builder.png', description: 'Project Builder' },
      { path: '/assistants', name: 'assistants-list.png', description: 'AI Assistants' },
      { path: '/agent_teams', name: 'agent-teams.png', description: 'Agent Teams' },
      { path: '/knowledge_documents', name: 'knowledge-base.png', description: 'Knowledge Base' },
      { path: '/chat', name: 'chat-interface.png', description: 'Chat' },
      { path: '/mcp_configs', name: 'mcp-configs.png', description: 'MCP Configurations' },
      { path: '/claude_cli_sessions', name: 'claude-code.png', description: 'Claude Code' },
      { path: '/oauth_integrations', name: 'integrations.png', description: 'Integrations' },
      { path: '/monitoring', name: 'monitoring.png', description: 'Monitoring' },
      { path: '/settings', name: 'security-settings.png', description: 'Settings' }
    ]
    
    begin
      runner.with_session do |session|
        # Login first
        puts "🔐 Logging in as admin..."
        runner.visit('/users/sign_in')
        session.fill_in 'Email', with: 'admin@example.com'
        session.fill_in 'Password', with: 'password123'
        session.click_button 'Log in'
        
        # Wait for login to complete
        sleep 3
        
        # Verify login worked
        if session.has_content?('Dashboard', wait: 5)
          puts "✅ Logged in successfully"
        else
          puts "❌ Login failed"
          exit 1
        end
        
        # Take screenshots
        screenshots.each_with_index do |screenshot_info, index|
          puts "\n[#{index + 1}/#{screenshots.length}] #{screenshot_info[:description]}"
          
          begin
            runner.visit(screenshot_info[:path])
            sleep 3  # Wait for page to fully load
            
            # Take screenshot
            temp_path = runner.take_screenshot("allspark_product_#{index}")
            
            # Copy to final location
            final_path = File.join(screenshot_dir, screenshot_info[:name])
            FileUtils.cp(temp_path, final_path)
            
            puts "✅ Saved to: #{screenshot_info[:name]}"
          rescue => e
            puts "❌ Failed: #{e.message}"
          end
        end
      end
      
      # Summary
      puts "\n" + "=" * 60
      puts "📊 Screenshot Summary:"
      saved_screenshots = Dir[File.join(screenshot_dir, "*.png")]
      saved_screenshots.each do |file|
        size = File.size(file) / 1024
        puts "✅ #{File.basename(file)} (#{size}KB)"
      end
      puts "Total: #{saved_screenshots.count} screenshots"
      puts "Location: #{screenshot_dir}"
      
    rescue => e
      puts "❌ Error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end
end