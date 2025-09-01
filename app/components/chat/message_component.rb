# frozen_string_literal: true

module Chat
  class MessageComponent < ::BaseComponent
    def initialize(message:, current_user:)
      @message = message
      @current_user = current_user
    end
    
    private
    
    def is_own_message?
      @message.user_id == @current_user.id
    end
    
    def formatted_time
      @message.created_at.strftime("%l:%M %p").strip
    end
    
    def edited_indicator
      return unless @message.edited?
      
      content_tag(:span, "(edited)", class: "text-xs opacity-70 ml-1")
    end
    
    def formatted_content
      content = @message.content
      
      # Check if the content contains tool calls (for compatibility with AssistantMessage)
      if @message.respond_to?(:tool_calls) && @message.tool_calls.present?
        # Format tool calls as markdown and append to content
        tool_calls_markdown = format_tool_calls_for_display(@message.tool_calls)
        content = [content, tool_calls_markdown].compact.join("\n\n")
      end
      
      # Check if content is a JSON string that might contain tool calls
      if content.is_a?(String) && content.strip.start_with?('{', '[')
        begin
          parsed = JSON.parse(content)
          if parsed.is_a?(Hash) && (parsed['tool_calls'] || parsed['tool_results'])
            return format_tool_data_from_json(parsed)
          end
        rescue JSON::ParserError
          # Not JSON, continue with normal processing
        end
      end
      
      content
    end
    
    def format_tool_calls_for_display(tool_calls)
      return "" if tool_calls.blank?
      
      tool_calls.map do |tool_call|
        format_single_tool_call(tool_call)
      end.join("\n\n")
    end
    
    def format_single_tool_call(tool_call)
      tool_name = tool_call['name'] || tool_call[:name] || 'Unknown'
      tool_input = tool_call['input'] || tool_call[:input] || {}
      
      markdown = "## 🛠️ Tool Usage: #{tool_name}\n\n"
      
      if tool_input.present?
        markdown += "**Parameters:**\n\n"
        tool_input.each do |key, value|
          markdown += "- **#{key}**: "
          begin
            if value.is_a?(String) && (value.include?("\n") || value.length > 100)
              markdown += "\n```\n#{value}\n```\n"
            elsif value.is_a?(Hash) || value.is_a?(Array)
              markdown += "\n```json\n#{JSON.pretty_generate(value)}\n```\n"
            else
              # Simple values inline - escape any special characters
              markdown += "`#{value.to_s.gsub('`', '\\`')}`\n"
            end
          rescue => e
            # Fallback for any serialization errors
            markdown += "`#{value.inspect}`\n"
          end
        end
      else
        markdown += "*No parameters*\n"
      end
      
      markdown
    end
    
    def format_tool_data_from_json(data)
      result = ""
      
      if data['tool_calls']
        data['tool_calls'].each do |tool_call|
          result += format_single_tool_call(tool_call) + "\n\n"
        end
      end
      
      if data['tool_results']
        data['tool_results'].each do |tool_result|
          result += format_single_tool_result(tool_result) + "\n\n"
        end
      end
      
      result.strip
    end
    
    def format_single_tool_result(tool_result)
      if tool_result['is_error']
        content = tool_result['content'] || 'Unknown error'
        "## ❌ Tool Error\n\n```\n#{content}\n```"
      else
        content = tool_result['content'] || 'No result'
        
        if content.is_a?(String)
          if content.strip.start_with?('{', '[') && content.strip.end_with?('}', ']')
            begin
              parsed = JSON.parse(content)
              formatted_json = JSON.pretty_generate(parsed)
              "## ✅ Tool Result\n\n```json\n#{formatted_json}\n```"
            rescue JSON::ParserError
              "## ✅ Tool Result\n\n```\n#{content}\n```"
            end
          elsif content.include?("\n") || content.length > 100
            "## ✅ Tool Result\n\n```\n#{content}\n```"
          else
            "## ✅ Tool Result\n\n`#{content}`"
          end
        else
          "## ✅ Tool Result\n\n```json\n#{JSON.pretty_generate(content)}\n```"
        end
      end
    end
  end
end