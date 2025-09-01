# frozen_string_literal: true

namespace :mcp do
  namespace :health do
    desc "Perform comprehensive MCP system health check"
    task check: :environment do
      puts "🔍 MCP System Health Check"
      puts "=" * 50
      
      checks = [
        :check_database_connectivity,
        :check_redis_connectivity,
        :check_background_jobs,
        :check_server_configurations,
        :check_connection_pools,
        :check_oauth_settings,
        :check_audit_log_health,
        :check_tool_registry,
        :check_performance_metrics
      ]
      
      results = {}
      
      checks.each do |check|
        print "#{check.to_s.humanize}... "
        begin
          result = send(check)
          if result[:status] == :ok
            puts "✅ #{result[:message]}"
          else
            puts "⚠️  #{result[:message]}"
          end
          results[check] = result
        rescue => e
          puts "❌ #{e.message}"
          results[check] = { status: :error, message: e.message }
        end
      end
      
      puts "\n" + "=" * 50
      puts "📊 Health Check Summary"
      puts "=" * 50
      
      ok_count = results.values.count { |r| r[:status] == :ok }
      warning_count = results.values.count { |r| r[:status] == :warning }
      error_count = results.values.count { |r| r[:status] == :error }
      
      puts "✅ Passed: #{ok_count}"
      puts "⚠️  Warnings: #{warning_count}" if warning_count > 0
      puts "❌ Errors: #{error_count}" if error_count > 0
      
      if error_count > 0
        puts "\n🚨 Critical Issues Found:"
        results.each do |check, result|
          if result[:status] == :error
            puts "   • #{check.to_s.humanize}: #{result[:message]}"
          end
        end
        exit 1
      elsif warning_count > 0
        puts "\n⚠️  Warnings Found (System Functional):"
        results.each do |check, result|
          if result[:status] == :warning
            puts "   • #{check.to_s.humanize}: #{result[:message]}"
          end
        end
      else
        puts "\n🎉 All systems healthy!"
      end
    end

    desc "Check MCP server connectivity"
    task servers: :environment do
      puts "🔗 Testing MCP Server Connectivity"
      puts "=" * 50
      
      servers = McpServer.active
      
      if servers.empty?
        puts "⚠️  No active MCP servers configured"
        exit 0
      end
      
      servers.each do |server|
        print "#{server.name} (#{server.endpoint})... "
        
        begin
          client = McpClient.new(server)
          if client.test_connection
            puts "✅ Connected"
          else
            puts "❌ Connection failed"
          end
        rescue => e
          puts "❌ Error: #{e.message}"
        end
      end
    end

    desc "Check OAuth token status"
    task oauth: :environment do
      puts "🔐 OAuth Token Status"
      puts "=" * 50
      
      oauth_servers = McpServer.where(auth_type: :oauth)
      
      if oauth_servers.empty?
        puts "ℹ️  No OAuth-enabled servers configured"
        exit 0
      end
      
      oauth_servers.each do |server|
        print "#{server.name}... "
        
        if server.credentials&.dig('access_token').present?
          expires_at = server.credentials.dig('expires_at')
          
          if expires_at.present?
            expiry = Time.parse(expires_at)
            if expiry > Time.current
              time_remaining = ((expiry - Time.current) / 3600).round(1)
              puts "✅ Valid (expires in #{time_remaining}h)"
            else
              puts "❌ Expired"
            end
          else
            puts "⚠️  No expiration set"
          end
        else
          puts "❌ No token"
        end
      end
    end

    desc "Monitor background job health"
    task jobs: :environment do
      puts "⚙️  Background Job Health"
      puts "=" * 50
      
      # Check Sidekiq status
      begin
        stats = Sidekiq::Stats.new
        puts "Queue size: #{stats.enqueued}"
        puts "Processing: #{stats.processes_size}"
        puts "Failed jobs: #{stats.failed}"
        puts "Retries: #{stats.retry_size}"
        
        if stats.failed > 100
          puts "⚠️  High number of failed jobs"
        elsif stats.enqueued > 1000
          puts "⚠️  Large queue size"
        else
          puts "✅ Healthy"
        end
      rescue => e
        puts "❌ Sidekiq not available: #{e.message}"
      end
    end

    private

    def check_database_connectivity
      McpServer.connection.execute("SELECT 1")
      count = McpServer.count
      { status: :ok, message: "Connected (#{count} servers configured)" }
    rescue => e
      { status: :error, message: "Database error: #{e.message}" }
    end

    def check_redis_connectivity
      Rails.cache.write('mcp_health_check', Time.current.to_i)
      value = Rails.cache.read('mcp_health_check')
      { status: :ok, message: "Connected and functional" }
    rescue => e
      { status: :error, message: "Redis error: #{e.message}" }
    end

    def check_background_jobs
      stats = Sidekiq::Stats.new
      
      if stats.failed > 100
        { status: :warning, message: "#{stats.failed} failed jobs" }
      elsif stats.enqueued > 1000
        { status: :warning, message: "Large queue: #{stats.enqueued} jobs" }
      else
        { status: :ok, message: "#{stats.enqueued} queued, #{stats.processes_size} workers" }
      end
    rescue => e
      { status: :error, message: "Sidekiq unavailable: #{e.message}" }
    end

    def check_server_configurations
      total = McpServer.count
      active = McpServer.active.count
      
      if total == 0
        { status: :warning, message: "No servers configured" }
      elsif active == 0
        { status: :warning, message: "No active servers" }
      else
        { status: :ok, message: "#{active}/#{total} servers active" }
      end
    end

    def check_connection_pools
      manager = McpConnectionManager.instance
      status = manager.pool_status
      
      if status[:total_connections] > 50
        { status: :warning, message: "High connection count: #{status[:total_connections]}" }
      else
        { status: :ok, message: "#{status[:total_connections]} active connections" }
      end
    rescue => e
      { status: :error, message: "Pool manager error: #{e.message}" }
    end

    def check_oauth_settings
      oauth_servers = McpServer.where(auth_type: :oauth)
      
      if oauth_servers.empty?
        { status: :ok, message: "No OAuth servers (not needed)" }
      else
        expired_count = oauth_servers.count do |server|
          expires_at = server.credentials&.dig('expires_at')
          expires_at && Time.parse(expires_at) <= Time.current
        end
        
        if expired_count > 0
          { status: :warning, message: "#{expired_count} servers have expired tokens" }
        else
          { status: :ok, message: "All #{oauth_servers.count} OAuth tokens valid" }
        end
      end
    end

    def check_audit_log_health
      total_logs = McpAuditLog.count
      recent_logs = McpAuditLog.where('executed_at > ?', 24.hours.ago).count
      
      if total_logs > 1_000_000
        { status: :warning, message: "Large audit log: #{total_logs} records" }
      else
        { status: :ok, message: "#{total_logs} total logs, #{recent_logs} recent" }
      end
    end

    def check_tool_registry
      registry = McpToolRegistry.instance
      tool_count = registry.available_tools.size
      
      { status: :ok, message: "#{tool_count} tools registered" }
    rescue => e
      { status: :error, message: "Registry error: #{e.message}" }
    end

    def check_performance_metrics
      recent_logs = McpAuditLog.successful.where('executed_at > ?', 1.hour.ago)
      
      if recent_logs.empty?
        { status: :ok, message: "No recent activity" }
      else
        avg_response = recent_logs.average(:response_time_ms)&.round(0) || 0
        
        if avg_response > 5000
          { status: :warning, message: "Slow average response: #{avg_response}ms" }
        else
          { status: :ok, message: "Average response time: #{avg_response}ms" }
        end
      end
    end
  end

  desc "Show MCP system status"
  task status: :environment do
    puts "📊 MCP System Status"
    puts "=" * 50
    
    # Server overview
    servers = McpServer.all
    puts "Servers: #{servers.active.count}/#{servers.count} active"
    
    servers.group(:auth_type).count.each do |auth_type, count|
      puts "  #{auth_type.humanize}: #{count}"
    end
    
    # Recent activity
    recent_logs = McpAuditLog.where('executed_at > ?', 24.hours.ago)
    puts "\nActivity (24h): #{recent_logs.count} executions"
    puts "  Successful: #{recent_logs.successful.count}"
    puts "  Failed: #{recent_logs.failed.count}"
    
    if recent_logs.any?
      avg_response = recent_logs.successful.average(:response_time_ms)&.round(0) || 0
      puts "  Avg response: #{avg_response}ms"
    end
    
    # Background jobs
    begin
      stats = Sidekiq::Stats.new
      puts "\nBackground Jobs:"
      puts "  Queued: #{stats.enqueued}"
      puts "  Failed: #{stats.failed}"
      puts "  Workers: #{stats.processes_size}"
    rescue
      puts "\nBackground Jobs: Unavailable"
    end
    
    # Connection pools
    begin
      manager = McpConnectionManager.instance
      status = manager.pool_status
      puts "\nConnection Pools: #{status[:total_connections]} active"
    rescue
      puts "\nConnection Pools: Unavailable"
    end
  end
end