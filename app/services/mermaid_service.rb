class MermaidService
  def self.workflow_to_mermaid(workflow)
    new.workflow_to_mermaid(workflow)
  end
  
  def self.mermaid_to_workflow(mermaid_string)
    new.mermaid_to_workflow(mermaid_string)
  end
  
  def workflow_to_mermaid(workflow)
    nodes = workflow.flow_definition['nodes'] || []
    edges = workflow.flow_definition['edges'] || []
    
    mermaid = "graph TD\n"
    
    # Group nodes by type for better organization
    node_definitions = []
    subgraph_definitions = []
    
    # Process nodes
    nodes.each do |node|
      node_def = format_node(node, workflow)
      node_definitions << "    #{node_def}"
    end
    
    # Process edges
    edge_definitions = edges.map do |edge|
      format_edge(edge, nodes)
    end
    
    # Combine all parts
    mermaid += node_definitions.join("\n") + "\n" if node_definitions.any?
    mermaid += "\n" + edge_definitions.map { |e| "    #{e}" }.join("\n") if edge_definitions.any?
    
    # Add styling
    mermaid += "\n\n" + generate_styling(nodes)
    
    mermaid
  end
  
  def mermaid_to_workflow(mermaid_string)
    lines = mermaid_string.split("\n").map(&:strip)
    
    nodes = []
    edges = []
    node_positions = {}
    current_line = 0
    
    lines.each_with_index do |line, index|
      current_line = index
      next if line.empty? || line.start_with?('#')
      
      # Skip graph declaration
      next if line.match?(/^graph\s+(TD|LR|TB|BT|RL)/)
      
      # Skip style definitions
      next if line.match?(/^style\s+/) || line.match?(/^classDef\s+/) || line.match?(/^class\s+/)
      
      # Parse node definitions
      if node_match = parse_node_definition(line)
        nodes << create_node_from_match(node_match, index)
      end
      
      # Parse edge definitions
      if edge_match = parse_edge_definition(line)
        edges << create_edge_from_match(edge_match)
      end
    end
    
    # Auto-layout nodes if positions not specified
    if node_positions.empty?
      apply_auto_layout(nodes, edges)
    end
    
    {
      'nodes' => nodes,
      'edges' => edges
    }
  end
  
  def validate_mermaid_syntax(mermaid_string)
    errors = []
    
    lines = mermaid_string.split("\n").map(&:strip)
    
    # Check for graph declaration
    has_graph_declaration = lines.any? { |l| l.match?(/^graph\s+(TD|LR|TB|BT|RL)/) }
    errors << "Missing graph declaration (e.g., 'graph TD')" unless has_graph_declaration
    
    # Check for balanced brackets
    bracket_count = {
      '[' => 0, ']' => 0,
      '(' => 0, ')' => 0,
      '{' => 0, '}' => 0
    }
    
    mermaid_string.chars.each do |char|
      bracket_count[char] += 1 if bracket_count.key?(char)
    end
    
    errors << "Unbalanced square brackets" if bracket_count['['] != bracket_count[']']
    errors << "Unbalanced parentheses" if bracket_count['('] != bracket_count[')']
    errors << "Unbalanced curly braces" if bracket_count['{'] != bracket_count['}']
    
    # Check for valid node and edge syntax
    lines.each_with_index do |line, index|
      next if line.empty? || line.start_with?('#') || line.match?(/^graph\s+/)
      next if line.match?(/^style\s+/) || line.match?(/^classDef\s+/)
      
      unless valid_node_or_edge?(line)
        errors << "Invalid syntax at line #{index + 1}: #{line}"
      end
    end
    
    errors
  end
  
  def extract_nodes_and_edges(mermaid_string)
    result = mermaid_to_workflow(mermaid_string)
    
    {
      nodes: result['nodes'],
      edges: result['edges'],
      node_count: result['nodes'].length,
      edge_count: result['edges'].length,
      has_start: result['nodes'].any? { |n| n['type'] == 'start' },
      has_end: result['nodes'].any? { |n| n['type'] == 'end' }
    }
  end
  
  private
  
  def format_node(node, workflow)
    node_id = node['id']
    node_type = node['type']
    node_data = node['data'] || {}
    
    label = node_label(node, workflow)
    
    case node_type
    when 'start'
      "#{node_id}((#{label}))"
    when 'end'
      "#{node_id}((#{label}))"
    when 'decision'
      "#{node_id}{#{label}}"
    when 'assistant', 'task'
      "#{node_id}[#{label}]"
    else
      "#{node_id}[#{label}]"
    end
  end
  
  def node_label(node, workflow)
    node_data = node['data'] || {}
    
    case node['type']
    when 'start'
      "Start"
    when 'end'
      "End"
    when 'assistant'
      if node_data['assignee']
        assistant = workflow.team.assistants.find_by(id: node_data['assignee'])
        assistant&.name || "Assistant"
      else
        "Unassigned"
      end
    when 'task'
      node_data['title'] || "Task"
    when 'decision'
      node_data['title'] || "Decision"
    else
      node['type'].humanize
    end
  end
  
  def format_edge(edge, nodes)
    source = edge['source']
    target = edge['target']
    edge_type = edge['type'] || 'sequential'
    edge_data = edge['data'] || {}
    
    # Get node types for special formatting
    source_node = nodes.find { |n| n['id'] == source }
    target_node = nodes.find { |n| n['id'] == target }
    
    arrow = case edge_type
    when 'conditional'
      if edge_data['label']
        "-->|#{edge_data['label']}|"
      else
        "-->"
      end
    when 'parallel'
      "==>"
    else
      "-->"
    end
    
    "#{source} #{arrow} #{target}"
  end
  
  def generate_styling(nodes)
    styles = []
    
    # Define class styles
    styles << "    classDef startEnd fill:#90EE90,stroke:#006400,stroke-width:2px;"
    styles << "    classDef task fill:#87CEEB,stroke:#4682B4,stroke-width:2px;"
    styles << "    classDef decision fill:#FFD700,stroke:#FF8C00,stroke-width:2px;"
    styles << "    classDef assistant fill:#DDA0DD,stroke:#8B008B,stroke-width:2px;"
    
    # Apply classes to nodes
    node_classes = {
      'start' => 'startEnd',
      'end' => 'startEnd',
      'task' => 'task',
      'decision' => 'decision',
      'assistant' => 'assistant'
    }
    
    class_assignments = {}
    nodes.each do |node|
      class_name = node_classes[node['type']] || 'task'
      class_assignments[class_name] ||= []
      class_assignments[class_name] << node['id']
    end
    
    class_assignments.each do |class_name, node_ids|
      styles << "    class #{node_ids.join(',')} #{class_name};" if node_ids.any?
    end
    
    styles.join("\n")
  end
  
  def parse_node_definition(line)
    # Match various node syntaxes
    patterns = [
      /^(\w+)\(\((.+?)\)\)$/,          # Circle: ID((label))
      /^(\w+)\[(.+?)\]$/,              # Rectangle: ID[label]
      /^(\w+)\{(.+?)\}$/,              # Diamond: ID{label}
      /^(\w+)\[\[(.+?)\]\]$/,          # Subroutine: ID[[label]]
      /^(\w+)\[\/(.+?)\/\]$/,          # Trapezoid: ID[/label/]
      /^(\w+)\[\\(.+?)\\\]$/           # Trapezoid alt: ID[\label\]
    ]
    
    patterns.each do |pattern|
      if match = line.match(pattern)
        return {
          id: match[1],
          label: match[2],
          shape: detect_shape_from_pattern(pattern)
        }
      end
    end
    
    nil
  end
  
  def parse_edge_definition(line)
    # Match various edge syntaxes
    patterns = [
      /^(\w+)\s*-->\s*(\w+)$/,                    # Simple arrow
      /^(\w+)\s*-->\|(.+?)\|\s*(\w+)$/,         # Labeled arrow
      /^(\w+)\s*==>\s*(\w+)$/,                    # Thick arrow
      /^(\w+)\s*-\.->\s*(\w+)$/,                  # Dotted arrow
      /^(\w+)\s*-\.->\|(.+?)\|\s*(\w+)$/        # Labeled dotted
    ]
    
    patterns.each_with_index do |pattern, index|
      if match = line.match(pattern)
        return {
          source: match[1],
          target: match[-1],
          label: match.length > 3 ? match[2] : nil,
          type: detect_edge_type_from_pattern(index)
        }
      end
    end
    
    nil
  end
  
  def detect_shape_from_pattern(pattern)
    case pattern.source
    when /\(\(/
      'circle'
    when /\{/
      'diamond'
    when /\[\[/
      'subroutine'
    when /\[\//
      'trapezoid'
    else
      'rectangle'
    end
  end
  
  def detect_edge_type_from_pattern(pattern_index)
    case pattern_index
    when 2
      'parallel'
    when 3, 4
      'dotted'
    else
      'sequential'
    end
  end
  
  def create_node_from_match(match, position_index)
    node_type = determine_node_type(match[:label], match[:shape])
    
    {
      'id' => match[:id],
      'type' => node_type,
      'data' => {
        'title' => match[:label]
      },
      'position' => {
        'x' => 100 + (position_index % 3) * 200,
        'y' => 100 + (position_index / 3).floor * 150
      }
    }
  end
  
  def determine_node_type(label, shape)
    label_lower = label.downcase
    
    return 'start' if label_lower == 'start' || shape == 'circle' && label_lower.include?('start')
    return 'end' if label_lower == 'end' || shape == 'circle' && label_lower.include?('end')
    return 'decision' if shape == 'diamond'
    
    'task'
  end
  
  def create_edge_from_match(match)
    {
      'id' => "#{match[:source]}-#{match[:target]}",
      'source' => match[:source],
      'target' => match[:target],
      'type' => match[:type] || 'sequential',
      'data' => match[:label] ? { 'label' => match[:label] } : {}
    }
  end
  
  def apply_auto_layout(nodes, edges)
    # Simple auto-layout algorithm
    # This is a basic implementation - could be enhanced with dagre
    levels = calculate_node_levels(nodes, edges)
    
    levels.each do |level, level_nodes|
      level_nodes.each_with_index do |node, index|
        node['position'] = {
          'x' => 150 + index * 200,
          'y' => 100 + level * 150
        }
      end
    end
  end
  
  def calculate_node_levels(nodes, edges)
    adjacency = edges.group_by { |e| e['source'] }
    node_map = nodes.index_by { |n| n['id'] }
    levels = Hash.new { |h, k| h[k] = [] }
    visited = Set.new
    
    # Start with nodes that have no incoming edges
    start_nodes = find_root_nodes(nodes, edges)
    
    start_nodes.each do |node|
      assign_levels(node, 0, adjacency, node_map, levels, visited)
    end
    
    levels
  end
  
  def find_root_nodes(nodes, edges)
    target_nodes = edges.map { |e| e['target'] }.to_set
    nodes.reject { |n| target_nodes.include?(n['id']) }
  end
  
  def assign_levels(node, level, adjacency, node_map, levels, visited)
    return if visited.include?(node['id'])
    
    visited.add(node['id'])
    levels[level] << node
    
    # Process children
    children = adjacency[node['id']] || []
    children.each do |edge|
      child_node = node_map[edge['target']]
      assign_levels(child_node, level + 1, adjacency, node_map, levels, visited) if child_node
    end
  end
  
  def valid_node_or_edge?(line)
    parse_node_definition(line) || parse_edge_definition(line)
  end
end