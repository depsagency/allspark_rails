# frozen_string_literal: true

module BrowserTesting
  class LogParser
    class << self
      def parse_rails_logs(logs)
        errors = []
        warnings = []
        requests = []
        current_request = nil

        logs.each do |line|
          # Parse log level
          level = extract_log_level(line)
          
          # Track requests
          if request_start?(line)
            current_request = parse_request_start(line)
            requests << current_request
          elsif current_request && request_end?(line)
            current_request[:completed] = parse_request_end(line)
            current_request = nil
          end

          # Collect errors and warnings
          case level
          when "ERROR", "FATAL"
            error_info = parse_error_line(line)
            errors << error_info if error_info
          when "WARN"
            warnings << parse_warning_line(line)
          end

          # Check for specific error patterns
          if exception = extract_exception(line)
            errors << exception
          end
        end

        {
          errors: errors,
          warnings: warnings,
          requests: requests,
          summary: {
            error_count: errors.size,
            warning_count: warnings.size,
            request_count: requests.size,
            failed_requests: requests.count { |r| r[:completed]&.dig(:status)&.to_i >= 500 }
          }
        }
      end

      def parse_docker_logs(logs)
        results = {}

        logs.each do |service, service_logs|
          results[service] = {
            errors: [],
            warnings: [],
            info: []
          }

          service_logs.each do |line|
            if error_line?(line)
              results[service][:errors] << parse_docker_error(line)
            elsif warning_line?(line)
              results[service][:warnings] << line
            elsif important_info?(line)
              results[service][:info] << line
            end
          end
        end

        results
      end

      private

      def extract_log_level(line)
        # Rails format: "I, [timestamp]" or "E, [timestamp]"
        if match = line.match(/^([IWEF]),\s*\[/)
          case match[1]
          when "I" then "INFO"
          when "W" then "WARN"
          when "E" then "ERROR"
          when "F" then "FATAL"
          else "DEBUG"
          end
        else
          "INFO"
        end
      end

      def request_start?(line)
        line.include?("Started ") && line.match(/Started (GET|POST|PUT|PATCH|DELETE)/)
      end

      def request_end?(line)
        line.include?("Completed ")
      end

      def parse_request_start(line)
        if match = line.match(/Started (\w+) "([^"]+)" for ([\d\.]+)/)
          {
            method: match[1],
            path: match[2],
            ip: match[3],
            timestamp: extract_timestamp(line)
          }
        else
          {}
        end
      end

      def parse_request_end(line)
        if match = line.match(/Completed (\d+) \w+ in (\d+(?:\.\d+)?)ms/)
          {
            status: match[1].to_i,
            duration: match[2].to_f,
            timestamp: extract_timestamp(line)
          }
        else
          {}
        end
      end

      def parse_error_line(line)
        {
          level: "ERROR",
          message: clean_log_line(line),
          timestamp: extract_timestamp(line),
          raw: line
        }
      end

      def parse_warning_line(line)
        {
          level: "WARN",
          message: clean_log_line(line),
          timestamp: extract_timestamp(line)
        }
      end

      def extract_exception(line)
        # Look for Ruby exception patterns
        if match = line.match(/(\w+(?:::\w+)*Error|Exception):\s*(.+)/)
          {
            type: "exception",
            exception_class: match[1],
            message: match[2],
            timestamp: extract_timestamp(line)
          }
        elsif line.include?("from ") && line.match(/from (.+):(\d+):in/)
          # Backtrace line
          {
            type: "backtrace",
            file: match[1],
            line: match[2].to_i
          }
        else
          nil
        end
      end

      def clean_log_line(line)
        # Remove timestamp and log level prefix
        line
          .sub(/^[IWEF],\s*\[[^\]]+\]\s*/, '')
          .sub(/^.*?--\s*:\s*/, '')
          .strip
      end

      def extract_timestamp(line)
        if match = line.match(/\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+)/)
          match[1]
        else
          nil
        end
      end

      def error_line?(line)
        line.match?(/error|exception|fatal|critical|failed/i)
      end

      def warning_line?(line)
        line.match?(/warn|warning|deprecated/i)
      end

      def important_info?(line)
        # Identify important non-error lines
        line.match?(/started|listening|connected|initialized|ready/i)
      end

      def parse_docker_error(line)
        # Clean up Docker timestamps and prefixes
        clean_line = line.sub(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z\s*/, '')
        
        {
          message: clean_line,
          timestamp: line.match(/^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z)/)&.captures&.first,
          raw: line
        }
      end
    end
  end
end