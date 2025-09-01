# Seed MCP Templates
puts "Seeding MCP Templates..."

# Clear existing templates in development
if Rails.env.development?
  McpTemplate.destroy_all
end

# Seed templates from the TEMPLATES constant
McpTemplate.seed_templates!

puts "Created #{McpTemplate.count} MCP templates:"
McpTemplate.find_each do |template|
  puts "  - #{template.name} (#{template.key}) - #{template.category}"
end

# Create some example configurations for development
if Rails.env.development? && User.any?
  puts "\nCreating example MCP configurations for development..."
  
  user = User.first
  
  # Add filesystem MCP for development
  if !user.has_mcp_configuration?("File System (Dev)")
    fs_template = McpTemplate.find_by(key: 'filesystem')
    config = fs_template.instantiate_configuration(
      name: "File System (Dev)",
      allowed_directories: Rails.root.to_s
    )
    config.owner = user
    config.save!
    puts "  - Created File System configuration for #{user.email}"
  end
  
  # Add a custom HTTP example
  if !user.has_mcp_configuration?("Example HTTP MCP")
    http_template = McpTemplate.find_by(key: 'http_server')
    config = http_template.instantiate_configuration(
      name: "Example HTTP MCP",
      server_url: "http://localhost:8080/mcp",
      api_token: "dev-token-123"
    )
    config.owner = user
    config.enabled = false # Disabled by default
    config.save!
    puts "  - Created Example HTTP MCP configuration for #{user.email}"
  end
end

puts "\nMCP Templates seeding completed!"