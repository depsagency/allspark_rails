# frozen_string_literal: true

module BrowserTesting
  class TestRunner < Base
    attr_reader :start_time, :end_time, :duration
    
    def test_page(path)
      @start_time = Time.current
      clear_errors
      
      result = with_session do |session|
        begin
          # Visit the page
          visit(path)
          
          # Wait for page to load
          wait_for_page_load
          
          # Collect errors
          collect_javascript_errors
          collect_network_errors
          check_for_rails_error
          
          # Take screenshot if errors found
          take_screenshot("error_#{path.gsub('/', '_')}") if has_errors?
          
          # Return success/failure
          !has_errors?
        rescue StandardError => e
          log_error("test_failure", e.message, { backtrace: e.backtrace.first(5) })
          take_screenshot("exception_#{path.gsub('/', '_')}")
          false
        end
      end
      
      @end_time = Time.current
      @duration = @end_time - @start_time
      
      TestResult.new(
        success: result,
        errors: @errors,
        screenshots: @screenshots,
        duration: @duration,
        url: path
      )
    end

    def test_page_with_details(path)
      result = test_page(path)
      
      # Enhance with additional details
      result.logs = collect_recent_logs if result.errors.any?
      result.page_content = capture_page_content if result.errors.any?
      result.suggestions = generate_fix_suggestions(result.errors)
      
      result
    end

    private

    def wait_for_page_load
      # Wait for basic page load
      @session.has_css?("body")
      
      # Wait for Turbo to finish if present
      if @session.has_css?('[data-turbo-temporary]', wait: 0.5)
        @session.has_no_css?('[data-turbo-temporary]')
      end
      
      # Give JavaScript time to initialize
      sleep 0.5
    end

    def collect_javascript_errors
      return unless @session.driver.respond_to?(:browser)
      
      # Try to get browser logs
      begin
        if @session.driver.browser.respond_to?(:logs)
          logs = @session.driver.browser.logs.get(:browser)
          
          logs.each do |log|
            if log.level == "SEVERE"
              log_error(
                "javascript_error",
                log.message,
                {
                  level: log.level,
                  timestamp: log.timestamp,
                  source: extract_source_from_message(log.message)
                }
              )
            end
          end
        elsif @session.driver.respond_to?(:console_messages)
          # Cuprite style
          @session.driver.console_messages.each do |msg|
            if msg[:type] == "error"
              log_error(
                "javascript_error",
                msg[:message],
                {
                  line: msg[:line_number],
                  source: msg[:source]
                }
              )
            end
          end
        end
      rescue => e
        Rails.logger.warn "[BrowserTesting] Could not collect JS errors: #{e.message}"
      end
    end

    def collect_network_errors
      return unless @session.driver.respond_to?(:network_traffic)
      
      begin
        @session.driver.network_traffic.each do |request|
          if request.response && request.response.status >= 400
            log_error(
              "network_error",
              "#{request.method} #{request.url} returned #{request.response.status}",
              {
                method: request.method,
                url: request.url,
                status: request.response.status
              }
            )
          end
        end
      rescue => e
        Rails.logger.warn "[BrowserTesting] Could not collect network errors: #{e.message}"
      end
    end

    def check_for_rails_error
      # Check for common Rails error pages
      if @session.has_css?("h1", text: /Error|Exception/, wait: 0.5)
        error_heading = @session.find("h1").text
        
        # Try to find error details
        error_message = if @session.has_css?(".message", wait: 0.5)
          @session.find(".message").text
        elsif @session.has_css?("pre", wait: 0.5)
          @session.find("pre").text
        else
          "Rails error detected"
        end
        
        log_error(
          "rails_error",
          error_heading,
          {
            message: error_message,
            page_title: @session.title
          }
        )
      end
      
      # Check for 404
      if @session.has_text?(/The page you were looking for doesn't exist/i, wait: 0.5)
        log_error("rails_error", "404 - Page not found")
      end
    end

    def collect_recent_logs
      # This will be implemented by LogAggregator
      {}
    end

    def capture_page_content
      {
        html: @session.html,
        current_url: @session.current_url,
        title: @session.title
      }
    end

    def generate_fix_suggestions(errors)
      suggestions = []
      
      errors.each do |error|
        case error[:type]
        when "javascript_error"
          if error[:message].include?("Cannot read property")
            suggestions << "Check if the element exists before accessing its properties"
          elsif error[:message].include?("is not defined")
            suggestions << "Ensure the variable or function is defined before use"
          end
        when "network_error"
          if error[:status] == 404
            suggestions << "Check if the route exists in config/routes.rb"
            suggestions << "Verify the URL path is correct"
          elsif error[:status] == 500
            suggestions << "Check Rails logs for the full error stack trace"
          end
        when "rails_error"
          suggestions << "Check Rails logs for detailed error information"
          suggestions << "Run the failing action in Rails console to debug"
        end
      end
      
      suggestions.uniq
    end

    def extract_source_from_message(message)
      # Extract file and line from Chrome console messages
      if message =~ /at (.+):(\d+):(\d+)/
        { file: $1, line: $2.to_i, column: $3.to_i }
      else
        {}
      end
    end
  end

  class TestResult
    attr_accessor :success, :errors, :screenshots, :duration, :url, :logs, 
                  :page_content, :suggestions

    def initialize(success:, errors: [], screenshots: [], duration: 0, url: nil)
      @success = success
      @errors = errors
      @screenshots = screenshots
      @duration = duration
      @url = url
      @logs = {}
      @page_content = {}
      @suggestions = []
    end

    def status
      success ? "passed" : "failed"
    end

    def error_count
      errors.size
    end

    def screenshot_path
      screenshots.first
    end

    def to_h
      {
        status: status,
        url: url,
        duration: duration,
        error_count: error_count,
        errors: errors,
        screenshots: screenshots,
        suggestions: suggestions
      }
    end
  end
end