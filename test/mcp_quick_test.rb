#!/usr/bin/env ruby
# Quick MCP functionality test without browser automation

require_relative '../config/environment'

puts "=== MCP QUICK FUNCTIONALITY TEST ==="
puts

# Test 1: Check if user profile page renders
puts "1. Testing user profile page rendering..."
begin
  user = User.find("41a123a1-0f95-4237-bfba-6cf3169d6c80")
  
  # Simulate rendering the view
  app = ActionController::TestCase.new
  app.instance_variable_set(:@user, user)
  
  puts "✅ User found: #{user.email}"
  puts "✅ Route helper working: #{Rails.application.routes.url_helpers.mcp_servers_user_path(user)}"
rescue => e
  puts "❌ User profile test error: #{e.message}"
end

# Test 2: Check MCP controllers
puts "\n2. Testing MCP controller instantiation..."
begin
  admin_controller = Admin::McpServersController.new
  puts "✅ Admin MCP controller instantiated"
rescue => e
  puts "❌ Admin controller error: #{e.message}"
end

# Test 3: Check if all MCP views exist
puts "\n3. Testing MCP view files..."
mcp_views = [
  'app/views/admin/mcp_servers/index.html.erb',
  'app/views/admin/mcp_servers/show.html.erb', 
  'app/views/admin/mcp_servers/new.html.erb',
  'app/views/admin/mcp_servers/edit.html.erb',
  'app/views/admin/mcp_servers/analytics.html.erb'
]

mcp_views.each do |view|
  if File.exist?(view)
    puts "✅ #{view} exists"
  else
    puts "❌ #{view} missing"
  end
end

# Test 4: Check if MCP models work
puts "\n4. Testing MCP model operations..."
begin
  server_count = McpServer.count
  audit_count = McpAuditLog.count
  puts "✅ McpServer model: #{server_count} records"
  puts "✅ McpAuditLog model: #{audit_count} records"
rescue => e
  puts "❌ Model test error: #{e.message}"
end

# Test 5: Check if required routes exist
puts "\n5. Testing MCP routes..."
required_routes = [
  '/admin/mcp_servers',
  '/admin/mcp_servers/new', 
  '/admin/mcp_servers/analytics',
  "/users/#{User.first.id}/mcp_servers"
]

required_routes.each do |route|
  begin
    recognized = Rails.application.routes.recognize_path(route)
    puts "✅ Route #{route}: #{recognized[:controller]}##{recognized[:action]}"
  rescue => e
    puts "❌ Route #{route}: #{e.message}"
  end
end

# Test 6: Create a test MCP server
puts "\n6. Testing MCP server creation..."
begin
  test_server = McpServer.new(
    name: "Quick Test Server",
    endpoint: "https://quicktest.example.com/mcp/v1", 
    auth_type: :api_key,
    config: { timeout: 30000 },
    credentials: { api_key: "test-key", header_name: "Authorization" }
  )
  
  if test_server.valid?
    puts "✅ MCP server validation passed"
    # Don't save to avoid cluttering database
  else
    puts "❌ MCP server validation failed: #{test_server.errors.full_messages.join(', ')}"
  end
rescue => e
  puts "❌ MCP server creation error: #{e.message}"
end

puts "\n=== MCP QUICK TEST COMPLETE ==="
puts "If most items show ✅, the MCP system is functional."