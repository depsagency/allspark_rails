require_relative '../test_helper'
require_relative '../../app/services/browser_testing/browser_test_service'

class TestChatLayout < ActiveSupport::TestCase
  def test_chat_layout
    service = BrowserTesting::BrowserTestService.new
    
    begin
      # Navigate to login page
      service.visit('/users/sign_in')
      
      # Log in as admin
      service.fill_in('user[email]', with: 'admin@example.com')
      service.fill_in('user[password]', with: 'password123')
      service.click_button('Log in')
      
      # Wait for redirect
      service.wait_for_navigation
      
      # Navigate to chat page
      service.visit('/chat')
      
      # Wait for page to load
      service.wait_for_selector('.chat-container', timeout: 10)
      
      # Take screenshot
      screenshot_path = service.take_screenshot('chat_layout')
      puts "Screenshot saved to: #{screenshot_path}"
      
      # Check for errors
      errors = service.check_for_errors
      
      if errors.empty?
        puts "✅ No errors found on chat page"
      else
        puts "❌ Errors found:"
        errors.each_with_index do |error, i|
          puts "\nError #{i + 1}:"
          puts "  Type: #{error[:type]}"
          puts "  Message: #{error[:message]}"
          puts "  Details: #{error[:details]}" if error[:details]
        end
      end
      
      # Check specific chat elements
      puts "\n📋 Chat Layout Analysis:"
      
      # Check for chat threads sidebar
      if service.has_selector?('.chat-threads-sidebar')
        puts "✓ Chat threads sidebar found"
      else
        puts "✗ Chat threads sidebar missing"
      end
      
      # Check for thread list
      if service.has_selector?('.thread-list')
        puts "✓ Thread list found"
      else
        puts "✗ Thread list missing"
      end
      
      # Check for chat messages area
      if service.has_selector?('.chat-messages')
        puts "✓ Chat messages area found"
      else
        puts "✗ Chat messages area missing"
      end
      
      # Check for message input
      if service.has_selector?('.message-input')
        puts "✓ Message input found"
      else
        puts "✗ Message input missing"
      end
      
      # Check layout structure
      chat_container = service.find('.chat-container') rescue nil
      if chat_container
        puts "\n📐 Container structure:"
        puts "  Width: #{service.execute_script("return document.querySelector('.chat-container').offsetWidth")}px"
        puts "  Height: #{service.execute_script("return document.querySelector('.chat-container').offsetHeight")}px"
        
        # Check if using flexbox or grid
        display = service.execute_script("return window.getComputedStyle(document.querySelector('.chat-container')).display")
        puts "  Display: #{display}"
      end
      
      # Get any console errors
      console_errors = service.console_messages.select { |msg| msg[:type] == 'error' }
      if console_errors.any?
        puts "\n🔴 JavaScript Console Errors:"
        console_errors.each do |error|
          puts "  - #{error[:text]}"
        end
      end
      
    ensure
      service.quit
    end
  end
end

# Run the test
test = TestChatLayout.new
test.test_chat_layout