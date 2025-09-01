# Example: Using Linear MCP Tools in AI Assistants
#
# This example shows how Linear tools become available to AI assistants
# once the Linear MCP server is configured with SSE transport.

class LinearToolUsageExample
  def demonstrate_linear_integration
    # 1. First, ensure Linear MCP server is configured
    linear_server = McpServer.find_by(name: "Linear")
    return puts "Linear MCP server not configured!" unless linear_server
    
    # 2. Tools are automatically discovered and made available
    # The MCP framework handles tool discovery via SSE
    available_tools = linear_server.available_tools
    
    puts "Available Linear tools:"
    available_tools.each do |tool|
      puts "- #{tool['name']}: #{tool['description']}"
    end
    
    # 3. AI assistants can use these tools automatically
    # When building an assistant, Linear tools are included:
    assistant = Assistant.find_by(name: "Project Manager")
    
    if assistant
      # The assistant's tools will include Linear tools
      linear_tools = assistant.tools.select { |t| t.name.start_with?("mcp_") }
      
      puts "\nAssistant has access to #{linear_tools.count} Linear tools"
    end
    
    # 4. Example tool execution (what happens behind the scenes)
    # When an AI assistant wants to create a Linear issue:
    
    # The AI generates a tool call like:
    tool_call = {
      name: "mcp_create_issue",
      arguments: {
        title: "Bug: Login page returns 404",
        description: "Users are unable to access the login page. Server returns 404.",
        teamId: "TEAM-123",
        priority: 2,
        labels: ["bug", "urgent"]
      }
    }
    
    # The MCP framework handles the execution via SSE:
    # 1. Sends request to Linear's SSE endpoint
    # 2. Streams the response back
    # 3. Returns the created issue details
    
    # Example response:
    response = {
      id: "LIN-456",
      url: "https://linear.app/team/issue/LIN-456",
      title: "Bug: Login page returns 404",
      state: "todo",
      createdAt: "2024-01-13T10:30:00Z"
    }
    
    puts "\nCreated Linear issue: #{response[:id]}"
    puts "View at: #{response[:url]}"
  end
  
  def example_workflow_integration
    # Example: Automatic issue creation from error monitoring
    
    workflow = Workflow.new(
      name: "Error to Linear Issue",
      description: "Creates Linear issues for critical errors"
    )
    
    # Task 1: Monitor for errors
    monitor_task = workflow.tasks.build(
      name: "Monitor Errors",
      task_type: "monitor_errors",
      config: { severity: "critical" }
    )
    
    # Task 2: Create Linear issue
    create_issue_task = workflow.tasks.build(
      name: "Create Linear Issue",
      task_type: "mcp_tool",
      config: {
        tool_name: "create_issue",
        tool_params: {
          title: "{{error.message}}",
          description: "Error occurred at {{error.timestamp}}\n\n{{error.stack_trace}}",
          labels: ["auto-created", "error"],
          priority: 1
        }
      }
    )
    
    # Task 3: Notify team
    notify_task = workflow.tasks.build(
      name: "Notify Team",
      task_type: "send_notification",
      config: {
        channel: "engineering",
        message: "Linear issue {{linear.issue_id}} created for error"
      }
    )
    
    puts "\nExample workflow created with Linear integration!"
  end
  
  def example_chat_integration
    # Example: User can interact with Linear via chat
    
    # User message: "Create a feature request for dark mode"
    
    # AI Assistant response process:
    # 1. Understands intent to create Linear issue
    # 2. Calls mcp_create_issue tool
    # 3. Returns formatted response
    
    ai_response = <<~RESPONSE
      I've created a Linear issue for the dark mode feature request:
      
      **Issue:** LIN-789 - Feature Request: Add dark mode support
      **Status:** Backlog
      **Team:** Product
      **Priority:** Medium
      
      You can view and track this issue at: https://linear.app/team/issue/LIN-789
      
      I've also added it to the Q1 feature planning project.
    RESPONSE
    
    puts "\nExample AI response:"
    puts ai_response
  end
end

# Usage:
# rails console
# example = LinearToolUsageExample.new
# example.demonstrate_linear_integration
# example.example_workflow_integration
# example.example_chat_integration