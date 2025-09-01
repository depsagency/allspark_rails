# frozen_string_literal: true

require "capybara"
require "capybara/cuprite"

module BrowserTesting
  class Configuration
    class << self
      def setup!
        configure_capybara
        configure_cuprite
        configure_selenium if defined?(Selenium)
      end

      def configure_capybara
        Capybara.register_driver :cuprite do |app|
          Capybara::Cuprite::Driver.new(
            app,
            window_size: [1200, 800],
            browser_options: browser_options,
            inspector: Rails.env.development?,
            js_errors: false,
            headless: true,
            timeout: 300,
            process_timeout: 300,
            url_whitelist: ["http://localhost:3000", "http://web:3000"]
          )
        end

        Capybara.register_driver :selenium_chrome_headless do |app|
          options = Selenium::WebDriver::Chrome::Options.new
          options.add_argument("--headless") if headless?
          options.add_argument("--no-sandbox")
          options.add_argument("--disable-dev-shm-usage")
          options.add_argument("--disable-gpu")
          options.add_argument("--window-size=1200,800")

          Capybara::Selenium::Driver.new(
            app,
            browser: :chrome,
            options: options
          )
        end

        # Set default driver based on environment
        Capybara.default_driver = default_driver
        Capybara.javascript_driver = default_driver
        
        # Server settings for Docker
        Capybara.server_host = "0.0.0.0"
        Capybara.server_port = 3001 # Different from Rails to avoid conflicts
        
        # Asset settings
        Capybara.asset_host = "http://localhost:3000"
        
        # Timeouts
        Capybara.default_max_wait_time = 15
      end

      def configure_cuprite
        # Cuprite-specific global configuration
        # Logger setting removed as it's not supported in newer versions
      end

      def configure_selenium
        # Selenium-specific global configuration if needed
      end

      def browser_options
        options = ["--no-sandbox", "--disable-setuid-sandbox"]
        
        if running_in_docker?
          options += [
            "--disable-dev-shm-usage",
            "--disable-gpu",
            "--disable-software-rasterizer",
            "--disable-background-timer-throttling",
            "--disable-backgrounding-occluded-windows",
            "--disable-renderer-backgrounding",
            "--disable-features=TranslateUI",
            "--disable-extensions",
            "--remote-debugging-port=9222",
            "--remote-debugging-address=0.0.0.0"
          ]
        end
        
        options
      end

      def default_driver
        if ENV["BROWSER_DRIVER"].present?
          ENV["BROWSER_DRIVER"].to_sym
        elsif running_in_docker?
          :cuprite
        else
          :selenium_chrome_headless
        end
      end

      def headless?
        return true if ENV["HEADLESS"] == "false"
        running_in_docker? || Rails.env.test?
      end

      def running_in_docker?
        File.exist?("/.dockerenv") || ENV["DOCKER_CONTAINER"] == "true"
      end

      def chrome_path
        if running_in_docker?
          # Common paths in Docker containers
          %w[
            /usr/bin/chromium-browser
            /usr/bin/chromium
            /usr/bin/google-chrome
            /usr/bin/google-chrome-stable
          ].find { |path| File.exist?(path) }
        else
          # Let Cuprite find Chrome automatically
          nil
        end
      end
    end
  end
end

# Initialize configuration when this file is loaded
# Commented out to avoid conflicts with rake task configurations
# BrowserTesting::Configuration.setup! if defined?(Rails)