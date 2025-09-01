class WorkflowExecutionService
  attr_reader :workflow, :user, :execution
  
  def initialize(workflow, user)
    @workflow = workflow
    @user = user
  end
  
  def execute(params = {})
    # Validate workflow before execution
    validation_errors = workflow.validate_flow
    raise "Invalid workflow: #{validation_errors.join(', ')}" if validation_errors.any?
    
    # Create execution record
    @execution = workflow.workflow_executions.create!(
      started_by: user.id,
      status: 'pending',
      execution_data: params
    )
    
    # Start execution
    execution.start!
    
    # Queue the execution job
    WorkflowExecutionJob.perform_later(execution)
    
    execution
  rescue => e
    execution&.fail!(e.message)
    raise
  end
  
  def parse_flow_definition
    flow = workflow.flow_definition
    nodes = flow['nodes'] || []
    edges = flow['edges'] || []
    
    {
      nodes: nodes.index_by { |n| n['id'] },
      edges: edges,
      adjacency: build_adjacency_list(edges),
      start_nodes: find_start_nodes(nodes, edges),
      end_nodes: find_end_nodes(nodes)
    }
  end
  
  def create_execution_plan
    parsed = parse_flow_definition
    plan = []
    
    # Topological sort to determine execution order
    sorted_nodes = topological_sort(parsed[:nodes].keys, parsed[:adjacency])
    
    # Group nodes by levels for parallel execution
    levels = calculate_levels(sorted_nodes, parsed[:adjacency])
    
    levels.each do |level, node_ids|
      level_tasks = node_ids.map do |node_id|
        node = parsed[:nodes][node_id]
        next if node['type'] == 'start' || node['type'] == 'end'
        
        {
          node_id: node_id,
          node: node,
          level: level,
          dependencies: find_dependencies(node_id, parsed[:edges])
        }
      end.compact
      
      plan << level_tasks unless level_tasks.empty?
    end
    
    plan
  end
  
  def handle_parallel_execution(tasks)
    # Execute tasks in parallel using threads or jobs
    threads = tasks.map do |task_data|
      Thread.new do
        create_and_execute_task(task_data)
      end
    end
    
    threads.each(&:join)
  end
  
  def handle_conditional_branching(node, edges)
    # Evaluate conditions for decision nodes
    outgoing_edges = edges.select { |e| e['source'] == node['id'] }
    
    # For now, return all branches - in future, evaluate conditions
    outgoing_edges
  end
  
  private
  
  def build_adjacency_list(edges)
    adjacency = Hash.new { |h, k| h[k] = [] }
    
    edges.each do |edge|
      adjacency[edge['source']] << edge['target']
    end
    
    adjacency
  end
  
  def find_start_nodes(nodes, edges)
    # Start nodes are nodes with type 'start' or nodes with no incoming edges
    target_nodes = edges.map { |e| e['target'] }.to_set
    
    nodes.select do |node|
      node['type'] == 'start' || !target_nodes.include?(node['id'])
    end
  end
  
  def find_end_nodes(nodes)
    nodes.select { |n| n['type'] == 'end' }
  end
  
  def topological_sort(node_ids, adjacency)
    sorted = []
    visited = Set.new
    temp_visited = Set.new
    
    node_ids.each do |node_id|
      visit(node_id, adjacency, visited, temp_visited, sorted) unless visited.include?(node_id)
    end
    
    sorted
  end
  
  def visit(node, adjacency, visited, temp_visited, sorted)
    raise "Circular dependency detected" if temp_visited.include?(node)
    
    return if visited.include?(node)
    
    temp_visited.add(node)
    
    adjacency[node].each do |neighbor|
      visit(neighbor, adjacency, visited, temp_visited, sorted)
    end
    
    temp_visited.delete(node)
    visited.add(node)
    sorted.unshift(node)
  end
  
  def calculate_levels(sorted_nodes, adjacency)
    levels = {}
    node_levels = {}
    
    sorted_nodes.each do |node|
      # Find the maximum level of all dependencies
      max_dep_level = -1
      
      adjacency.each do |source, targets|
        if targets.include?(node) && node_levels[source]
          max_dep_level = [max_dep_level, node_levels[source]].max
        end
      end
      
      level = max_dep_level + 1
      node_levels[node] = level
      
      levels[level] ||= []
      levels[level] << node
    end
    
    levels
  end
  
  def find_dependencies(node_id, edges)
    edges.select { |e| e['target'] == node_id }.map { |e| e['source'] }
  end
  
  def create_and_execute_task(task_data)
    node = task_data[:node]
    node_data = node['data'] || {}
    
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
    
    task = execution.workflow_tasks.create!(
      node_id: node['id'],
      title: node_data['title'] || node['type'].humanize,
      instructions: instructions,
      assistant_id: assistant_id,
      status: 'pending'
    )
    
    # Execute if dependencies are met
    if dependencies_met?(task_data[:dependencies])
      task.execute!
    end
  end
  
  def dependencies_met?(dependency_node_ids)
    return true if dependency_node_ids.empty?
    
    dependency_node_ids.all? do |dep_id|
      task = execution.workflow_tasks.find_by(node_id: dep_id)
      task && task.completed?
    end
  end
end