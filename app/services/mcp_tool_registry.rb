class McpToolRegistry
  include Singleton

  CACHE_PREFIX = "mcp_tool_registry"
  CACHE_EXPIRY = 1.hour
  MAX_TOOLS_PER_SERVER = 100
  MAX_TOTAL_TOOLS = 1000

  def initialize
    @mutex = Mutex.new
    @usage_stats = Concurrent::Map.new
    @conflict_resolution = :latest_wins # :latest_wins, :first_wins, :manual
  end

  # Register tools from a server
  def register_server_tools(server_id, tools)
    @mutex.synchronize do
      validate_tools_input(tools)
      
      server_tools = process_server_tools(server_id, tools)
      
      # Store server tools
      cache_key = "#{CACHE_PREFIX}_server_#{server_id}"
      Rails.cache.write(cache_key, server_tools, expires_in: CACHE_EXPIRY)
      
      # Update global registry
      update_global_registry(server_id, server_tools)
      
      # Handle conflicts
      resolve_tool_conflicts
      
      Rails.logger.info "[MCP Registry] Registered #{server_tools.size} tools for server #{server_id}"
      
      server_tools
    end
  end

  # Register tools from a configuration
  def register_configuration_tools(configuration_id, tools)
    @mutex.synchronize do
      validate_tools_input(tools)
      
      config_tools = process_configuration_tools(configuration_id, tools)
      
      # Store configuration tools
      cache_key = "#{CACHE_PREFIX}_configuration_#{configuration_id}"
      Rails.cache.write(cache_key, config_tools, expires_in: CACHE_EXPIRY)
      
      # Update global registry
      update_global_configuration_registry(configuration_id, config_tools)
      
      # Handle conflicts
      resolve_tool_conflicts
      
      Rails.logger.info "[MCP Registry] Registered #{config_tools.size} tools for configuration #{configuration_id}"
      
      config_tools
    end
  end

  # Get all tools from a specific server
  def get_server_tools(server_id)
    cache_key = "#{CACHE_PREFIX}_server_#{server_id}"
    Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRY) { [] }
  end

  # Get all tools from a specific configuration
  def get_configuration_tools(configuration_id)
    cache_key = "#{CACHE_PREFIX}_configuration_#{configuration_id}"
    Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRY) { [] }
  end

  # Get all available tools across all servers
  def get_all_tools(user: nil, instance: nil)
    @mutex.synchronize do
      tools = []
      
      # Get tools from all accessible servers
      servers = get_accessible_servers(user, instance)
      
      servers.each do |server|
        server_tools = get_server_tools(server.id)
        tools.concat(server_tools)
      end
      
      # Remove duplicates and resolve conflicts
      deduplicated_tools = deduplicate_tools(tools)
      
      Rails.logger.debug "[MCP Registry] Retrieved #{deduplicated_tools.size} total tools for user/instance"
      
      deduplicated_tools
    end
  end

  # Find a specific tool by name
  def find_tool(tool_name, user: nil, instance: nil)
    tools = get_all_tools(user: user, instance: instance)
    tools.find { |tool| tool['name'] == tool_name }
  end

  # Search tools by various criteria
  def search_tools(query = nil, category: nil, server_id: nil, user: nil, instance: nil)
    tools = if server_id
      get_server_tools(server_id)
    else
      get_all_tools(user: user, instance: instance)
    end
    
    # Apply search filters
    filtered_tools = apply_search_filters(tools, query, category)
    
    # Sort by relevance and usage
    sort_tools_by_relevance(filtered_tools, query)
  end

  # Get tool usage statistics
  def get_tool_usage_stats(tool_name = nil, time_window = 24.hours)
    if tool_name
      get_single_tool_stats(tool_name, time_window)
    else
      get_all_tools_stats(time_window)
    end
  end

  # Track tool usage
  def track_tool_usage(tool_name, server_id, user_id: nil, success: true)
    @usage_stats["#{tool_name}_#{server_id}"] ||= []
    @usage_stats["#{tool_name}_#{server_id}"] << {
      timestamp: Time.current,
      user_id: user_id,
      success: success
    }
    
    # Keep only recent usage data
    cutoff = Time.current - 7.days
    @usage_stats["#{tool_name}_#{server_id}"].reject! { |stat| stat[:timestamp] < cutoff }
    
    # Update cache
    update_usage_cache(tool_name, server_id)
  end

  # Get tool categories
  def get_tool_categories(user: nil, instance: nil)
    tools = get_all_tools(user: user, instance: instance)
    
    categories = {}
    
    tools.each do |tool|
      category = categorize_tool(tool)
      categories[category] ||= 0
      categories[category] += 1
    end
    
    categories.sort_by { |_, count| -count }.to_h
  end

  # Check for tool conflicts
  def get_tool_conflicts
    @mutex.synchronize do
      conflicts = {}
      all_servers_tools = get_all_servers_tools
      
      # Group tools by name
      tools_by_name = {}
      all_servers_tools.each do |server_id, tools|
        tools.each do |tool|
          tools_by_name[tool['name']] ||= []
          tools_by_name[tool['name']] << { tool: tool, server_id: server_id }
        end
      end
      
      # Find conflicts (same name, different servers)
      tools_by_name.each do |tool_name, tool_entries|
        next if tool_entries.size <= 1
        
        # Check if tools are actually different
        unique_definitions = tool_entries.map { |entry| tool_definition_signature(entry[:tool]) }.uniq
        
        if unique_definitions.size > 1
          conflicts[tool_name] = tool_entries
        end
      end
      
      conflicts
    end
  end

  # Validate tool availability
  def validate_tool_availability(tool_name, user: nil, instance: nil)
    tool = find_tool(tool_name, user: user, instance: instance)
    
    return { available: false, reason: 'Tool not found' } unless tool
    
    # Check server status
    server_id = tool['_server_id']
    server = McpServer.find_by(id: server_id)
    
    return { available: false, reason: 'Server not found' } unless server
    return { available: false, reason: 'Server inactive' } unless server.active?
    
    # Check access permissions
    unless has_access_to_server?(server, user, instance)
      return { available: false, reason: 'Access denied' }
    end
    
    # Check if tool is still available on server (recent discovery)
    last_discovery = tool['_discovered_at']
    if last_discovery && Time.parse(last_discovery) < 10.minutes.ago
      return { available: true, reason: 'Available (discovery might be stale)' }
    end
    
    { available: true, reason: 'Available' }
  end

  # Clear registry data
  def clear_server_tools(server_id)
    @mutex.synchronize do
      cache_key = "#{CACHE_PREFIX}_server_#{server_id}"
      Rails.cache.delete(cache_key)
      
      # Clear from global registry
      global_cache_key = "#{CACHE_PREFIX}_global"
      Rails.cache.delete(global_cache_key)
      
      Rails.logger.info "[MCP Registry] Cleared tools for server #{server_id}"
    end
  end

  def clear_all_tools
    @mutex.synchronize do
      # Clear all server caches
      McpServer.pluck(:id).each do |server_id|
        clear_server_tools(server_id)
      end
      
      # Clear usage stats
      @usage_stats.clear
      
      Rails.logger.info "[MCP Registry] Cleared all registry data"
    end
  end

  private

  def validate_tools_input(tools)
    raise ArgumentError, "Tools must be an array" unless tools.is_a?(Array)
    raise ArgumentError, "Too many tools (max #{MAX_TOOLS_PER_SERVER})" if tools.size > MAX_TOOLS_PER_SERVER
  end

  def process_server_tools(server_id, tools)
    processed = []
    
    tools.each_with_index do |tool, index|
      # Add processing metadata
      processed_tool = tool.dup
      processed_tool['_registry_id'] = "#{server_id}_#{tool['name']}_#{index}"
      processed_tool['_processed_at'] = Time.current.iso8601
      processed_tool['_position'] = index
      
      processed << processed_tool
    end
    
    processed
  end

  def update_global_registry(server_id, server_tools)
    global_cache_key = "#{CACHE_PREFIX}_global"
    all_tools = Rails.cache.read(global_cache_key) || {}
    
    all_tools[server_id.to_s] = server_tools
    
    # Enforce total tool limit
    total_tools = all_tools.values.flatten.size
    if total_tools > MAX_TOTAL_TOOLS
      Rails.logger.warn "[MCP Registry] Tool limit exceeded (#{total_tools}/#{MAX_TOTAL_TOOLS})"
      # Remove oldest tools from least active servers
      prune_excess_tools(all_tools)
    end
    
    Rails.cache.write(global_cache_key, all_tools, expires_in: CACHE_EXPIRY)
  end

  def get_accessible_servers(user, instance)
    if user && instance
      McpServer.available_to_user(user).active
    elsif user
      McpServer.available_to_user(user).active
    elsif instance
      McpServer.available_to_instance(instance).active
    else
      McpServer.system_wide.active
    end
  end

  def deduplicate_tools(tools)
    # Group by tool name
    tools_by_name = tools.group_by { |tool| tool['name'] }
    
    deduplicated = []
    
    tools_by_name.each do |tool_name, tool_variants|
      if tool_variants.size == 1
        deduplicated << tool_variants.first
      else
        # Resolve conflict
        resolved_tool = resolve_tool_conflict(tool_variants)
        deduplicated << resolved_tool
      end
    end
    
    deduplicated
  end

  def resolve_tool_conflict(tool_variants)
    case @conflict_resolution
    when :latest_wins
      # Choose the most recently discovered tool
      tool_variants.max_by { |tool| Time.parse(tool['_discovered_at'] || '1970-01-01') }
    when :first_wins
      # Choose the first registered tool
      tool_variants.min_by { |tool| tool['_position'] || 0 }
    else
      # Default to latest wins
      tool_variants.max_by { |tool| Time.parse(tool['_discovered_at'] || '1970-01-01') }
    end
  end

  def resolve_tool_conflicts
    conflicts = get_tool_conflicts
    
    conflicts.each do |tool_name, conflicting_tools|
      Rails.logger.warn "[MCP Registry] Tool conflict detected for '#{tool_name}': #{conflicting_tools.size} variants"
      
      # Log conflict details
      conflicting_tools.each do |entry|
        server_name = McpServer.find_by(id: entry[:server_id])&.name || "Unknown"
        Rails.logger.debug "[MCP Registry] - #{tool_name} from #{server_name} (#{entry[:server_id]})"
      end
    end
  end

  def apply_search_filters(tools, query, category)
    filtered = tools
    
    # Text search
    if query.present?
      query_downcase = query.downcase
      filtered = filtered.select do |tool|
        tool['name'].downcase.include?(query_downcase) ||
        tool['description'].downcase.include?(query_downcase)
      end
    end
    
    # Category filter
    if category.present?
      filtered = filtered.select { |tool| categorize_tool(tool) == category }
    end
    
    filtered
  end

  def sort_tools_by_relevance(tools, query)
    if query.present?
      query_downcase = query.downcase
      
      tools.sort_by do |tool|
        score = 0
        
        # Exact name match gets highest score
        score += 1000 if tool['name'].downcase == query_downcase
        
        # Name starts with query gets high score
        score += 500 if tool['name'].downcase.start_with?(query_downcase)
        
        # Name contains query gets medium score
        score += 100 if tool['name'].downcase.include?(query_downcase)
        
        # Description contains query gets low score
        score += 10 if tool['description'].downcase.include?(query_downcase)
        
        # Factor in usage stats
        usage_stats = get_tool_usage_stats(tool['name'])
        score += (usage_stats[:usage_count] || 0) * 5
        
        -score # Negative for descending sort
      end
    else
      # Sort by usage when no query
      tools.sort_by do |tool|
        usage_stats = get_tool_usage_stats(tool['name'])
        -(usage_stats[:usage_count] || 0)
      end
    end
  end

  def categorize_tool(tool)
    name = tool['name'].downcase
    description = tool['description'].downcase
    
    return 'Search' if name.include?('search') || description.include?('search')
    return 'Create' if name.include?('create') || description.include?('create')
    return 'Update' if name.include?('update') || description.include?('update')
    return 'Delete' if name.include?('delete') || description.include?('delete')
    return 'Linear' if name.include?('linear') || description.include?('linear')
    return 'Figma' if name.include?('figma') || description.include?('figma')
    return 'Sentry' if name.include?('sentry') || description.include?('sentry')
    return 'API' if description.include?('api')
    return 'Data' if description.include?('data')
    
    'Other'
  end

  def get_single_tool_stats(tool_name, time_window)
    cutoff = Time.current - time_window
    
    all_usage = @usage_stats.values.flatten.select do |stat|
      stat[:timestamp] >= cutoff
    end
    
    tool_usage = all_usage.select { |stat| stat[:tool_name] == tool_name }
    
    {
      usage_count: tool_usage.size,
      success_count: tool_usage.count { |stat| stat[:success] },
      failure_count: tool_usage.count { |stat| !stat[:success] },
      unique_users: tool_usage.map { |stat| stat[:user_id] }.compact.uniq.size,
      last_used: tool_usage.map { |stat| stat[:timestamp] }.max
    }
  end

  def get_all_tools_stats(time_window)
    cutoff = Time.current - time_window
    
    all_usage = @usage_stats.values.flatten.select do |stat|
      stat[:timestamp] >= cutoff
    end
    
    {
      total_usage: all_usage.size,
      total_successes: all_usage.count { |stat| stat[:success] },
      total_failures: all_usage.count { |stat| !stat[:success] },
      unique_users: all_usage.map { |stat| stat[:user_id] }.compact.uniq.size,
      active_tools: @usage_stats.keys.size
    }
  end

  def update_usage_cache(tool_name, server_id)
    cache_key = "#{CACHE_PREFIX}_usage_#{tool_name}_#{server_id}"
    current_stats = @usage_stats["#{tool_name}_#{server_id}"] || []
    
    Rails.cache.write(cache_key, current_stats, expires_in: 1.hour)
  end

  def has_access_to_server?(server, user, instance)
    return true if server.user_id.nil? && server.instance_id.nil? # System-wide
    return true if server.user_id == user&.id
    return true if server.instance_id == instance&.id && user&.instances&.include?(instance)
    
    false
  end

  def get_all_servers_tools
    global_cache_key = "#{CACHE_PREFIX}_global"
    Rails.cache.read(global_cache_key) || {}
  end

  def tool_definition_signature(tool)
    # Create a signature for comparing tool definitions
    [
      tool['name'],
      tool['description'],
      tool['inputSchema']&.dig('properties')&.keys&.sort,
      tool['outputSchema']&.dig('properties')&.keys&.sort
    ].to_s
  end

  def prune_excess_tools(all_tools)
    # Simple pruning: remove tools from servers with least recent activity
    # In a production system, this could be more sophisticated
    
    server_activity = {}
    all_tools.each do |server_id, tools|
      last_discovery = tools.map { |t| Time.parse(t['_discovered_at'] || '1970-01-01') }.max
      server_activity[server_id] = last_discovery
    end
    
    # Remove tools from least active server
    least_active_server = server_activity.min_by { |_, last_activity| last_activity }&.first
    if least_active_server
      all_tools.delete(least_active_server)
      Rails.logger.warn "[MCP Registry] Pruned tools from server #{least_active_server} due to tool limit"
    end
  end

  def process_configuration_tools(configuration_id, tools)
    processed = []
    
    tools.each_with_index do |tool, index|
      # Add processing metadata
      processed_tool = tool.dup
      processed_tool['_registry_id'] = "config_#{configuration_id}_#{tool['name']}_#{index}"
      processed_tool['_processed_at'] = Time.current.iso8601
      processed_tool['_position'] = index
      
      processed << processed_tool
    end
    
    processed
  end

  def update_global_configuration_registry(configuration_id, config_tools)
    global_cache_key = "#{CACHE_PREFIX}_global_configurations"
    all_tools = Rails.cache.read(global_cache_key) || {}
    
    all_tools[configuration_id.to_s] = config_tools
    
    # Enforce total tool limit
    total_tools = all_tools.values.flatten.size
    if total_tools > MAX_TOTAL_TOOLS
      Rails.logger.warn "[MCP Registry] Configuration tool limit exceeded (#{total_tools}/#{MAX_TOTAL_TOOLS})"
      # Remove oldest tools from least active configurations
      prune_excess_configuration_tools(all_tools)
    end
    
    Rails.cache.write(global_cache_key, all_tools, expires_in: CACHE_EXPIRY)
  end

  def prune_excess_configuration_tools(all_tools)
    # Simple pruning: remove tools from configurations with least recent activity
    config_activity = {}
    all_tools.each do |config_id, tools|
      last_discovery = tools.map { |t| Time.parse(t['_discovered_at'] || '1970-01-01') }.max
      config_activity[config_id] = last_discovery
    end
    
    # Remove tools from least active configuration
    least_active_config = config_activity.min_by { |_, last_activity| last_activity }&.first
    if least_active_config
      all_tools.delete(least_active_config)
      Rails.logger.warn "[MCP Registry] Pruned tools from configuration #{least_active_config} due to tool limit"
    end
  end
end