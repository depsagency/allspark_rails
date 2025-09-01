# frozen_string_literal: true

begin
  require 'capybara'
  require 'capybara/cuprite'
rescue LoadError
  # Dependencies will be loaded by rake task
end

module BrowserTesting
  class Base
    attr_reader :session, :errors, :screenshots

    def initialize(driver: :cuprite)
      @driver = driver
      @errors = []
      @screenshots = []
      @session = nil
    end

    def start_session
      @session = Capybara::Session.new(@driver)
      configure_session
      @session
    end

    def end_session
      @session&.quit
      @session = nil
    end

    def with_session
      start_session
      yield @session
    ensure
      end_session
    end

    def visit(path)
      full_url = build_url(path)
      @session.visit(full_url)
    end

    def take_screenshot(name = nil)
      name ||= "screenshot_#{Time.current.to_i}"
      path = Rails.root.join("tmp", "screenshots", "#{name}.png")
      FileUtils.mkdir_p(File.dirname(path))
      
      @session.save_screenshot(path)
      @screenshots << path
      path
    end

    def has_errors?
      @errors.any?
    end

    def clear_errors
      @errors = []
      @screenshots = []
    end

    protected

    def configure_session
      # Configure driver-specific settings
      case @driver
      when :cuprite
        configure_cuprite
      when :selenium_chrome_headless
        configure_selenium
      end
    end

    def configure_cuprite
      # Cuprite-specific configuration
      # Driver options are set during registration, not per-session
    end

    def configure_selenium
      # Selenium-specific configuration if needed
    end

    def build_url(path)
      return path if path.start_with?("http")
      
      # For browser testing, we connect to localhost even in Docker
      # because Chrome runs in the same container as the Rails app
      host = ENV.fetch("CAPYBARA_SERVER_HOST", "localhost")
      port = ENV.fetch("CAPYBARA_SERVER_PORT", "3000")
      
      "http://#{host}:#{port}#{path}"
    end

    def log_error(type, message, details = {})
      error = {
        type: type,
        message: message,
        timestamp: Time.current,
        url: @session&.current_url,
        **details
      }
      @errors << error
      Rails.logger.error("[BrowserTesting] #{type}: #{message}")
    end
  end
end