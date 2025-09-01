# frozen_string_literal: true

class AgentTeam < ApplicationRecord
  belongs_to :user
  has_and_belongs_to_many :assistants
  has_many :agent_team_executions, dependent: :destroy
  has_many :workflows, foreign_key: 'team_id', dependent: :destroy
  
  # Validations
  validates :name, presence: true
  validates :purpose, presence: true
  
  # Store configuration
  store_accessor :configuration, :coordination_mode, :max_iterations, :timeout_seconds
  
  # Scopes
  scope :active, -> { where(active: true) }
  
  # Default configuration
  after_initialize :set_defaults, if: :new_record?
  
  # Create a coordinator for this team
  def create_coordinator(context: {})
    coordinator = Agents::Coordinator.new(user: user, context: context)
    
    # Register all team agents
    assistants.each do |assistant|
      # Register by name
      coordinator.register_agent(assistant.name.parameterize.underscore, assistant)
      
      # Also register by capabilities/keywords if present
      register_agent_capabilities(coordinator, assistant)
    end
    
    coordinator
  end
  
  private
  
  def register_agent_capabilities(coordinator, assistant)
    # Analyze assistant's name and instructions for capabilities
    text = "#{assistant.name} #{assistant.instructions}".downcase
    
    # Register based on detected capabilities
    if text.include?('write') || text.include?('writer') || text.include?('content')
      coordinator.register_agent(:writer, assistant)
    end
    
    if text.include?('research') || text.include?('search') || text.include?('find')
      coordinator.register_agent(:researcher, assistant)
    end
    
    if text.include?('code') || text.include?('program') || text.include?('developer')
      coordinator.register_agent(:coder, assistant)
    end
    
    # Always register as general for fallback
    coordinator.register_agent(:general, assistant)
  end
  
  public
  
  # Execute a task with the team
  def execute_task(task, context: {})
    coordinator = create_coordinator(context: context)
    
    # Record the execution
    execution = agent_team_executions.create!(
      task: task,
      status: :running,
      started_at: Time.current
    )
    
    begin
      # Pass execution to coordinator for progress tracking
      result = coordinator.execute(task, execution: execution)
      
      execution.update!(
        status: result[:status],
        completed_at: Time.current,
        result_data: result
      )
      
      result
    rescue => e
      execution.update!(
        status: :failed,
        completed_at: Time.current,
        error_message: e.message
      )
      
      raise
    end
  end
  
  # Get team capabilities
  def capabilities
    tools = assistants.flat_map { |a| a.tools.map { |t| t['type'] } }.uniq
    
    {
      agents: assistants.count,
      tools: tools,
      coordination_modes: available_coordination_modes
    }
  end
  
  # Execute a workflow
  def execute_workflow(workflow_id, params = {})
    workflow = workflows.find(workflow_id)
    
    raise "Workflow not active" unless workflow.status == 'active'
    
    execution = workflow.workflow_executions.create!(
      started_by: user.id,
      status: 'pending',
      execution_data: params
    )
    
    # Start the workflow execution asynchronously
    WorkflowExecutionJob.perform_later(execution)
    
    execution
  end
  
  private
  
  def set_defaults
    self.coordination_mode ||= 'sequential'
    self.max_iterations ||= 10
    self.timeout_seconds ||= 300
    self.active = true if active.nil?
  end
  
  def available_coordination_modes
    %w[sequential parallel hierarchical consensus]
  end
end