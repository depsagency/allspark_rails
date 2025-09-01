class WorkflowValidationService
  attr_reader :workflow, :errors
  
  def initialize(workflow)
    @workflow = workflow
    @errors = []
  end
  
  def validate
    @errors = []
    
    validate_flow_structure
    check_circular_dependencies
    validate_assistant_assignments
    validate_required_fields
    
    @errors
  end
  
  def valid?
    validate
    @errors.empty?
  end
  
  def validate_flow_structure
    nodes = workflow.flow_definition['nodes'] || []
    edges = workflow.flow_definition['edges'] || []
    
    # Check for empty workflow
    if nodes.empty?
      @errors << "Workflow must contain at least one node"
      return
    end
    
    # Check for start node
    start_nodes = nodes.select { |n| n['type'] == 'start' }
    if start_nodes.empty?
      @errors << "Workflow must have a start node"
    elsif start_nodes.length > 1
      @errors << "Workflow should have only one start node"
    end
    
    # Check for end node
    end_nodes = nodes.select { |n| n['type'] == 'end' }
    if end_nodes.empty?
      @errors << "Workflow must have at least one end node"
    end
    
    # Check node IDs are unique
    node_ids = nodes.map { |n| n['id'] }
    if node_ids.length != node_ids.uniq.length
      @errors << "Duplicate node IDs found"
    end
    
    # Check edges reference valid nodes
    node_id_set = node_ids.to_set
    edges.each do |edge|
      unless node_id_set.include?(edge['source'])
        @errors << "Edge references non-existent source node: #{edge['source']}"
      end
      unless node_id_set.include?(edge['target'])
        @errors << "Edge references non-existent target node: #{edge['target']}"
      end
    end
    
    # Check for disconnected nodes
    check_disconnected_nodes(nodes, edges)
    
    # Check decision nodes have multiple outgoing edges
    check_decision_nodes(nodes, edges)
  end
  
  def check_circular_dependencies
    nodes = workflow.flow_definition['nodes'] || []
    edges = workflow.flow_definition['edges'] || []
    
    adjacency = build_adjacency_list(edges)
    
    if has_cycle?(nodes.map { |n| n['id'] }, adjacency)
      @errors << "Workflow contains circular dependencies"
    end
  end
  
  def validate_assistant_assignments
    nodes = workflow.flow_definition['nodes'] || []
    team_assistant_ids = workflow.team.assistants.pluck(:id).map(&:to_s).to_set
    
    nodes.each do |node|
      next unless node['type'] == 'assistant' || node['type'] == 'task'
      
      assignee_id = node.dig('data', 'assignee')
      
      if assignee_id.blank? && node['type'] == 'assistant'
        @errors << "Assistant node '#{node['id']}' has no assistant assigned"
      elsif assignee_id.present? && !team_assistant_ids.include?(assignee_id.to_s)
        @errors << "Node '#{node['id']}' assigned to assistant not in team"
      end
    end
  end
  
  def validate_required_fields
    nodes = workflow.flow_definition['nodes'] || []
    
    nodes.each do |node|
      node_data = node['data'] || {}
      
      # Validate node has required fields based on type
      case node['type']
      when 'task'
        if node_data['title'].blank?
          @errors << "Task node '#{node['id']}' missing title"
        end
        if node_data['instructions'].blank?
          @errors << "Task node '#{node['id']}' missing instructions"
        end
      when 'decision'
        if node_data['conditions'].blank?
          @errors << "Decision node '#{node['id']}' missing conditions"
        end
      end
      
      # Validate position data
      if node['position'].nil? || !node['position'].is_a?(Hash)
        @errors << "Node '#{node['id']}' missing position data"
      elsif node['position']['x'].nil? || node['position']['y'].nil?
        @errors << "Node '#{node['id']}' has invalid position data"
      end
    end
    
    # Validate edges
    edges = workflow.flow_definition['edges'] || []
    edges.each do |edge|
      if edge['id'].blank?
        @errors << "Edge missing ID"
      end
      
      if edge['type'] == 'conditional' && edge.dig('data', 'condition').blank?
        @errors << "Conditional edge '#{edge['id']}' missing condition"
      end
    end
  end
  
  private
  
  def check_disconnected_nodes(nodes, edges)
    # Build sets of connected nodes
    connected_nodes = Set.new
    
    # Add all nodes that are sources or targets of edges
    edges.each do |edge|
      connected_nodes.add(edge['source'])
      connected_nodes.add(edge['target'])
    end
    
    # Start nodes are considered connected even without incoming edges
    start_nodes = nodes.select { |n| n['type'] == 'start' }.map { |n| n['id'] }
    connected_nodes.merge(start_nodes)
    
    # Check for disconnected nodes
    all_node_ids = nodes.map { |n| n['id'] }.to_set
    disconnected = all_node_ids - connected_nodes
    
    unless disconnected.empty?
      @errors << "Disconnected nodes found: #{disconnected.to_a.join(', ')}"
    end
  end
  
  def check_decision_nodes(nodes, edges)
    decision_nodes = nodes.select { |n| n['type'] == 'decision' }
    
    decision_nodes.each do |decision_node|
      outgoing_edges = edges.select { |e| e['source'] == decision_node['id'] }
      
      if outgoing_edges.length < 2
        @errors << "Decision node '#{decision_node['id']}' should have at least 2 outgoing edges"
      end
      
      # Check that outgoing edges have conditions
      outgoing_edges.each do |edge|
        if edge.dig('data', 'label').blank?
          @errors << "Decision node edge from '#{decision_node['id']}' missing condition label"
        end
      end
    end
  end
  
  def build_adjacency_list(edges)
    adjacency = Hash.new { |h, k| h[k] = [] }
    
    edges.each do |edge|
      adjacency[edge['source']] << edge['target']
    end
    
    adjacency
  end
  
  def has_cycle?(node_ids, adjacency)
    white = node_ids.to_set  # Unvisited
    gray = Set.new           # Being processed
    black = Set.new          # Processed
    
    while white.any?
      node = white.first
      if dfs_cycle_check(node, adjacency, white, gray, black)
        return true
      end
    end
    
    false
  end
  
  def dfs_cycle_check(node, adjacency, white, gray, black)
    # Move from white to gray
    white.delete(node)
    gray.add(node)
    
    # Check all neighbors
    (adjacency[node] || []).each do |neighbor|
      if gray.include?(neighbor)
        # Back edge found - cycle detected
        return true
      elsif white.include?(neighbor)
        # Recursively check unvisited neighbor
        if dfs_cycle_check(neighbor, adjacency, white, gray, black)
          return true
        end
      end
    end
    
    # Move from gray to black
    gray.delete(node)
    black.add(node)
    
    false
  end
end