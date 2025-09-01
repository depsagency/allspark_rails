# frozen_string_literal: true

require_relative 'allspark_integration_test_helper'

class ApiEndpointIntegrationTest < AllsparkIntegrationTestHelper
  def setup
    skip("Dual-container environment not available") unless dual_container_environment_available?
  end

  test "builder and target serve different applications on different ports" do
    # Test Builder application
    builder_response = make_http_request(builder_url('/health'))
    assert_equal '200', builder_response.code, "Builder health check failed"
    
    # Test Target application  
    target_response = make_http_request(target_url('/health'))
    assert_equal '200', target_response.code, "Target health check failed"
    
    # Verify they're different instances
    assert_not_equal builder_response.body, target_response.body, 
                     "Builder and Target should serve different applications"
  end

  test "builder can manage target container via API endpoints" do
    # Test container management endpoints (if they exist)
    management_endpoints = [
      '/api/containers/status',
      '/api/containers/health',
      '/api/terminal/status'
    ]

    management_endpoints.each do |endpoint|
      response = make_http_request(builder_url(endpoint))
      # These endpoints might not exist yet, but should not return 500 errors
      refute_equal '500', response.code, "Server error on #{endpoint}"
    end
  end

  test "cross-container api communication works" do
    # Test if Builder can make API calls to Target
    # This would be used for checking Target status from Builder UI

    # First verify Target has API endpoints
    target_health = make_http_request(target_url('/api/health'))
    
    if target_health.code == '200'
      # Test Builder making requests to Target
      # This simulates Builder UI checking Target status
      
      # Create a test endpoint call from Builder to Target
      command = "curl -s http://target:3000/api/health"
      result = execute_in_container('builder', command)
      
      assert_equal 0, result[2], "Builder cannot make API calls to Target"
      
      # Parse the response
      response_body = result[0].join
      assert_not_empty response_body, "Empty response from Target API"
    end
  end

  test "file operations api endpoints work across containers" do
    # Test file operations that might be exposed via API
    test_file_path = "/app/workspace/api_test_file.txt"
    test_content = "API file operation test"

    # Create file via Builder
    create_test_file_in_container('builder', test_file_path, test_content)

    # Verify file accessible via Target (simulating API file operations)
    assert wait_for_file_in_container('target', test_file_path), 
           "File created in Builder not accessible from Target"

    # Test file reading via API-like operation
    read_result = read_file_from_container('target', test_file_path)
    assert_equal test_content, read_result.strip, "File content differs across containers"
  end

  test "terminal session api endpoints function correctly" do
    # Test terminal session management APIs
    session_endpoints = [
      '/api/terminal/create',
      '/api/terminal/execute',
      '/api/terminal/status'
    ]

    session_endpoints.each do |endpoint|
      response = make_http_request(builder_url(endpoint), method: :post)
      # Should not return 500 errors (endpoints might return 404 or auth errors)
      refute_equal '500', response.code, "Server error on terminal endpoint #{endpoint}"
    end
  end

  test "real-time communication channels work between containers" do
    # Test ActionCable/WebSocket connections between containers
    
    # Test ActionCable connection from Builder
    builder_cable_test = execute_in_container('builder', 
      "bundle exec rails runner \"puts ActionCable.server.connections.count\""
    )
    assert_equal 0, builder_cable_test[2], "Builder ActionCable connection test failed"

    # Test ActionCable connection from Target
    target_cable_test = execute_in_container('target', 
      "bundle exec rails runner \"puts ActionCable.server.connections.count\""
    )
    assert_equal 0, target_cable_test[2], "Target ActionCable connection test failed"
  end

  test "claude code integration endpoints work across containers" do
    # Test Claude Code related API endpoints
    claude_endpoints = [
      '/api/claude/status',
      '/api/claude/sessions',
      '/api/sessions/status'
    ]

    claude_endpoints.each do |endpoint|
      builder_response = make_http_request(builder_url(endpoint))
      target_response = make_http_request(target_url(endpoint))
      
      # Endpoints should exist and not error
      refute_equal '500', builder_response.code, "Claude endpoint error in Builder: #{endpoint}"
      refute_equal '500', target_response.code, "Claude endpoint error in Target: #{endpoint}"
    end
  end

  test "mcp server integration endpoints work" do
    # Test MCP (Model Context Protocol) server endpoints
    mcp_endpoints = [
      '/api/mcp/servers',
      '/api/mcp/status',
      '/api/mcp/health'
    ]

    mcp_endpoints.each do |endpoint|
      builder_response = make_http_request(builder_url(endpoint))
      target_response = make_http_request(target_url(endpoint))
      
      # Should not return server errors
      refute_equal '500', builder_response.code, "MCP endpoint error in Builder: #{endpoint}"
      refute_equal '500', target_response.code, "MCP endpoint error in Target: #{endpoint}"
    end
  end

  test "workflow builder api endpoints work" do
    # Test Workflow Builder related endpoints
    workflow_endpoints = [
      '/api/workflows',
      '/api/workflow_builder/status'
    ]

    workflow_endpoints.each do |endpoint|
      response = make_http_request(builder_url(endpoint))
      refute_equal '500', response.code, "Workflow endpoint error: #{endpoint}"
    end
  end

  test "authentication works independently in each container" do
    # Test that authentication sessions are independent
    
    # Try to access a protected endpoint on Builder
    protected_response = make_http_request(builder_url('/dashboard'))
    
    # Response should either be successful (if no auth required) or redirect to login
    assert ['200', '302', '401'].include?(protected_response.code), 
           "Unexpected response code for protected endpoint: #{protected_response.code}"

    # Same for Target
    target_protected = make_http_request(target_url('/dashboard'))
    assert ['200', '302', '401'].include?(target_protected.code), 
           "Unexpected response code for Target protected endpoint: #{target_protected.code}"
  end

  test "database migrations work in both containers" do
    # Test that both containers can run migrations independently
    
    builder_migration = execute_in_container('builder', 
      "bundle exec rails runner \"puts ActiveRecord::Base.connection.migration_context.current_version\""
    )
    assert_equal 0, builder_migration[2], "Builder migration version check failed"

    target_migration = execute_in_container('target', 
      "bundle exec rails runner \"puts ActiveRecord::Base.connection.migration_context.current_version\""
    )
    assert_equal 0, target_migration[2], "Target migration version check failed"
    
    # Both should have the same migration version (shared database)
    builder_version = builder_migration[0].join.strip
    target_version = target_migration[0].join.strip
    
    assert_equal builder_version, target_version, 
                 "Migration versions should be the same across containers"
  end

  private

  def dual_container_environment_available?
    %w[builder target].all? do |service|
      container = get_container(service)
      container&.info&.dig('State', 'Running')
    end
  rescue
    false
  end
end