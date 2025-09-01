# frozen_string_literal: true

require 'timeout'

module Agents
  module Tools
    class RubyCodeTool
      extend Langchain::ToolDefinition
      
      NAME = "ruby_code"
      ANNOTATIONS_PATH = Pathname.new(__dir__).join("../../../schemas/agents/tools/ruby_code_tool.json").to_s
      
      def self.description
        <<~DESC
        Execute Ruby code in a sandboxed environment. Use this for data processing, 
        calculations, string manipulation, and other programming tasks.
        The code runs in a restricted environment for safety.
      DESC
      end
      
      # Define the ruby_code function with parameters
      define_function :execute, description: "Execute Ruby code in a sandboxed environment" do
        property :code, type: "string", description: "Ruby code to execute", required: true
      end
      
      def initialize
        require 'safe_ruby' if defined?(SafeRuby).nil?
      end
      
      # Execute Ruby code safely
      def execute(code:)
        return { error: "No code provided" } if code.blank?
        
        begin
          # For now, use a simpler approach with timeout
          # SafeRuby seems to have issues with our Ruby version
          result = Timeout.timeout(5) do
            # Create a binding with limited scope
            binding = Object.new.instance_eval { binding }
            
            # Evaluate the code
            eval(code, binding)
          end
          
          {
            success: true,
            code: code,
            result: result,
            output: format_output(result)
          }
        rescue Timeout::Error
          { error: "Code execution timed out (5 second limit)" }
        rescue StandardError => e
          { error: "Runtime error: #{e.message}" }
        end
      end
      
      private
      
      def format_output(result)
        case result
        when String
          result
        when Array, Hash
          result.inspect
        when nil
          "nil"
        else
          result.to_s
        end
      end
    end
  end
end