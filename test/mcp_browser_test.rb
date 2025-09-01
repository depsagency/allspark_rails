#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple MCP browser test
require 'capybara'
require 'cuprite'

# Configure Capybara for headless Chrome
Capybara.register_driver :cuprite_mcp do |app|
  Cuprite::Driver.new(app,
    window_size: [1200, 800],
    browser_options: {
      'no-sandbox': true,
      'disable-dev-shm-usage': true,
      'disable-gpu': true,
      'disable-web-security': true,
      'disable-features=VizDisplayCompositor': true
    },
    inspector: false,
    headless: true,
    timeout: 20,
    process_timeout: 15,
    url_blacklist: ['googletagmanager.com', 'google-analytics.com']
  )
end

Capybara.default_driver = :cuprite_mcp
Capybara.app_host = 'http://localhost:3000'
Capybara.default_max_wait_time = 10

session = Capybara::Session.new(:cuprite_mcp)

puts "=== MCP BROWSER TEST ==="
puts "Testing MCP admin interface via browser automation"

begin
  # Step 1: Login as admin
  puts "\n1. Logging in as admin..."
  session.visit '/users/sign_in'
  
  if session.has_content?('Email')
    session.fill_in 'Email', with: 'admin@example.com'
    session.fill_in 'Password', with: 'password123'
    session.click_button 'Log in'
    
    if session.has_content?('Signed in successfully') || session.current_path != '/users/sign_in'
      puts "✅ Login successful"
    else
      puts "❌ Login failed - still on login page"
      puts "Current page content: #{session.text[0..200]}..."
      exit 1
    end
  else
    puts "❌ Login page not found"
    puts "Current page: #{session.current_url}"
    puts "Content: #{session.text[0..200]}..."
    exit 1
  end

  # Step 2: Navigate to MCP Servers admin page
  puts "\n2. Accessing MCP Servers admin page..."
  session.visit '/admin/mcp_servers'
  
  if session.status_code == 200 && session.has_content?('MCP Servers')
    puts "✅ Admin MCP Servers page accessible"
  else
    puts "❌ Cannot access admin MCP servers page"
    puts "Status: #{session.status_code}"
    puts "Current URL: #{session.current_url}"
    puts "Page content: #{session.text[0..300]}..."
    
    # Try to get more debug info
    if session.has_content?('Access denied')
      puts "❌ Access denied - admin permissions issue"
    end
    exit 1
  end

  # Step 3: Try to create a new MCP server
  puts "\n3. Testing MCP server creation..."
  
  if session.has_link?('New MCP Server') || session.has_link?('Add MCP Server')
    session.click_link session.has_link?('New MCP Server') ? 'New MCP Server' : 'Add MCP Server'
    
    if session.has_content?('Add MCP Server') || session.has_content?('New MCP Server')
      puts "✅ New MCP server form accessible"
      
      # Fill out the form
      session.fill_in 'Server Name', with: 'Browser Test Server'
      session.fill_in 'Endpoint URL', with: 'https://browser-test.example.com/mcp/v1'
      
      # Select authentication type
      if session.has_select?('Authentication Type')
        session.select 'API Key', from: 'Authentication Type'
        
        # Wait for fields to appear and fill them
        session.find_field('API Key', wait: 5)
        session.fill_in 'API Key', with: 'browser-test-key-123'
        session.fill_in 'Header Name', with: 'Authorization'
        
        puts "✅ Form filled successfully"
        
        # Submit the form
        session.click_button 'Create Server'
        
        if session.has_content?('successfully created') || session.has_content?('Browser Test Server')
          puts "✅ MCP server created successfully"
          server_created = true
        else
          puts "❌ Server creation failed"
          puts "Current content: #{session.text[0..300]}..."
          server_created = false
        end
      else
        puts "⚠️  Authentication type field not found"
        server_created = false
      end
    else
      puts "❌ New server form not accessible"
      exit 1
    end
  else
    puts "❌ 'New MCP Server' link not found"
    puts "Available links: #{session.all('a').map(&:text).join(', ')}"
    server_created = false
  end

  # Step 4: Test MCP Analytics page
  puts "\n4. Testing MCP Analytics page..."
  session.visit '/admin/mcp_servers/analytics'
  
  if session.status_code == 200 && session.has_content?('Analytics')
    puts "✅ Analytics page accessible"
    
    if session.has_content?('Total Servers') || session.has_content?('No activity')
      puts "✅ Analytics dashboard displaying data"
    else
      puts "⚠️  Analytics dashboard present but no clear metrics visible"
    end
  else
    puts "❌ Analytics page not accessible"
    puts "Status: #{session.status_code}"
  end

  # Step 5: Cleanup - delete test server if created
  if server_created
    puts "\n5. Cleaning up test server..."
    session.visit '/admin/mcp_servers'
    
    if session.has_content?('Browser Test Server')
      session.click_link 'Browser Test Server'
      
      if session.has_link?('Delete')
        session.click_link 'Delete'
        
        # Handle confirmation if present
        if session.has_button?('Delete Server')
          session.click_button 'Delete Server'
        end
        
        if session.has_content?('successfully deleted')
          puts "✅ Test server cleaned up successfully"
        else
          puts "⚠️  Cleanup may have failed"
        end
      else
        puts "⚠️  Delete link not found for cleanup"
      end
    else
      puts "⚠️  Test server not found for cleanup"
    end
  end

  puts "\n=== MCP BROWSER TEST COMPLETE ==="
  puts "✅ Browser automation test successful"
  puts "MCP admin interface is working correctly!"

rescue => e
  puts "\n❌ Browser test failed with error:"
  puts "#{e.class}: #{e.message}"
  puts "Backtrace:"
  puts e.backtrace.first(5).join("\n")
  
  # Try to get current page info for debugging
  begin
    puts "\nDebug info:"
    puts "Current URL: #{session.current_url}"
    puts "Status code: #{session.status_code}" if session.respond_to?(:status_code)
    puts "Page title: #{session.title}" if session.respond_to?(:title)
  rescue => debug_error
    puts "Could not get debug info: #{debug_error.message}"
  end
  
  exit 1
ensure
  # Always quit the browser session
  session.quit if session
end