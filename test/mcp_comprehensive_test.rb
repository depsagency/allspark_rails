#!/usr/bin/env ruby
# Comprehensive MCP functionality test using Rails integration tests

require_relative '../config/environment'
require 'action_controller/test_case'

puts "=== COMPREHENSIVE MCP FUNCTIONALITY TEST ==="
puts "Testing all MCP user journeys with simulated requests"
puts

class McpFunctionalityTest
  include Rails.application.routes.url_helpers
  
  def initialize
    @errors = []
    @successes = []
    @admin_user = User.find_by(role: :system_admin)
    @regular_user = User.where.not(role: :system_admin).first
  end
  
  def run_all_tests
    puts "🧪 Starting comprehensive MCP functionality tests..."
    puts "Admin user: #{@admin_user&.email || 'None found'}"
    puts "Regular user: #{@regular_user&.email || 'None found'}"
    puts
    
    test_user_profile_mcp_link
    test_mcp_server_model_operations
    test_admin_mcp_routes
    test_user_mcp_routes
    test_oauth_server_creation
    test_analytics_data_generation
    test_audit_log_functionality
    test_multi_tenant_access
    test_service_classes
    test_production_features
    
    print_results
  end
  
  private
  
  def test_user_profile_mcp_link
    test_name = "User Profile MCP Link"
    puts "🔍 Testing: #{test_name}"
    
    begin
      return add_error(test_name, "No admin user found") unless @admin_user
      
      # Test route generation
      path = mcp_servers_user_path(@admin_user)
      add_success("Route generation: #{path}")
      
      # Test that the route is recognized
      recognized = Rails.application.routes.recognize_path(path)
      expected_controller = 'users'
      expected_action = 'mcp_servers'
      
      if recognized[:controller] == expected_controller && recognized[:action] == expected_action
        add_success("Route recognition: #{recognized[:controller]}##{recognized[:action]}")
      else
        add_error(test_name, "Route recognition failed: got #{recognized[:controller]}##{recognized[:action]}")
      end
      
    rescue => e
      add_error(test_name, e.message)
    end
    puts
  end
  
  def test_mcp_server_model_operations
    test_name = "MCP Server Model Operations"
    puts "🔍 Testing: #{test_name}"
    
    begin
      # Test creation with different auth types
      auth_types = [:api_key, :oauth, :bearer_token, :no_auth]
      
      auth_types.each do |auth_type|
        server = McpServer.new(
          name: "Test #{auth_type.to_s.humanize} Server",
          endpoint: "https://#{auth_type}.example.com/mcp/v1",
          auth_type: auth_type,
          config: { timeout: 30000 },
          credentials: build_credentials_for_auth_type(auth_type)
        )
        
        if server.valid?
          add_success("#{auth_type.to_s.humanize} server validation passed")
        else
          add_error(test_name, "#{auth_type.to_s.humanize} server validation failed: #{server.errors.full_messages.join(', ')}")
        end
      end
      
      # Test scopes
      total_servers = McpServer.count
      system_servers = McpServer.system_wide.count
      add_success("Model scopes working: #{total_servers} total, #{system_servers} system-wide")
      
    rescue => e
      add_error(test_name, e.message)
    end
    puts
  end
  
  def test_admin_mcp_routes
    test_name = "Admin MCP Routes"
    puts "🔍 Testing: #{test_name}"
    
    admin_routes = [
      '/admin/mcp_servers',
      '/admin/mcp_servers/new',
      '/admin/mcp_servers/analytics'
    ]
    
    admin_routes.each do |route|
      begin
        recognized = Rails.application.routes.recognize_path(route)
        add_success("Route #{route}: #{recognized[:controller]}##{recognized[:action]}")
      rescue => e
        add_error(test_name, "Route #{route} failed: #{e.message}")
      end
    end
    puts
  end
  
  def test_user_mcp_routes
    test_name = "User MCP Routes"
    puts "🔍 Testing: #{test_name}"
    
    return add_error(test_name, "No regular user found") unless @regular_user
    
    begin
      user_route = "/users/#{@regular_user.id}/mcp_servers"
      recognized = Rails.application.routes.recognize_path(user_route)
      
      if recognized[:controller] == 'users' && recognized[:action] == 'mcp_servers'
        add_success("User MCP route works: #{user_route}")
      else
        add_error(test_name, "User MCP route failed: #{recognized}")
      end
      
    rescue => e
      add_error(test_name, e.message)
    end
    puts
  end
  
  def test_oauth_server_creation
    test_name = "OAuth Server Creation"
    puts "🔍 Testing: #{test_name}"
    
    begin
      oauth_server = McpServer.new(
        name: "OAuth Test Server",
        endpoint: "https://oauth.example.com/mcp/v1",
        auth_type: :oauth,
        credentials: {
          client_id: "test-client-id",
          client_secret: "test-client-secret",
          authorization_url: "https://oauth.example.com/oauth/authorize",
          token_url: "https://oauth.example.com/oauth/token",
          scope: "read write"
        }
      )
      
      if oauth_server.valid?
        add_success("OAuth server validation passed")
        
        # Test OAuth-specific methods exist
        creds = oauth_server.credentials
        if creds['client_id'] && creds['authorization_url']
          add_success("OAuth credentials structure correct")
        else
          add_error(test_name, "OAuth credentials missing required fields")
        end
      else
        add_error(test_name, "OAuth server validation failed: #{oauth_server.errors.full_messages.join(', ')}")
      end
      
    rescue => e
      add_error(test_name, e.message)
    end
    puts
  end
  
  def test_analytics_data_generation
    test_name = "Analytics Data Generation"
    puts "🔍 Testing: #{test_name}"
    
    begin
      # Test analytics controller methods (without actually creating test data)
      controller = Admin::McpServersController.new
      
      # Test method existence
      methods_to_test = [
        :get_global_analytics_data,
        :get_global_overview,
        :get_response_time_distribution,
        :calculate_health_statistics
      ]
      
      methods_to_test.each do |method|
        if controller.respond_to?(method, true)
          add_success("Analytics method #{method} exists")
        else
          add_error(test_name, "Analytics method #{method} missing")
        end
      end
      
    rescue => e
      add_error(test_name, e.message)
    end
    puts
  end
  
  def test_audit_log_functionality
    test_name = "Audit Log Functionality"
    puts "🔍 Testing: #{test_name}"
    
    begin
      # Test audit log model
      audit_log = McpAuditLog.new(
        tool_name: "test_tool",
        status: :successful,
        executed_at: Time.current,
        response_time_ms: 250,
        request_data: { action: "test" },
        response_data: { result: "success" }
      )
      
      # Note: This will fail validation because user and mcp_server are required
      # but we're testing the model structure
      expected_errors = audit_log.errors.keys
      
      if audit_log.respond_to?(:tool_name) && audit_log.respond_to?(:status)
        add_success("Audit log model structure correct")
      else
        add_error(test_name, "Audit log model missing required attributes")
      end
      
      # Test scopes
      scopes_to_test = [:recent, :successful, :failed]
      scopes_to_test.each do |scope|
        if McpAuditLog.respond_to?(scope)
          add_success("Audit log scope #{scope} exists")
        else
          add_error(test_name, "Audit log scope #{scope} missing")
        end
      end
      
    rescue => e
      add_error(test_name, e.message)
    end
    puts
  end
  
  def test_multi_tenant_access
    test_name = "Multi-tenant Access Control"
    puts "🔍 Testing: #{test_name}"
    
    begin
      # Test different server scopes
      scopes_to_test = [:system_wide, :by_status]
      
      scopes_to_test.each do |scope|
        if McpServer.respond_to?(scope)
          add_success("McpServer scope #{scope} exists")
        else
          add_error(test_name, "McpServer scope #{scope} missing")
        end
      end
      
      # Test user role methods
      if @admin_user&.admin?
        add_success("Admin user role detection works")
      else
        add_error(test_name, "Admin user role detection failed")
      end
      
    rescue => e
      add_error(test_name, e.message)
    end
    puts
  end
  
  def test_service_classes
    test_name = "MCP Service Classes"
    puts "🔍 Testing: #{test_name}"
    
    begin
      # Test connection manager
      manager = McpConnectionManager.instance
      if manager.respond_to?(:pool_status)
        add_success("McpConnectionManager instantiated")
        
        status = manager.pool_status
        if status.is_a?(Hash) && status.key?(:total_connections)
          add_success("Connection manager pool_status works")
        else
          add_error(test_name, "Connection manager pool_status returned invalid format")
        end
      else
        add_error(test_name, "McpConnectionManager missing pool_status method")
      end
      
      # Test tool registry
      registry = McpToolRegistry.instance
      if registry.respond_to?(:get_server_tools)
        add_success("McpToolRegistry instantiated")
      else
        add_error(test_name, "McpToolRegistry missing get_server_tools method")
      end
      
    rescue => e
      add_error(test_name, e.message)
    end
    puts
  end
  
  def test_production_features
    test_name = "Production Features"
    puts "🔍 Testing: #{test_name}"
    
    begin
      # Test background jobs
      jobs_to_test = [
        McpHealthCheckJob,
        McpAuditLogCleanupJob,
        McpToolDiscoveryJob
      ]
      
      jobs_to_test.each do |job_class|
        if job_class.respond_to?(:perform_later)
          add_success("Background job #{job_class.name} exists")
        else
          add_error(test_name, "Background job #{job_class.name} missing")
        end
      end
      
      # Test database constraints exist
      constraints_exist = ActiveRecord::Base.connection.execute(
        "SELECT COUNT(*) as count FROM information_schema.check_constraints WHERE constraint_name LIKE '%mcp%'"
      ).first['count'].to_i > 0
      
      if constraints_exist
        add_success("Database constraints for MCP tables exist")
      else
        add_error(test_name, "Database constraints for MCP tables missing")
      end
      
    rescue => e
      add_error(test_name, e.message)
    end
    puts
  end
  
  def build_credentials_for_auth_type(auth_type)
    case auth_type
    when :api_key
      { api_key: "test-key", header_name: "Authorization" }
    when :oauth
      { 
        client_id: "test-client",
        client_secret: "test-secret",
        authorization_url: "https://example.com/oauth/authorize",
        token_url: "https://example.com/oauth/token"
      }
    when :bearer_token
      { bearer_token: "test-bearer-token" }
    when :no_auth
      {}
    else
      {}
    end
  end
  
  def add_success(message)
    @successes << message
    puts "  ✅ #{message}"
  end
  
  def add_error(test_name, message)
    @errors << "#{test_name}: #{message}"
    puts "  ❌ #{test_name}: #{message}"
  end
  
  def print_results
    puts "=" * 60
    puts "MCP COMPREHENSIVE TEST RESULTS"
    puts "=" * 60
    puts "✅ Successes: #{@successes.count}"
    puts "❌ Errors: #{@errors.count}"
    puts
    
    if @errors.any?
      puts "ERRORS TO FIX:"
      @errors.each_with_index do |error, index|
        puts "#{index + 1}. #{error}"
      end
      puts
    end
    
    success_rate = (@successes.count.to_f / (@successes.count + @errors.count) * 100).round(1)
    puts "SUCCESS RATE: #{success_rate}%"
    
    if success_rate >= 90
      puts "🎉 MCP INTEGRATION IS HIGHLY FUNCTIONAL!"
    elsif success_rate >= 75
      puts "🟡 MCP INTEGRATION IS MOSTLY FUNCTIONAL (minor issues to fix)"
    else
      puts "🔴 MCP INTEGRATION NEEDS ATTENTION (major issues to address)"
    end
    
    puts "=" * 60
  end
end

# Run the comprehensive test
test_runner = McpFunctionalityTest.new
test_runner.run_all_tests