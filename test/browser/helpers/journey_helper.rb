# frozen_string_literal: true

require_relative '../../../config/environment'
require_relative '../../../app/services/browser_testing/configuration'

# Helper methods for browser journeys
module JourneyHelper
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def journey(name, &block)
      define_method("run_#{name}_journey") do
        puts "🚀 Starting journey: #{name}"
        puts "=" * 50
        
        start_time = Time.current
        success = false
        errors = []
        
        begin
          instance_eval(&block)
          success = true
          puts "✅ Journey completed successfully!"
        rescue => e
          errors << e
          puts "❌ Journey failed: #{e.message}"
          puts e.backtrace.first(5).join("\n")
        ensure
          duration = Time.current - start_time
          puts "Duration: #{duration.round(2)}s"
          puts "=" * 50
          
          # Exit with appropriate code
          exit(success ? 0 : 1)
        end
      end

      # Auto-run if this is the main file
      if $0 == __FILE__
        new.send("run_#{name}_journey")
      end
    end
  end

  def setup_session
    # Configure Capybara if not already done
    unless Capybara.drivers.key?(:cuprite)
      Capybara.register_driver :cuprite do |app|
        Capybara::Cuprite::Driver.new(
          app, 
          headless: !ENV['BROWSER_VISIBLE'],
          js_errors: false,
          timeout: 30,
          process_timeout: 30,
          browser_options: {
            'no-sandbox' => nil,
            'disable-dev-shm-usage' => nil,
            'disable-gpu' => nil,
            'remote-debugging-port' => 9222,
            'remote-debugging-address' => '0.0.0.0'
          }
        )
      end
    end
    
    @session = Capybara::Session.new(:cuprite)
    @base_url = ENV.fetch("CAPYBARA_SERVER_HOST", "http://localhost:3000")
  end

  def teardown_session
    @session&.quit
  end

  def visit(path)
    url = path.start_with?("http") ? path : "#{@base_url}#{path}"
    @session.visit(url)
  end

  def screenshot(name = nil)
    name ||= "journey_#{Time.current.to_i}"
    path = Rails.root.join("tmp", "screenshots", "#{name}.png")
    FileUtils.mkdir_p(File.dirname(path))
    @session.save_screenshot(path)
    puts "📸 Screenshot saved: #{path}"
    path
  end

  def expect_success(message = "Step successful")
    puts "✓ #{message}"
  end

  def expect_page_to_have(content, options = {})
    if @session.has_text?(content, **options)
      expect_success("Page contains: #{content}")
    else
      raise "Expected page to have content: #{content}"
    end
  end

  def expect_no_errors
    # Check for JavaScript errors
    if @session.driver.respond_to?(:console_messages)
      errors = @session.driver.console_messages.select { |m| m[:type] == "error" }
      if errors.any?
        raise "JavaScript errors detected:\n#{errors.map { |e| e[:message] }.join("\n")}"
      end
    end

    # Check for Rails error pages
    if @session.has_css?("h1", text: /Error|Exception/, wait: 0.5)
      error_text = @session.find("h1").text
      raise "Rails error detected: #{error_text}"
    end

    expect_success("No errors detected")
  end

  def debug_page_content(label = "DEBUG")
    puts "#{label}: Current URL: #{@session.current_url}"
    puts "#{label}: Page title: #{@session.title}" if @session.respond_to?(:title)
    puts "#{label}: Available links:"
    @session.all('a').each_with_index do |link, i|
      puts "  #{i+1}. '#{link.text.strip}' -> #{link[:href]}" if link.text.strip.present?
    end
    puts "#{label}: Available buttons:"
    @session.all('button, input[type=submit]').each_with_index do |button, i|
      puts "  #{i+1}. '#{button.text.strip}' (#{button.tag_name})" if button.text.strip.present?
    end
  end

  def fill_in(locator, with:)
    @session.fill_in(locator, with: with)
    expect_success("Filled in '#{locator}' with '#{with}'")
  end

  def click_button(locator)
    @session.click_button(locator)
    expect_success("Clicked button: #{locator}")
  end

  def click_link(locator)
    @session.click_link(locator)
    expect_success("Clicked link: #{locator}")
  end

  def select(value, from:)
    @session.select(value, from: from)
    expect_success("Selected '#{value}' from '#{from}'")
  end

  def wait_for_turbo
    if @session.has_css?('[data-turbo-temporary]', wait: 0.5)
      @session.has_no_css?('[data-turbo-temporary]')
    end
    sleep 0.5 # Give JavaScript time to settle
  end

  def login_as(email, password)
    visit "/users/sign_in"
    fill_in "user[email]", with: email
    fill_in "user[password]", with: password
    click_button "Sign in"
    wait_for_turbo
    
    # Check if login was successful by verifying we're not on the sign-in page
    if @session.current_path == "/users/sign_in"
      debug_page_content("Login failed")
      raise "Login failed - still on sign in page"
    else
      expect_success("Login successful")
      
      # Additional check - verify we can access authenticated content
      if @session.has_content?("Access denied") || @session.has_content?("You need to sign in")
        debug_page_content("Authentication issue after login")
        raise "Login succeeded but authentication not working properly"
      end
    end
  end

  def logout
    visit "/"
    if @session.has_link?("Logout")
      click_link "Logout"
      expect_page_to_have("Signed out successfully")
    end
  end

  # Data helpers
  def test_email
    "test_#{Time.current.to_i}@example.com"
  end

  def test_user_data
    {
      email: test_email,
      password: "password123",
      password_confirmation: "password123"
    }
  end
end