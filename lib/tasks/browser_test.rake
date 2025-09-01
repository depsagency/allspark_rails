# frozen_string_literal: true

namespace :browser do
  
  # Ensure testing gems are available
  def load_browser_testing_dependencies
    begin
      require 'capybara'
      require 'capybara/cuprite'
      
      # Configure Capybara for headless Chrome
      Capybara.register_driver :cuprite do |app|
        browser_path = ENV['CHROME_BIN'] || ENV['CHROMIUM_BIN'] || '/usr/bin/chromium'
        
        # Additional Chrome flags for Docker environments
        browser_options = {
          'no-sandbox' => nil,
          'disable-dev-shm-usage' => nil,
          'disable-gpu' => nil,
          'disable-software-rasterizer' => nil,
          'disable-setuid-sandbox' => nil,
          'disable-features' => 'VizDisplayCompositor',
          'remote-debugging-port' => 9222
        }
        
        # Add container-specific options
        if ENV['DOCKER_CONTAINER']
          browser_options.delete('disable-features')  # Remove duplicate
          browser_options.merge!({
            'disable-web-security' => nil,
            'disable-features' => 'VizDisplayCompositor,TranslateUI,site-per-process',
            'disable-extensions' => nil,
            'disable-default-apps' => nil,
            'disable-background-timer-throttling' => nil,
            'disable-backgrounding-occluded-windows' => nil,
            'disable-renderer-backgrounding' => nil,
            'window-size' => '1280,800'
          })
        end
        
        Capybara::Cuprite::Driver.new(
          app, 
          headless: !ENV['BROWSER_VISIBLE'],
          inspector: ENV['BROWSER_INSPECTOR'],
          js_errors: false,
          timeout: 60,
          process_timeout: 60,
          browser_path: browser_path,
          browser_options: browser_options,
          url_whitelist: ['*']
        )
      end
      
      Capybara.default_driver = :cuprite
      Capybara.javascript_driver = :cuprite
      Capybara.default_max_wait_time = 5
      
      # Load browser testing services
      Dir[Rails.root.join('app/services/browser_testing/*.rb')].each { |file| require file }
      
      true
    rescue LoadError => e
      puts "❌ Browser testing dependencies not available: #{e.message}"
      puts "Run: bundle install"
      false
    end
  end
  
  def server_running?(host = 'localhost', port = 3000)
    begin
      require 'net/http'
      require 'timeout'
      
      Timeout.timeout(3) do
        response = Net::HTTP.get_response(URI("http://#{host}:#{port}/"))
        response.code != '500' # Allow any response except server error
      end
    rescue
      false
    end
  end

  desc "Test a specific page and report errors"
  task :test, [:path] => :environment do |t, args|
    exit 1 unless load_browser_testing_dependencies
    
    path = args[:path] || "/"
    
    puts "🔍 Testing page: #{path}"
    puts "=" * 50
    
    # Check if server is running
    unless server_running?
      puts "❌ Server not running. Start with: bin/dev or rails server"
      exit 1
    end
    
    runner = BrowserTesting::TestRunner.new
    result = runner.test_page(path)
    
    if result.success
      puts "✅ No errors found!"
      puts "Duration: #{result.duration.round(2)}s"
    else
      puts "❌ Test failed with #{result.error_count} error(s)"
      puts "\nErrors:"
      result.errors.each_with_index do |error, i|
        puts "\n#{i + 1}. #{error[:type].humanize}"
        puts "   Message: #{error[:message]}"
        puts "   URL: #{error[:url]}" if error[:url]
        puts "   Source: #{error[:source]}" if error[:source].present?
      end
      
      if result.screenshots.any?
        puts "\nScreenshots saved:"
        result.screenshots.each { |path| puts "  - #{path}" }
      end
    end
    
    puts "=" * 50
    exit(result.success ? 0 : 1)
  end

  desc "Test page with full diagnostics"
  task :diagnose, [:path] => :environment do |t, args|
    path = args[:path] || "/"
    
    puts "🔍 Starting diagnostic test for #{path}..."
    puts "=" * 50
    
    # Mark start time for log collection
    start_time = Time.current
    
    # Run the browser test
    runner = BrowserTesting::TestRunner.new
    result = runner.test_page_with_details(path)
    
    # Collect logs from all containers
    logs = BrowserTesting::LogAggregator.new.collect_logs_for_request(
      start_time.iso8601,
      Time.current.iso8601
    ) rescue {}
    
    # Generate diagnostic report
    generate_diagnostic_report(result, logs)
  end

  desc "Test and collect errors for Claude to fix"
  task :test_for_fix, [:path] => :environment do |t, args|
    path = args[:path] || "/"
    
    runner = BrowserTesting::TestRunner.new
    result = runner.test_page_with_details(path)
    
    # Output in a format Claude can easily parse
    puts "=== BROWSER TEST RESULT ==="
    puts "URL: #{path}"
    puts "Status: #{result.status}"
    puts "Duration: #{result.duration.round(2)}s"
    puts "Errors: #{result.error_count}"
    
    if result.errors.any?
      result.errors.each_with_index do |error, i|
        puts "\nError #{i + 1}:"
        puts "  Type: #{error[:type]}"
        puts "  Message: #{error[:message]}"
        puts "  URL: #{error[:url]}" if error[:url]
        
        if error[:source].is_a?(Hash)
          puts "  File: #{error[:source][:file]}" if error[:source][:file]
          puts "  Line: #{error[:source][:line]}" if error[:source][:line]
        end
        
        if error[:backtrace]
          puts "  Backtrace:"
          error[:backtrace].each { |line| puts "    #{line}" }
        end
      end
      
      if result.suggestions.any?
        puts "\nSuggested Fixes:"
        result.suggestions.each_with_index do |suggestion, i|
          puts "  #{i + 1}. #{suggestion}"
        end
      end
    end
    
    puts "\nScreenshot: #{result.screenshot_path}" if result.screenshot_path
    puts "=== END BROWSER TEST RESULT ==="
  end

  desc "Run a user journey test"
  task :journey, [:name] => :environment do |t, args|
    exit 1 unless load_browser_testing_dependencies
    
    journey_name = args[:name]
    
    unless journey_name
      puts "Available journeys:"
      Dir[Rails.root.join("test/browser/journeys/*.rb")].each do |file|
        puts "  - #{File.basename(file, '.rb')}"
      end
      exit 1
    end
    
    # Check if server is running
    unless server_running?
      puts "❌ Server not running. Start with: bin/dev or rails server"
      exit 1
    end
    
    journey_file = Rails.root.join("test/browser/journeys/#{journey_name}.rb")
    
    unless File.exist?(journey_file)
      puts "Journey not found: #{journey_name}"
      puts "Available journeys:"
      Dir[Rails.root.join("test/browser/journeys/*.rb")].each do |file|
        puts "  - #{File.basename(file, '.rb')}"
      end
      exit 1
    end
    
    begin
      # Load the journey file
      require journey_file
      
      # Get the journey class name (e.g., UserRegistrationJourney)
      class_name = "#{journey_name.camelize}Journey"
      journey_class = Object.const_get(class_name)
      
      # Create instance and run the journey
      journey_instance = journey_class.new
      method_name = "run_#{journey_name}_journey"
      
      if journey_instance.respond_to?(method_name)
        journey_instance.send(method_name)
      else
        puts "❌ Journey method '#{method_name}' not found in #{class_name}"
        exit 1
      end
      
    rescue NameError => e
      puts "❌ Journey class not found: #{class_name}"
      puts "Error: #{e.message}"
      exit 1
    rescue => e
      puts "❌ Error running journey: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end

  desc "Take a screenshot of a page"
  task :screenshot, [:path] => :environment do |t, args|
    path = args[:path] || "/"
    
    # Ensure dependencies are loaded
    unless load_browser_testing_dependencies
      puts "Failed to load browser testing dependencies"
      exit 1
    end
    
    puts "Taking screenshot of: #{path}"
    puts "Chrome binary: #{ENV['CHROME_BIN'] || ENV['CHROMIUM_BIN'] || '/usr/bin/chromium'}"
    
    runner = BrowserTesting::TestRunner.new
    screenshot_path = nil
    
    begin
      runner.with_session do |session|
        runner.visit(path)
        sleep 2 # Give page time to render
        screenshot_path = runner.take_screenshot("screenshot_#{path.gsub('/', '_')}")
      end
      
      puts "✅ Screenshot saved to: #{screenshot_path}"
      
      # Copy to presentation assets directory if it exists
      assets_dir = Rails.root.join('docs/strategy/allspark-product-deck/assets')
      if File.directory?(assets_dir) && screenshot_path
        filename = case path
        when '/' then 'homepage.png'
        when '/instances' then 'instance-dashboard.png'
        when '/app_projects/new' then 'project-builder.png'
        when '/assistants' then 'assistants-list.png'
        when '/knowledge_documents' then 'knowledge-base.png'
        when '/chat' then 'chat-interface.png'
        when '/mcp_configs' then 'mcp-configs.png'
        when '/claude_cli_sessions' then 'claude-code.png'
        when '/oauth_integrations' then 'integrations.png'
        else "screenshot_#{path.gsub('/', '_')}.png"
        end
        
        destination = File.join(assets_dir, filename)
        FileUtils.cp(screenshot_path, destination)
        puts "📋 Copied to presentation: #{destination}"
      end
    rescue => e
      puts "❌ Screenshot failed: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end

  private

  def generate_diagnostic_report(result, logs)
    puts "\n=== DIAGNOSTIC REPORT ==="
    puts "URL: #{result.url}"
    puts "Test Started: #{Time.current - result.duration}"
    puts "Test Duration: #{result.duration.round(2)}s"
    
    puts "\nBROWSER STATUS:"
    puts "- Page loaded: #{result.success ? '✅' : '❌'}"
    puts "- JavaScript errors: #{result.errors.count { |e| e[:type] == 'javascript_error' }}"
    puts "- Network errors: #{result.errors.count { |e| e[:type] == 'network_error' }}"
    puts "- Rails errors: #{result.errors.count { |e| e[:type] == 'rails_error' }}"
    
    if result.errors.any?
      puts "\nERRORS DETECTED:"
      result.errors.each_with_index do |error, i|
        puts "\n#{i + 1}. #{error[:type].humanize}"
        puts "   Message: #{error[:message]}"
        puts "   Details: #{error.except(:type, :message, :timestamp).to_json}"
      end
    end
    
    if logs[:rails].present?
      puts "\nRAILS LOGS (last 20 lines):"
      logs[:rails].last(20).each { |line| puts line }
    end
    
    if logs[:docker].present?
      logs[:docker].each do |service, service_logs|
        if service_logs.any?
          puts "\n#{service.upcase} LOGS:"
          service_logs.last(10).each { |line| puts line }
        end
      end
    end
    
    if result.suggestions.any?
      puts "\nSUGGESTED FIXES:"
      result.suggestions.each_with_index do |suggestion, i|
        puts "#{i + 1}. #{suggestion}"
      end
    end
    
    if result.screenshots.any?
      puts "\nSCREENSHOTS:"
      result.screenshots.each { |path| puts "- #{path}" }
    end
    
    puts "\n=== END DIAGNOSTIC REPORT ==="
  end
end