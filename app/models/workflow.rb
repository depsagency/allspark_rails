class Workflow < ApplicationRecord
  belongs_to :team, class_name: 'AgentTeam', foreign_key: 'team_id'
  belongs_to :user
  has_many :workflow_executions, dependent: :destroy
  
  validates :name, presence: true
  validates :team, presence: true
  validates :status, inclusion: { in: %w[draft active archived] }
  
  scope :active, -> { where(status: 'active') }
  scope :draft, -> { where(status: 'draft') }
  scope :archived, -> { where(status: 'archived') }
  
  def to_mermaid
    return mermaid_definition if mermaid_definition.present?
    
    # Generate Mermaid from flow_definition
    nodes = flow_definition['nodes'] || []
    edges = flow_definition['edges'] || []
    
    mermaid = "graph TD\n"
    
    # Add nodes
    nodes.each do |node|
      node_id = node['id']
      node_type = node['type']
      node_data = node['data'] || {}
      
      label = case node_type
      when 'start'
        "Start"
      when 'end'
        "End"
      when 'task'
        node_data['title'] || 'Task'
      when 'assistant'
        assistant = Assistant.find_by(id: node_data['assignee'])
        assistant&.name || 'Assistant'
      when 'decision'
        node_data['title'] || 'Decision'
      else
        node_type.humanize
      end
      
      shape = case node_type
      when 'start', 'end'
        "#{node_id}((#{label}))"
      when 'decision'
        "#{node_id}{#{label}}"
      else
        "#{node_id}[#{label}]"
      end
      
      mermaid += "    #{shape}\n"
    end
    
    # Add edges
    edges.each do |edge|
      source = edge['source']
      target = edge['target']
      edge_type = edge['type'] || 'sequential'
      label = edge['data'] && edge['data']['label']
      
      arrow = case edge_type
      when 'conditional'
        if label
          "-->|#{label}|"
        else
          "-->"
        end
      when 'parallel'
        "==>"
      else
        "-->"
      end
      
      mermaid += "    #{source} #{arrow} #{target}\n"
    end
    
    mermaid
  end
  
  def from_mermaid(mermaid_string)
    # Parse Mermaid and update flow_definition
    # This is a simplified parser - a full implementation would need more robust parsing
    lines = mermaid_string.split("\n").map(&:strip)
    
    nodes = []
    edges = []
    node_map = {}
    
    lines.each do |line|
      next if line.empty? || line.start_with?('graph')
      
      # Parse node definitions
      if match = line.match(/^(\w+)\[\[(.+?)\]\]$/) # Start/End nodes
        id, label = match[1], match[2]
        type = label.downcase == 'start' ? 'start' : 'end'
        nodes << { 'id' => id, 'type' => type, 'data' => { 'title' => label } }
        node_map[id] = true
      elsif match = line.match(/^(\w+)\[(.+?)\]$/) # Regular nodes
        id, label = match[1], match[2]
        nodes << { 'id' => id, 'type' => 'task', 'data' => { 'title' => label } }
        node_map[id] = true
      elsif match = line.match(/^(\w+)\{(.+?)\}$/) # Decision nodes
        id, label = match[1], match[2]
        nodes << { 'id' => id, 'type' => 'decision', 'data' => { 'title' => label } }
        node_map[id] = true
      elsif match = line.match(/^(\w+)\s*-->\s*(\w+)$/) # Simple edge
        source, target = match[1], match[2]
        edges << { 'id' => "#{source}-#{target}", 'source' => source, 'target' => target, 'type' => 'sequential' }
      elsif match = line.match(/^(\w+)\s*-->\|(.+?)\|\s*(\w+)$/) # Labeled edge
        source, label, target = match[1], match[2], match[3]
        edges << { 'id' => "#{source}-#{target}", 'source' => source, 'target' => target, 'type' => 'conditional', 'data' => { 'label' => label } }
      end
    end
    
    self.flow_definition = { 'nodes' => nodes, 'edges' => edges }
    self.mermaid_definition = mermaid_string
  end
  
  def validate_flow
    errors = []
    
    nodes = flow_definition['nodes'] || []
    edges = flow_definition['edges'] || []
    
    # Check for start node
    start_nodes = nodes.select { |n| n['type'] == 'start' }
    if start_nodes.empty?
      errors << "Workflow must have at least one start node"
    elsif start_nodes.length > 1
      errors << "Workflow should have only one start node"
    end
    
    # Check for end node
    end_nodes = nodes.select { |n| n['type'] == 'end' }
    if end_nodes.empty?
      errors << "Workflow must have at least one end node"
    end
    
    # Check for disconnected nodes
    node_ids = nodes.map { |n| n['id'] }.to_set
    connected_nodes = Set.new
    
    edges.each do |edge|
      connected_nodes.add(edge['source'])
      connected_nodes.add(edge['target'])
    end
    
    disconnected = node_ids - connected_nodes
    unless disconnected.empty?
      errors << "Disconnected nodes found: #{disconnected.to_a.join(', ')}"
    end
    
    # Check for circular dependencies
    if has_circular_dependency?
      errors << "Workflow contains circular dependencies"
    end
    
    errors
  end
  
  private
  
  def has_circular_dependency?
    nodes = flow_definition['nodes'] || []
    edges = flow_definition['edges'] || []
    
    # Build adjacency list
    graph = Hash.new { |h, k| h[k] = [] }
    edges.each do |edge|
      graph[edge['source']] << edge['target']
    end
    
    # DFS to detect cycles
    visited = Set.new
    rec_stack = Set.new
    
    nodes.each do |node|
      node_id = node['id']
      if detect_cycle(node_id, graph, visited, rec_stack)
        return true
      end
    end
    
    false
  end
  
  def detect_cycle(node, graph, visited, rec_stack)
    visited.add(node)
    rec_stack.add(node)
    
    graph[node].each do |neighbor|
      if !visited.include?(neighbor)
        return true if detect_cycle(neighbor, graph, visited, rec_stack)
      elsif rec_stack.include?(neighbor)
        return true
      end
    end
    
    rec_stack.delete(node)
    false
  end
end