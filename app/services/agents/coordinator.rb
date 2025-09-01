# frozen_string_literal: true

module Agents
  class Coordinator
    attr_reader :agents, :user, :context
    
    def initialize(user:, context: {})
      @user = user
      @context = context
      @agents = {}
      @message_queue = []
    end
    
    # Register an agent
    def register_agent(name, assistant)
      @agents[name.to_sym] = {
        assistant: assistant,
        status: :idle,
        current_task: nil
      }
    end
    
    # Execute a multi-agent workflow
    def execute(task, plan: nil, execution: nil)
      run_id = SecureRandom.uuid
      
      # Broadcast execution start
      broadcast_progress(execution, 'started', { task: task }) if execution
      
      # Create execution plan if not provided
      plan ||= create_execution_plan(task)
      
      # Broadcast plan created
      broadcast_progress(execution, 'plan_created', { 
        plan: plan, 
        total_steps: plan[:steps].size 
      }) if execution
      
      # Execute plan steps
      results = []
      plan[:steps].each_with_index do |step, index|
        # Broadcast step start
        broadcast_progress(execution, 'step_started', { 
          step_number: index + 1,
          total_steps: plan[:steps].size,
          step: step 
        }) if execution
        
        result = execute_step(step, run_id, results)
        results << result
        
        # Broadcast step complete
        broadcast_progress(execution, 'step_completed', { 
          step_number: index + 1,
          total_steps: plan[:steps].size,
          step: step,
          result: result 
        }) if execution
        
        # Stop if step failed
        break if result[:status] == :failed
      end
      
      final_status = results.all? { |r| r[:status] == :completed } ? :completed : :failed
      
      # Broadcast execution complete
      broadcast_progress(execution, 'completed', { 
        status: final_status,
        results: results 
      }) if execution
      
      {
        run_id: run_id,
        task: task,
        plan: plan,
        results: results,
        status: final_status
      }
    end
    
    # Create an execution plan
    def create_execution_plan(task)
      # Use a planning agent to decompose the task
      planner = find_or_create_planner
      
      # Include agent information in the planning prompt
      agent_info = @agents.map { |name, _| name.to_s }.join(", ")
      
      prompt = <<~PROMPT
        Create a step-by-step plan for: #{task}
        
        Available agents: #{agent_info}
        
        Format as a numbered list with one action per line.
        If you have multiple agents available, distribute the work among them.
      PROMPT
      
      response = planner.run(
        content: prompt,
        user: user
      )
      
      # Parse the response into steps
      plan_content = response.respond_to?(:content) ? response.content : response.to_s
      parse_plan(plan_content)
    rescue => e
      # Fallback to simple single-agent execution
      {
        steps: [
          {
            agent: :general,
            action: task,
            dependencies: []
          }
        ]
      }
    end
    
    private
    
    def execute_step(step, run_id, previous_results)
      agent_name = step[:agent]
      agent = @agents[agent_name]
      
      # If specific agent not found, try to find the best available agent
      if !agent && @agents.any?
        agent_name, agent = find_best_agent_for_step(step)
      end
      
      return { status: :failed, error: "No agents available" } unless agent
      
      # Update agent status
      @agents[agent_name][:status] = :working
      @agents[agent_name][:current_task] = step[:action]
      
      # Build context from previous results
      step_context = build_step_context(step, previous_results)
      
      # Execute the task
      begin
        response = agent[:assistant].run(
          content: "#{step[:action]}\n\nContext: #{step_context.to_json}",
          user: user,
          run_id: "#{run_id}-#{agent_name}"
        )
        
        @agents[agent_name][:status] = :idle
        @agents[agent_name][:current_task] = nil
        
        response_content = response.respond_to?(:content) ? response.content : response.to_s
        
        {
          step: step,
          agent: agent_name,
          response: response_content,
          status: :completed
        }
      rescue => e
        @agents[agent_name][:status] = :error
        
        {
          step: step,
          agent: agent_name,
          error: e.message,
          status: :failed
        }
      end
    end
    
    def build_step_context(step, previous_results)
      context = @context.dup
      
      # Add results from dependencies
      if step[:dependencies].any?
        context[:previous_results] = previous_results.select do |result|
          step[:dependencies].include?(result[:step][:id])
        end
      end
      
      context
    end
    
    def find_or_create_planner
      # Look for a planning agent
      planner = @agents[:planner]
      return planner[:assistant] if planner
      
      # Use the first available agent as planner if no dedicated planner exists
      if @agents.any?
        return @agents.values.first[:assistant]
      end
      
      # Create a default planner for the user
      Assistant.find_or_create_by(name: 'Planning Assistant', user: user) do |asst|
        asst.instructions = <<~INSTRUCTIONS
          You are a planning assistant that breaks down complex tasks into steps.
          
          Format your response as a numbered list like this:
          1. First action to take
          2. Second action to take
          3. Third action to take
          
          Keep each step concise and actionable.
        INSTRUCTIONS
        asst.tool_choice = 'none'
        asst.active = true
      end
    end
    
    def parse_plan(plan_text)
      steps = []
      
      # Look for various step formats
      # Match "Step N:" or "### Step N:" or just numbered lists
      patterns = [
        /(?:###\s*)?Step\s+(\d+):\s*(.+?)(?:\n|$)/i,
        /(\d+)[.)]\s*(.+?)(?:\n|$)/
      ]
      
      # Track how many times each agent type is used for round-robin
      agent_usage = Hash.new(0)
      
      patterns.each do |pattern|
        matches = plan_text.scan(pattern)
        if matches.any?
          matches.each_with_index do |(step_num, text), index|
            # Skip if text includes "Agent:" marker (we'll extract that separately)
            next if text.include?('**Agent:**')
            
            # Extract agent type if mentioned
            agent_type = case text.downcase
                        when /search|research|find/
                          :researcher
                        when /code|program|implement/
                          :coder
                        when /write|document|draft|email/
                          :writer
                        else
                          :general
                        end
            
            # If we have multiple agents, distribute tasks
            agent = if @agents.size > 1
                     # Use round-robin to distribute tasks
                     available_agents = @agents.keys
                     agent_index = index % available_agents.size
                     available_agents[agent_index]
                   else
                     agent_type
                   end
            
            steps << {
              id: index + 1,
              agent: agent,
              action: text.strip,
              dependencies: index > 0 ? [index] : []
            }
          end
          break if steps.any?
        end
      end
      
      # If no steps found, create a single step with the entire task
      if steps.empty?
        steps << {
          id: 1,
          agent: @agents.keys.first || :general,
          action: "Complete the task",
          dependencies: []
        }
      end
      
      { steps: steps }
    end
    
    def broadcast_progress(execution, event, data = {})
      return unless execution
      
      ActionCable.server.broadcast(
        "team_execution_#{execution.id}",
        {
          event: event,
          execution_id: execution.id,
          timestamp: Time.current.iso8601,
          data: data
        }
      )
    end
    
    def find_best_agent_for_step(step)
      # Try to find the least busy agent
      available_agents = @agents.select { |_, agent| agent[:status] == :idle }
      
      if available_agents.any?
        # Return the least recently used agent
        agent_name, agent = available_agents.first
        [agent_name, agent]
      else
        # All agents are busy, use round-robin
        agent_name = @agents.keys[@current_agent_index % @agents.size]
        @current_agent_index = (@current_agent_index || 0) + 1
        [agent_name, @agents[agent_name]]
      end
    end
  end
end