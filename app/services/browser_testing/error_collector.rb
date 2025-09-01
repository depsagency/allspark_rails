# frozen_string_literal: true

module BrowserTesting
  class ErrorCollector
    attr_reader :errors

    def initialize
      @errors = []
    end

    def collect_from_session(session)
      @errors = []
      
      collect_javascript_errors(session)
      collect_network_errors(session)
      collect_page_errors(session)
      
      @errors
    end

    def collect_javascript_errors(session)
      return unless session.driver.respond_to?(:browser) || session.driver.respond_to?(:console_messages)
      
      begin
        if session.driver.respond_to?(:browser) && session.driver.browser.respond_to?(:logs)
          # Selenium style
          logs = session.driver.browser.logs.get(:browser)
          parse_browser_logs(logs)
        elsif session.driver.respond_to?(:console_messages)
          # Cuprite style
          parse_console_messages(session.driver.console_messages)
        end
      rescue => e
        Rails.logger.warn "[ErrorCollector] Could not collect JS errors: #{e.message}"
      end
    end

    def collect_network_errors(session)
      return unless session.driver.respond_to?(:network_traffic)
      
      begin
        session.driver.network_traffic.each do |request|
          if request.response && request.response.status >= 400
            add_error(
              type: "network_error",
              message: "#{request.method} #{request.url} returned #{request.response.status}",
              details: {
                method: request.method,
                url: request.url,
                status: request.response.status,
                headers: request.response.headers
              }
            )
          end
        end
      rescue => e
        Rails.logger.warn "[ErrorCollector] Could not collect network errors: #{e.message}"
      end
    end

    def collect_page_errors(session)
      # Check for Rails error pages
      if has_rails_error?(session)
        error_info = extract_rails_error(session)
        add_error(
          type: "rails_error",
          message: error_info[:title],
          details: error_info
        )
      end
      
      # Check for custom error indicators
      check_custom_error_indicators(session)
    end

    private

    def parse_browser_logs(logs)
      logs.each do |log|
        if log.level == "SEVERE"
          error_info = parse_chrome_error(log.message)
          add_error(
            type: "javascript_error",
            message: error_info[:message],
            details: {
              level: log.level,
              timestamp: log.timestamp,
              source: error_info[:source],
              stack: error_info[:stack]
            }
          )
        end
      end
    end

    def parse_console_messages(messages)
      messages.each do |msg|
        if msg[:type] == "error"
          add_error(
            type: "javascript_error",
            message: msg[:message],
            details: {
              line: msg[:line_number],
              column: msg[:column_number],
              source: msg[:source],
              stack: msg[:stack_trace]
            }
          )
        end
      end
    end

    def parse_chrome_error(message)
      # Parse Chrome console error format
      # Example: "http://localhost:3000/assets/application.js 15:25 Uncaught TypeError: Cannot read property 'addEventListener' of null"
      
      source = {}
      stack = []
      clean_message = message
      
      # Extract source location
      if message =~ /^(.+?)\s+(\d+):(\d+)\s+(.+)$/
        source = { file: $1, line: $2.to_i, column: $3.to_i }
        clean_message = $4
      end
      
      # Extract stack trace if present
      if message.include?("\n")
        lines = message.split("\n")
        clean_message = lines.first
        stack = lines[1..-1].map(&:strip)
      end
      
      {
        message: clean_message,
        source: source,
        stack: stack
      }
    end

    def has_rails_error?(session)
      # Common Rails error page indicators
      session.has_css?("h1", text: /Error|Exception/, wait: 0.5) ||
        session.has_css?(".exception", wait: 0.5) ||
        session.has_text?(/The page you were looking for doesn't exist/i, wait: 0.5) ||
        session.has_text?(/We're sorry, but something went wrong/i, wait: 0.5)
    end

    def extract_rails_error(session)
      info = {
        title: "Rails Error",
        message: nil,
        backtrace: []
      }
      
      # Get error title
      if session.has_css?("h1", wait: 0.5)
        info[:title] = session.find("h1").text
      end
      
      # Get error message
      if session.has_css?(".message", wait: 0.5)
        info[:message] = session.find(".message").text
      elsif session.has_css?("#container h2", wait: 0.5)
        info[:message] = session.find("#container h2").text
      end
      
      # Get backtrace if available
      if session.has_css?(".source", wait: 0.5)
        info[:backtrace] = session.all(".source").map(&:text)
      elsif session.has_css?("pre", wait: 0.5)
        info[:backtrace] = session.find("pre").text.split("\n")
      end
      
      # Get request details if available
      if session.has_css?(".request-info", wait: 0.5)
        info[:request_info] = session.find(".request-info").text
      end
      
      info
    end

    def check_custom_error_indicators(session)
      # Check for common error patterns in the page
      
      # Flash messages
      if session.has_css?(".alert-danger", wait: 0.5)
        session.all(".alert-danger").each do |alert|
          add_error(
            type: "application_error",
            message: "Alert: #{alert.text}",
            details: { element: ".alert-danger" }
          )
        end
      end
      
      # Form validation errors
      if session.has_css?(".field_with_errors", wait: 0.5)
        error_count = session.all(".field_with_errors").size
        add_error(
          type: "validation_error",
          message: "Form has #{error_count} validation errors",
          details: { 
            fields: session.all(".field_with_errors label").map(&:text)
          }
        )
      end
      
      # Empty required content
      if session.has_css?("[data-required]:empty", wait: 0.5)
        add_error(
          type: "content_error",
          message: "Required content is missing",
          details: { 
            elements: session.all("[data-required]:empty").map { |e| e[:id] || e[:class] }
          }
        )
      end
    end

    def add_error(type:, message:, details: {})
      @errors << {
        type: type,
        message: message,
        timestamp: Time.current,
        **details
      }
    end
  end
end