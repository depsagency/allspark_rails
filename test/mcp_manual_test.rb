#!/usr/bin/env ruby
# frozen_string_literal: true

# Manual test script to verify MCP functionality
# Run this in the Rails console or as a script

puts "=== MCP FUNCTIONALITY TEST ==="
puts "Testing MCP models, services, and basic functionality"
puts

# Test 1: Model Creation
puts "1. Testing McpServer model creation..."
begin
  server = McpServer.new(
    name: "Test Server",
    endpoint: "https://test.example.com/mcp/v1",
    auth_type: :api_key,
    config: { timeout: 30000 },
    credentials: { api_key: "test-key-123", header_name: "Authorization" }
  )
  
  if server.valid?
    puts "✅ McpServer validation passed"
  else
    puts "❌ McpServer validation failed: #{server.errors.full_messages.join(', ')}"
  end
rescue => e
  puts "❌ McpServer model error: #{e.message}"
end

# Test 2: OAuth Server Creation
puts "\n2. Testing OAuth server creation..."
begin
  oauth_server = McpServer.new(
    name: "OAuth Test Server",
    endpoint: "https://oauth.example.com/mcp/v1",
    auth_type: :oauth,
    config: { timeout: 30000 },
    credentials: {
      client_id: "test-client-id",
      client_secret: "test-client-secret",
      authorization_url: "https://oauth.example.com/oauth/authorize",
      token_url: "https://oauth.example.com/oauth/token",
      scope: "read write"
    }
  )
  
  if oauth_server.valid?
    puts "✅ OAuth McpServer validation passed"
  else
    puts "❌ OAuth McpServer validation failed: #{oauth_server.errors.full_messages.join(', ')}"
  end
rescue => e
  puts "❌ OAuth McpServer model error: #{e.message}"
end

# Test 3: Audit Log Creation
puts "\n3. Testing McpAuditLog creation..."
begin
  audit_log = McpAuditLog.new(
    tool_name: "test_tool",
    status: :successful,
    executed_at: Time.current,
    response_time_ms: 250,
    request_data: { action: "test" },
    response_data: { result: "success" }
  )
  
  if audit_log.valid?
    puts "✅ McpAuditLog validation passed"
  else
    puts "❌ McpAuditLog validation failed: #{audit_log.errors.full_messages.join(', ')}"
  end
rescue => e
  puts "❌ McpAuditLog model error: #{e.message}"
end

# Test 4: Service Classes
puts "\n4. Testing MCP service classes..."

# Test McpConnectionManager
begin
  manager = McpConnectionManager.instance
  puts "✅ McpConnectionManager singleton accessible"
  
  status = manager.pool_status
  puts "✅ Connection pool status: #{status[:total_connections]} total connections"
rescue => e
  puts "❌ McpConnectionManager error: #{e.message}"
end

# Test McpToolRegistry
begin
  registry = McpToolRegistry.instance
  puts "✅ McpToolRegistry singleton accessible"
  
  # Test tool registration
  registry.register_tools(1, [
    { name: "test_tool", description: "Test tool", parameters: {} }
  ])
  tools = registry.get_server_tools(1)
  puts "✅ Tool registration works: #{tools.size} tools for server 1"
rescue => e
  puts "❌ McpToolRegistry error: #{e.message}"
end

# Test 5: Jobs
puts "\n5. Testing MCP background jobs..."

begin
  # Test job classes exist and can be instantiated
  health_job = McpHealthCheckJob.new
  cleanup_job = McpAuditLogCleanupJob.new
  discovery_job = McpToolDiscoveryJob.new
  
  puts "✅ All MCP job classes can be instantiated"
rescue => e
  puts "❌ MCP job error: #{e.message}"
end

# Test 6: Routes and Controllers
puts "\n6. Testing controller classes..."

begin
  controller = Admin::McpServersController.new
  puts "✅ Admin::McpServersController can be instantiated"
rescue => e
  puts "❌ Admin controller error: #{e.message}"
end

# Test 7: Database Tables
puts "\n7. Testing database schema..."

begin
  # Check that tables exist and can be queried
  server_count = McpServer.count
  audit_count = McpAuditLog.count
  
  puts "✅ Database tables accessible:"
  puts "  - mcp_servers: #{server_count} records"
  puts "  - mcp_audit_logs: #{audit_count} records"
rescue => e
  puts "❌ Database error: #{e.message}"
end

# Test 8: Sample Data Creation and Cleanup
puts "\n8. Testing full CRUD operations..."

begin
  # Create a test server
  test_server = McpServer.create!(
    name: "Integration Test Server",
    endpoint: "https://integration.example.com/mcp/v1",
    auth_type: :api_key,
    config: { timeout: 30000 },
    credentials: { api_key: "integration-test-key", header_name: "Authorization" }
  )
  puts "✅ Created test server: #{test_server.name}"
  
  # Create an audit log for the server
  test_audit = test_server.mcp_audit_logs.create!(
    tool_name: "integration_test_tool",
    status: :successful,
    executed_at: Time.current,
    response_time_ms: 150,
    request_data: { test: true },
    response_data: { success: true }
  )
  puts "✅ Created audit log: #{test_audit.tool_name}"
  
  # Update the server
  test_server.update!(name: "Updated Integration Test Server")
  puts "✅ Updated server name"
  
  # Test queries
  recent_logs = McpAuditLog.recent.limit(5).count
  successful_logs = McpAuditLog.successful.count
  puts "✅ Query operations work: #{recent_logs} recent logs, #{successful_logs} successful"
  
  # Cleanup
  test_audit.destroy!
  test_server.destroy!
  puts "✅ Cleanup completed"
  
rescue => e
  puts "❌ CRUD operations error: #{e.message}"
  
  # Attempt cleanup even if there was an error
  begin
    McpServer.where(name: ["Integration Test Server", "Updated Integration Test Server"]).destroy_all
    McpAuditLog.where(tool_name: "integration_test_tool").destroy_all
    puts "⚠️  Emergency cleanup performed"
  rescue cleanup_error
    puts "❌ Cleanup failed: #{cleanup_error.message}"
  end
end

puts "\n=== MCP TEST COMPLETE ==="
puts "All core MCP functionality has been tested."
puts "If you see mostly ✅ marks above, the MCP integration is working correctly."
puts "Any ❌ marks indicate issues that need to be addressed."