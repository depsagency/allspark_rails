# frozen_string_literal: true

module Agents
  module Tools
    class CalculatorTool
      extend Langchain::ToolDefinition
      
      NAME = "calculator"
      ANNOTATIONS_PATH = Pathname.new(__dir__).join("../../../schemas/agents/tools/calculator_tool.json").to_s
      
      def self.description
        <<~DESC
        Perform mathematical calculations. Supports basic arithmetic, trigonometry, logarithms, and more.
        Use this tool when you need to perform any mathematical computation.
      DESC
      end
      
      # Define the calculator function with parameters
      define_function :execute, description: "Perform mathematical calculations" do
        property :expression, type: "string", description: "Mathematical expression to evaluate", required: true
      end
      
      def initialize
        require 'eqn' if defined?(Eqn).nil?
      end
      
      # Execute a mathematical expression
      def execute(expression:)
        return { error: "No expression provided" } if expression.blank?
        
        # Use the Eqn gem for safe mathematical evaluation
        result = Eqn::Calculator.calc(expression)
        
        {
          success: true,
          expression: expression,
          result: result,
          formatted_result: format_result(result)
        }
      rescue Eqn::ParseError => e
        { error: "Invalid expression: #{e.message}" }
      rescue ZeroDivisionError
        { error: "Division by zero" }
      rescue => e
        { error: "Calculation error: #{e.message}" }
      end
      
      private
      
      def format_result(result)
        case result
        when Float
          # Format floats nicely, removing unnecessary decimals
          result.round(10).to_s.sub(/\.?0+$/, '')
        when BigDecimal
          result.to_s('F')
        else
          result.to_s
        end
      end
    end
  end
end