# frozen_string_literal: true

module BrowserTesting
  class JavascriptErrorParser
    class << self
      def parse(error_message)
        result = {
          type: detect_error_type(error_message),
          message: clean_message(error_message),
          details: {}
        }

        # Extract file location
        if location = extract_location(error_message)
          result[:details][:location] = location
        end

        # Extract stack trace
        if stack = extract_stack_trace(error_message)
          result[:details][:stack] = stack
        end

        # Extract variable/property names
        if var_info = extract_variable_info(error_message)
          result[:details][:variable_info] = var_info
        end

        # Add common fix suggestions
        result[:suggestions] = suggest_fixes(result)

        result
      end

      private

      def detect_error_type(message)
        case message
        when /TypeError/i
          :type_error
        when /ReferenceError/i
          :reference_error
        when /SyntaxError/i
          :syntax_error
        when /RangeError/i
          :range_error
        when /Cannot read prop/i
          :property_access_error
        when /is not defined/i
          :undefined_error
        when /is not a function/i
          :not_a_function_error
        when /Failed to fetch/i
          :network_error
        else
          :unknown_error
        end
      end

      def clean_message(message)
        # Remove file paths and line numbers from the main message
        message
          .sub(/^.+?:\d+:\d+\s+/, '')
          .sub(/^\s*Uncaught\s+/, '')
          .strip
      end

      def extract_location(message)
        patterns = [
          # Chrome format: http://localhost:3000/assets/application.js:15:25
          /(?<file>https?:\/\/[^:]+\.js):(?<line>\d+):(?<column>\d+)/,
          # File path format: /app/assets/application.js:15:25
          /(?<file>\/[^:]+\.js):(?<line>\d+):(?<column>\d+)/,
          # At format: at functionName (file:line:column)
          /at\s+(?<function>\w+)?\s*\((?<file>[^:)]+):(?<line>\d+):(?<column>\d+)\)/
        ]

        patterns.each do |pattern|
          if match = message.match(pattern)
            return {
              file: match[:file],
              line: match[:line]&.to_i,
              column: match[:column]&.to_i,
              function: match[:function]
            }.compact
          end
        end

        nil
      end

      def extract_stack_trace(message)
        return nil unless message.include?("\n")

        lines = message.split("\n")
        stack_lines = lines[1..-1].select { |line| line.include?(" at ") }

        stack_lines.map do |line|
          if match = line.match(/at\s+(?<function>[^\s(]+)?\s*\((?<location>[^)]+)\)/)
            {
              function: match[:function] || "anonymous",
              location: match[:location]
            }
          else
            line.strip
          end
        end
      end

      def extract_variable_info(message)
        info = {}

        # Extract property name from "Cannot read property 'X' of null/undefined"
        if match = message.match(/Cannot read (?:property|properties) ['"](\w+)['"] of (\w+)/)
          info[:property] = match[1]
          info[:object_type] = match[2]
        end

        # Extract variable name from "X is not defined"
        if match = message.match(/(\w+) is not defined/)
          info[:undefined_variable] = match[1]
        end

        # Extract function name from "X is not a function"
        if match = message.match(/(\w+) is not a function/)
          info[:not_a_function] = match[1]
        end

        info.any? ? info : nil
      end

      def suggest_fixes(parsed_error)
        suggestions = []

        case parsed_error[:type]
        when :property_access_error
          if parsed_error[:details][:variable_info]
            obj = parsed_error[:details][:variable_info][:object_type]
            prop = parsed_error[:details][:variable_info][:property]
            
            suggestions << "Check if the object exists before accessing '#{prop}'"
            suggestions << "Use optional chaining: object?.#{prop}"
            suggestions << "Add a null check: if (object) { object.#{prop} }"
          end

        when :undefined_error
          if var_name = parsed_error[:details][:variable_info]&.dig(:undefined_variable)
            suggestions << "Ensure '#{var_name}' is defined before use"
            suggestions << "Check if '#{var_name}' is imported/required"
            suggestions << "Verify the script load order"
          end

        when :not_a_function_error
          if func_name = parsed_error[:details][:variable_info]&.dig(:not_a_function)
            suggestions << "Verify '#{func_name}' is actually a function"
            suggestions << "Check if '#{func_name}' is defined at call time"
            suggestions << "Ensure the correct object method is being called"
          end

        when :syntax_error
          suggestions << "Check for missing semicolons, brackets, or quotes"
          suggestions << "Validate JavaScript syntax"

        when :network_error
          suggestions << "Check if the endpoint exists"
          suggestions << "Verify CORS settings"
          suggestions << "Check network connectivity"
        end

        # General suggestions based on location
        if location = parsed_error[:details][:location]
          if location[:file]&.include?("turbo")
            suggestions << "Ensure Turbo is properly initialized"
            suggestions << "Check for Turbo event listeners"
          elsif location[:file]&.include?("stimulus")
            suggestions << "Verify Stimulus controller is connected"
            suggestions << "Check data-controller attributes"
          end
        end

        suggestions
      end
    end
  end
end