# frozen_string_literal: true

module Integrations
  class TodoistClient
    include HTTParty
    base_uri 'https://api.todoist.com/rest/v2'
    
    def initialize(access_token)
      @access_token = access_token
      @headers = {
        'Authorization' => "Bearer #{@access_token}",
        'Content-Type' => 'application/json'
      }
    end
    
    # Get all projects
    def projects
      self.class.get('/projects', headers: @headers)
    end
    
    # Get all tasks
    def tasks(filter: nil, project_id: nil)
      options = { headers: @headers }
      
      if filter || project_id
        options[:query] = {}
        options[:query][:filter] = filter if filter
        options[:query][:project_id] = project_id if project_id
      end
      
      self.class.get('/tasks', options)
    end
    
    # Get a specific task
    def task(task_id)
      self.class.get("/tasks/#{task_id}", headers: @headers)
    end
    
    # Create a new task
    def create_task(content:, description: nil, project_id: nil, due_date: nil, priority: 1, labels: [])
      body = {
        content: content,
        priority: priority
      }
      
      body[:description] = description if description
      body[:project_id] = project_id if project_id
      body[:due_date] = due_date if due_date
      body[:labels] = labels if labels.any?
      
      self.class.post('/tasks', 
        headers: @headers,
        body: body.to_json
      )
    end
    
    # Update a task
    def update_task(task_id, updates = {})
      self.class.post("/tasks/#{task_id}", 
        headers: @headers,
        body: updates.to_json
      )
    end
    
    # Complete a task
    def complete_task(task_id)
      self.class.post("/tasks/#{task_id}/close", headers: @headers)
    end
    
    # Reopen a task
    def reopen_task(task_id)
      self.class.post("/tasks/#{task_id}/reopen", headers: @headers)
    end
    
    # Delete a task
    def delete_task(task_id)
      self.class.delete("/tasks/#{task_id}", headers: @headers)
    end
    
    # Get comments for a task
    def task_comments(task_id)
      self.class.get('/comments', 
        headers: @headers,
        query: { task_id: task_id }
      )
    end
    
    # Add a comment to a task
    def add_comment(task_id:, content:)
      self.class.post('/comments',
        headers: @headers,
        body: {
          task_id: task_id,
          content: content
        }.to_json
      )
    end
    
    # Check if authenticated
    def authenticated?
      response = self.class.get('/projects', headers: @headers)
      response.code == 200
    rescue
      false
    end
  end
end