# frozen_string_literal: true

# Browser configuration for testing in Docker container
if Rails.env.test? || Rails.env.development?
  # Set Chrome binary path for Docker container
  if ENV['DOCKER_CONTAINER'] == 'true'
    ENV['CHROME_BIN'] ||= '/usr/bin/chromium'
    ENV['CHROMIUM_BIN'] ||= '/usr/bin/chromium'
  end
  
  # Configure Capybara with Cuprite for browser testing (only if gems are available)
  begin
    require 'capybara/cuprite'
  rescue LoadError
    # Capybara/Cuprite not available (likely in production mode or gems not installed)
    Rails.logger&.info "Capybara/Cuprite not available, skipping browser configuration"
  else
  
  Capybara.register_driver :cuprite do |app|
    Capybara::Cuprite::Driver.new(
      app,
      window_size: [1440, 900],
      browser_options: {
        'no-sandbox': true,
        'disable-dev-shm-usage': true,
        'disable-gpu': true,
        'disable-setuid-sandbox': true,
        'disable-web-security': true
      },
      process_timeout: 30,
      timeout: 30,
      js_errors: false,
      headless: true,
      slowmo: ENV['CUPRITE_SLOWMO']&.to_f || 0
    )
  end
  
  # Configure Capybara defaults
  Capybara.default_driver = :cuprite
  Capybara.javascript_driver = :cuprite
  Capybara.default_max_wait_time = 10
  Capybara.server = :puma, { Silent: true }
  
  # For system tests with Selenium
  if defined?(Selenium)
    Selenium::WebDriver::Chrome::Service.driver_path = '/usr/bin/chromedriver' if ENV['DOCKER_CONTAINER'] == 'true'
  end
  end # End of else block for Capybara require
end