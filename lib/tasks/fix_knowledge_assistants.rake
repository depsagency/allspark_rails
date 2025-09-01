namespace :allspark do
  desc "Fix knowledge base and assistants screenshots"
  task fix_knowledge_assistants: :environment do
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
        
        # Fix Knowledge Base screenshot
        puts "\n📸 Capturing Knowledge Base..."
        runner.visit('/agents/knowledge_documents')
        sleep 3
        temp_path = runner.take_screenshot('fix_knowledge_base')
        FileUtils.cp(temp_path, screenshot_dir.join('knowledge-base.png'))
        puts "✅ Saved knowledge-base.png"
        
        # Fix Assistants screenshot
        puts "\n📸 Capturing AI Assistants..."
        runner.visit('/agents/assistants')
        sleep 3
        temp_path = runner.take_screenshot('fix_assistants_list')
        FileUtils.cp(temp_path, screenshot_dir.join('assistants-list.png'))
        puts "✅ Saved assistants-list.png"
      end
      
      puts "\n✅ Screenshots fixed successfully!"
      
    rescue => e
      puts "❌ Error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end
end