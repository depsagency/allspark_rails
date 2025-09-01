class WorkflowExecution < ApplicationRecord
  belongs_to :workflow
  belongs_to :user, foreign_key: 'started_by'
  has_many :workflow_tasks, dependent: :destroy
  
  validates :status, inclusion: { in: %w[pending running completed failed cancelled] }
  
  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :running, -> { where(status: 'running') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :finished, -> { where(status: %w[completed failed cancelled]) }
  
  # State machine transitions
  def start!
    return false unless status == 'pending'
    
    transaction do
      update!(
        status: 'running',
        started_at: Time.current
      )
      
      # Create initial tasks based on workflow definition
      create_initial_tasks
    end
    
    true
  end
  
  def complete!
    return false unless status == 'running'
    
    update!(
      status: 'completed',
      completed_at: Time.current
    )
    
    # Broadcast completion status
    ActionCable.server.broadcast(
      "workflow_execution_#{id}",
      {
        type: 'execution_update',
        status: 'completed',
        progress_percentage: 100,
        completed_at: completed_at
      }
    )
    
    Rails.logger.info "[EXECUTION] Broadcast completion for execution #{id}"
    
    true
  end
  
  def fail!(error_message = nil)
    return false unless %w[pending running].include?(status)
    
    update!(
      status: 'failed',
      completed_at: Time.current,
      execution_data: execution_data.merge('error' => error_message)
    )
    
    true
  end
  
  def cancel!
    return false unless %w[pending running].include?(status)
    
    transaction do
      # Cancel any pending or running tasks
      workflow_tasks.where(status: %w[pending running]).each do |task|
        task.update!(status: 'cancelled')
      end
      
      update!(
        status: 'cancelled',
        completed_at: Time.current
      )
    end
    
    true
  end
  
  def progress_percentage
    return 0 if workflow_tasks.empty?
    
    completed_tasks = workflow_tasks.where(status: 'completed').count
    total_tasks = workflow_tasks.count
    
    (completed_tasks.to_f / total_tasks * 100).round
  end
  
  def elapsed_time
    return nil unless started_at
    
    end_time = completed_at || Time.current
    end_time - started_at
  end
  
  def running?
    status == 'running'
  end
  
  def completed?
    status == 'completed'
  end
  
  def failed?
    status == 'failed'
  end
  
  def cancelled?
    status == 'cancelled'
  end
  
  private
  
  def create_initial_tasks
    flow_definition = workflow.flow_definition
    nodes = flow_definition['nodes'] || []
    edges = flow_definition['edges'] || []
    
    # Find start nodes
    start_nodes = nodes.select { |n| n['type'] == 'start' }
    
    # Find nodes immediately after start
    start_node_ids = start_nodes.map { |n| n['id'] }
    initial_edges = edges.select { |e| start_node_ids.include?(e['source']) }
    
    initial_edges.each do |edge|
      target_node_id = edge['target']
      target_node = nodes.find { |n| n['id'] == target_node_id }
      
      next unless target_node
      
      create_task_from_node(target_node)
    end
  end
  
  def broadcast_task_created(task)
    assistant_name = task.assistant&.name || 'Unassigned'
    
    ActionCable.server.broadcast(
      "workflow_execution_#{id}",
      {
        type: 'task_created',
        task: {
          id: task.id,
          node_id: task.node_id,
          title: task.title,
          instructions: task.instructions,
          assistant_name: assistant_name,
          status: task.status,
          started_at: task.started_at,
          completed_at: task.completed_at
        }
      }
    )
  end
  
  def create_task_from_node(node)
    node_data = node['data'] || {}
    
    # Check if task already exists for this execution
    existing_task = workflow_tasks.find_by(node_id: node['id'])
    return existing_task if existing_task
    
    # Extract assistant_id from assignee data
    assistant_id = if node_data['assignee'].is_a?(Hash)
                     node_data['assignee']['id']
                   elsif node_data['assignee'].is_a?(String)
                     node_data['assignee']
                   else
                     nil
                   end
    
    # For assistant nodes, the instructions might be in the task field
    instructions = node_data['instructions']
    if node['type'] == 'assistant' && node_data['task']
      instructions = node_data['task']['title'] || instructions
    end
    
    task = workflow_tasks.create!(
      node_id: node['id'],
      title: node_data['title'] || node['type'].humanize,
      instructions: instructions,
      assistant_id: assistant_id,
      status: 'pending'
    )
    
    # Broadcast task creation
    broadcast_task_created(task)
    
    task
  end
end