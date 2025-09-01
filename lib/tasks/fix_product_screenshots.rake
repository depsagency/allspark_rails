namespace :allspark do
  desc "Fix product deck screenshots with correct routes"
  task fix_product_screenshots: :environment do
    require 'capybara'
    require 'capybara/cuprite'
    
    # Load browser testing setup
    load Rails.root.join('lib/tasks/browser_test.rake')
    
    runner = BrowserTesting::TestRunner.new
    screenshot_dir = Rails.root.join('docs', 'strategy', 'allspark-product-deck', 'assets')
    
    begin
      runner.with_session do |session|
        # Login
        puts "🔐 Logging in..."
        runner.visit('/users/sign_in')
        session.fill_in 'Email', with: 'admin@example.com'
        session.fill_in 'Password', with: 'password123'
        session.click_button 'Log in'
        sleep 2
        
        # Verify login
        if session.has_content?('Dashboard', wait: 3)
          puts "✅ Logged in successfully"
        else
          puts "❌ Login failed"
          exit 1
        end
        
        # Screenshots with correct routes
        screenshots = [
          { path: '/mcp_configurations', file: 'mcp-configs.png', name: 'MCP Configurations' },
          { path: '/integrations', file: 'integrations.png', name: 'Integrations' },
          { path: '/agents/monitoring', file: 'monitoring.png', name: 'Monitoring' }
        ]
        
        screenshots.each do |shot|
          begin
            puts "\n📸 Capturing #{shot[:name]}..."
            runner.visit(shot[:path])
            sleep 2
            
            # Check for errors
            if session.has_content?('Routing Error', wait: 1)
              puts "❌ Route not found: #{shot[:path]}"
              next
            end
            
            # Take screenshot
            temp_path = runner.take_screenshot("fix_#{shot[:file].gsub('.png', '')}")
            FileUtils.cp(temp_path, screenshot_dir.join(shot[:file]))
            puts "✅ Saved #{shot[:file]}"
          rescue => e
            puts "❌ Failed: #{e.message}"
          end
        end
        
        # Claude Code - special handling
        puts "\n📸 Capturing Claude Code..."
        claude_found = false
        
        # Try instances page with Claude Code link
        runner.visit('/instances')
        sleep 2
        
        # Look for Claude Code related content or fallback
        if session.has_css?('.instance-card', wait: 2)
          # Just use instances page showing Claude Code capabilities
          temp_path = runner.take_screenshot('fix_claude_code')
          FileUtils.cp(temp_path, screenshot_dir.join('claude-code.png'))
          puts "✅ Saved claude-code.png (instances view)"
        else
          # Create new instance to show Claude Code option
          runner.visit('/instances/new') 
          sleep 2
          temp_path = runner.take_screenshot('fix_claude_code')
          FileUtils.cp(temp_path, screenshot_dir.join('claude-code.png'))
          puts "✅ Saved claude-code.png (new instance view)"
        end
      end
      
      puts "\n✅ Screenshot fixes completed!"
      
    rescue => e
      puts "❌ Error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end
end