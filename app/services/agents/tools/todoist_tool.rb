# frozen_string_literal: true

module Agents
  module Tools
    class TodoistTool
      extend Langchain::ToolDefinition
      
      NAME = "todoist"
      ANNOTATIONS_PATH = Pathname.new(__dir__).join("../../../schemas/agents/tools/todoist_tool.json").to_s
      
      def self.description
        <<~DESC
        Interact with Todoist to manage tasks and projects. You can list tasks, create new tasks,
        update existing tasks, and mark tasks as complete.
      DESC
      end
      
      # Define the todoist function with parameters
      define_function :execute, description: "Interact with Todoist to manage tasks" do
        property :action, type: "string", description: "Action to perform (list_tasks, create_task, etc.)", required: true
        property :content, type: "string", description: "Task content", required: false
        property :description, type: "string", description: "Task description", required: false
        property :project_id, type: "string", description: "Project ID", required: false
        property :task_id, type: "string", description: "Task ID", required: false
        property :filter, type: "string", description: "Filter for listing tasks", required: false
        property :due_date, type: "string", description: "Due date", required: false
        property :priority, type: "integer", description: "Priority level", required: false
        property :labels, type: "array", description: "Task labels", required: false do
          item type: "string", description: "Label name"
        end
      end
      
      def initialize(access_token: nil)
        @access_token = access_token || ENV['TODOIST_API_TOKEN']
        @client = Integrations::TodoistClient.new(@access_token) if @access_token
      end
      
      # Execute Todoist operations
      def execute(action:, **params)
        return { error: "Todoist not configured" } unless @client
        
        case action
        when 'list_tasks'
          list_tasks(params)
        when 'create_task'
          create_task(params)
        when 'update_task'
          update_task(params)
        when 'complete_task'
          complete_task(params)
        when 'list_projects'
          list_projects
        else
          { error: "Unknown action: #{action}" }
        end
      rescue => e
        { error: "Todoist error: #{e.message}" }
      end
      
      private
      
      def list_tasks(params)
        response = @client.tasks(
          filter: params[:filter],
          project_id: params[:project_id]
        )
        
        if response.success?
          tasks = JSON.parse(response.body)
          {
            success: true,
            tasks: tasks.map { |t| format_task(t) },
            count: tasks.size
          }
        else
          { error: "Failed to fetch tasks: #{response.code}" }
        end
      end
      
      def create_task(params)
        response = @client.create_task(
          content: params[:content],
          description: params[:description],
          project_id: params[:project_id],
          due_date: params[:due_date],
          priority: params[:priority] || 1,
          labels: params[:labels] || []
        )
        
        if response.success?
          task = JSON.parse(response.body)
          {
            success: true,
            task: format_task(task),
            message: "Task created successfully"
          }
        else
          { error: "Failed to create task: #{response.code}" }
        end
      end
      
      def update_task(params)
        task_id = params.delete(:task_id)
        return { error: "task_id required" } unless task_id
        
        response = @client.update_task(task_id, params)
        
        if response.success?
          {
            success: true,
            message: "Task updated successfully"
          }
        else
          { error: "Failed to update task: #{response.code}" }
        end
      end
      
      def complete_task(params)
        task_id = params[:task_id]
        return { error: "task_id required" } unless task_id
        
        response = @client.complete_task(task_id)
        
        if response.success?
          {
            success: true,
            message: "Task completed successfully"
          }
        else
          { error: "Failed to complete task: #{response.code}" }
        end
      end
      
      def list_projects
        response = @client.projects
        
        if response.success?
          projects = JSON.parse(response.body)
          {
            success: true,
            projects: projects.map { |p| format_project(p) },
            count: projects.size
          }
        else
          { error: "Failed to fetch projects: #{response.code}" }
        end
      end
      
      def format_task(task)
        {
          id: task['id'],
          content: task['content'],
          description: task['description'],
          completed: task['is_completed'],
          priority: task['priority'],
          due_date: task['due']&.dig('date'),
          project_id: task['project_id'],
          labels: task['labels']
        }
      end
      
      def format_project(project)
        {
          id: project['id'],
          name: project['name'],
          color: project['color'],
          is_favorite: project['is_favorite']
        }
      end
    end
  end
end