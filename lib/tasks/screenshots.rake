namespace :screenshots do
  desc "Capture screenshots of specific pages after logging in"
  task :capture => :environment do
    require 'capybara/rails'
    require 'capybara/cuprite'
    
    # Configure Capybara
    Capybara.default_driver = :cuprite_headless
    Capybara.javascript_driver = :cuprite_headless
    
    Capybara.register_driver :cuprite_headless do |app|
      Capybara::Cuprite::Driver.new(app,
        browser_path: '/usr/bin/chromium',
        browser_options: {
          'no-sandbox' => nil,
          'disable-gpu' => nil,
          'disable-dev-shm-usage' => nil,
          'disable-software-rasterizer' => nil,
          'disable-extensions' => nil,
          'disable-setuid-sandbox' => nil
        },
        process_timeout: 30,
        timeout: 15,
        js_errors: false,
        window_size: [1920, 1080],
        headless: true
      )
    end
    
    include Capybara::DSL
    
    Rails.application.load_seed
    
    output_dir = '/app/docs/strategy/allspark-product-deck/assets'
    FileUtils.mkdir_p(output_dir)
    
    # Start Rails server
    Capybara.server = :puma
    Capybara.server_host = '0.0.0.0'
    Capybara.server_port = 3001
    Capybara.app = Rails.application
    
    puts "Starting screenshot capture..."
    
    # Visit login page
    visit '/users/sign_in'
    
    # Fill in login form
    within('form') do
      fill_in 'Email address', with: 'admin@example.com'
      fill_in 'Password', with: 'password123'
      click_button 'Sign in'
    end
    
    sleep 2
    puts "✅ Logged in as admin"
    
    # Capture screenshots
    pages = [
      { path: '/mcp_configurations', filename: 'mcp-configs.png', name: 'MCP Configurations' },
      { path: '/integrations', filename: 'integrations.png', name: 'Integrations' },
      { path: '/agents/monitoring', filename: 'monitoring.png', name: 'Monitoring' }
    ]
    
    pages.each do |page|
      begin
        puts "Capturing #{page[:name]}..."
        visit page[:path]
        sleep 2
        
        output_path = File.join(output_dir, page[:filename])
        save_screenshot(output_path)
        puts "✅ Saved: #{page[:filename]}"
      rescue => e
        puts "❌ Error capturing #{page[:name]}: #{e.message}"
      end
    end
    
    # Special handling for Claude Code
    begin
      puts "Capturing Claude Code..."
      visit '/instances'
      sleep 2
      
      # Click on the first instance if available
      if has_css?('a[href^="/instances/"]')
        first('a[href^="/instances/"]').click
        sleep 2
        
        # Look for Claude Code link
        if has_link?('Claude Code')
          click_link 'Claude Code'
          sleep 2
          
          output_path = File.join(output_dir, 'claude-code.png')
          save_screenshot(output_path)
          puts "✅ Saved: claude-code.png"
        else
          puts "❌ Claude Code link not found on instance page"
        end
      else
        puts "❌ No instances found"
      end
    rescue => e
      puts "❌ Error capturing Claude Code: #{e.message}"
    end
    
    puts "\nScreenshot capture complete!"
  end
end