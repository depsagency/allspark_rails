require 'capybara/dsl'
require 'capybara/cuprite'
require 'fileutils'

# Configure Capybara
Capybara.default_driver = :cuprite
Capybara.javascript_driver = :cuprite
Capybara.app_host = 'http://localhost:3000'
Capybara.server = :puma
Capybara.server_host = '0.0.0.0'
Capybara.server_port = 3001

Capybara.register_driver :cuprite do |app|
  Capybara::Cuprite::Driver.new(app,
    browser_path: '/usr/bin/chromium',
    browser_options: {
      'no-sandbox' => nil,
      'disable-gpu' => nil,
      'disable-dev-shm-usage' => nil,
      'disable-software-rasterizer' => nil,
      'disable-extensions' => nil,
      'single-process' => nil
    },
    process_timeout: 30,
    timeout: 15,
    js_errors: false,
    window_size: [1920, 1080],
    inspector: false,
    headless: true
  )
end

class ScreenshotCapture
  include Capybara::DSL

  def initialize
    @output_dir = '/app/docs/strategy/allspark-product-deck/assets'
    FileUtils.mkdir_p(@output_dir)
  end

  def login_as_admin
    visit '/login'
    fill_in 'user_email', with: 'admin@example.com'
    fill_in 'user_password', with: 'password123'
    click_button 'Sign in'
    sleep 2 # Wait for login to complete
  end

  def capture_page(path, filename, options = {})
    begin
      puts "Capturing #{path}..."
      
      if options[:via_instances]
        # Special handling for Claude Code
        visit '/instances'
        sleep 2
        
        # Click on the first instance
        first('a[href^="/instances/"]').click
        sleep 2
        
        # Look for Claude Code link
        if has_link?('Claude Code')
          click_link 'Claude Code'
          sleep 2
        else
          puts "Claude Code link not found"
          return false
        end
      else
        visit path
        sleep 2
      end
      
      # Save screenshot
      output_path = File.join(@output_dir, filename)
      save_screenshot(output_path)
      puts "✅ Saved: #{filename}"
      true
    rescue => e
      puts "❌ Error capturing #{path}: #{e.message}"
      false
    end
  end

  def run
    puts "Starting screenshot capture..."
    
    # Login first
    login_as_admin
    puts "✅ Logged in as admin"
    
    # Capture each page
    pages = [
      { path: '/mcp_configurations', filename: 'mcp-configs.png' },
      { path: '/integrations', filename: 'integrations.png' },
      { path: '/agents/monitoring', filename: 'monitoring.png' },
      { path: '/instances', filename: 'claude-code.png', via_instances: true }
    ]
    
    pages.each do |page|
      capture_page(page[:path], page[:filename], page)
    end
    
    puts "\nScreenshot capture complete!"
  end
end

# Run the screenshot capture
capture = ScreenshotCapture.new
capture.run