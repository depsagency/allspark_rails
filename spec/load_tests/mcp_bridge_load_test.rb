# frozen_string_literal: true

require 'rails_helper'
require 'concurrent'
require 'benchmark'

RSpec.describe 'MCP Bridge Load Test', type: :integration do
  let(:user) { create(:user) }
  let(:configuration) { create_test_mcp_configuration(owner: user) }
  let(:bridge_manager) { McpBridgeManager.new }
  
  before do
    # Setup mock MCP server for load testing
    mock_open3_spawn(
      stdout_responses: [
        initialize_response,
        tools_list_response(tools: [
          { 'name' => 'echo', 'description' => 'Echo tool' },
          { 'name' => 'add', 'description' => 'Add numbers' }
        ])
      ] + Array.new(1000) { |i| tool_call_response(id: "load-test-#{i}", content: "Response #{i}") }
    )
  end

  describe 'concurrent user simulation' do
    it 'handles 10 concurrent users making tool calls', :slow do
      concurrent_users = 10
      calls_per_user = 5
      
      results = Concurrent::Array.new
      errors = Concurrent::Array.new
      
      threads = concurrent_users.times.map do |user_id|
        Thread.new do
          test_user = create(:user, email: "loadtest#{user_id}@example.com")
          test_config = create_test_mcp_configuration(owner: test_user)
          
          calls_per_user.times do |call_id|
            begin
              start_time = Time.current
              result = bridge_manager.execute_tool(
                test_user, 
                test_config.id, 
                'echo', 
                { message: "User #{user_id} Call #{call_id}" }
              )
              duration = (Time.current - start_time) * 1000 # ms
              
              results << {
                user_id: user_id,
                call_id: call_id,
                success: result[:success],
                duration: duration
              }
            rescue => e
              errors << {
                user_id: user_id,
                call_id: call_id,
                error: e.message
              }
            end
          end
        end
      end
      
      # Wait for all threads to complete with timeout
      threads.each { |t| t.join(30) }
      
      # Analyze results
      successful_calls = results.select { |r| r[:success] }
      failed_calls = results.reject { |r| r[:success] }
      
      puts "\n=== Load Test Results ==="
      puts "Total calls: #{concurrent_users * calls_per_user}"
      puts "Successful: #{successful_calls.size}"
      puts "Failed: #{failed_calls.size}"
      puts "Errors: #{errors.size}"
      puts "Success rate: #{(successful_calls.size.to_f / results.size * 100).round(2)}%"
      
      if successful_calls.any?
        durations = successful_calls.map { |r| r[:duration] }
        puts "Avg response time: #{(durations.sum / durations.size).round(2)}ms"
        puts "Min response time: #{durations.min.round(2)}ms"
        puts "Max response time: #{durations.max.round(2)}ms"
        puts "95th percentile: #{durations.sort[(durations.size * 0.95).to_i].round(2)}ms"
      end
      
      # Performance assertions
      expect(successful_calls.size).to be >= (concurrent_users * calls_per_user * 0.9) # 90% success rate
      expect(errors.size).to be <= (concurrent_users * calls_per_user * 0.1) # Max 10% errors
      
      if successful_calls.any?
        avg_duration = successful_calls.map { |r| r[:duration] }.sum / successful_calls.size
        expect(avg_duration).to be < 2000 # Under 2 seconds average
      end
    end
    
    it 'handles process spawning under load', :slow do
      concurrent_spawns = 5
      
      spawn_results = Concurrent::Array.new
      spawn_errors = Concurrent::Array.new
      
      threads = concurrent_spawns.times.map do |i|
        Thread.new do
          begin
            test_user = create(:user, email: "spawn#{i}@example.com")
            test_config = create_test_mcp_configuration(owner: test_user)
            
            start_time = Time.current
            tools = bridge_manager.list_tools(test_user, test_config.id)
            duration = (Time.current - start_time) * 1000
            
            spawn_results << {
              spawn_id: i,
              success: tools.is_a?(Array),
              duration: duration,
              tools_count: tools&.size || 0
            }
          rescue => e
            spawn_errors << {
              spawn_id: i,
              error: e.message
            }
          end
        end
      end
      
      threads.each { |t| t.join(30) }
      
      puts "\n=== Process Spawn Load Test ==="
      puts "Concurrent spawns: #{concurrent_spawns}"
      puts "Successful spawns: #{spawn_results.size}"
      puts "Failed spawns: #{spawn_errors.size}"
      
      if spawn_results.any?
        durations = spawn_results.map { |r| r[:duration] }
        puts "Avg spawn time: #{(durations.sum / durations.size).round(2)}ms"
        puts "Max spawn time: #{durations.max.round(2)}ms"
      end
      
      # All spawns should succeed
      expect(spawn_results.size).to eq(concurrent_spawns)
      expect(spawn_errors).to be_empty
    end
  end
  
  describe 'memory usage monitoring' do
    it 'monitors memory usage during sustained load', :slow do
      initial_memory = get_memory_usage
      
      # Perform sustained operations
      100.times do |i|
        bridge_manager.execute_tool(user, configuration.id, 'echo', { iteration: i })
        
        # Check memory every 20 iterations
        if i % 20 == 0
          current_memory = get_memory_usage
          memory_growth = current_memory - initial_memory
          
          puts "Iteration #{i}: Memory usage #{current_memory}MB (growth: #{memory_growth}MB)"
          
          # Memory shouldn't grow excessively (more than 100MB)
          expect(memory_growth).to be < 100
        end
      end
      
      # Force garbage collection
      GC.start
      
      final_memory = get_memory_usage
      total_growth = final_memory - initial_memory
      
      puts "Final memory growth: #{total_growth}MB"
      
      # Total growth should be reasonable
      expect(total_growth).to be < 50 # Less than 50MB growth after GC
    end
  end
  
  describe 'performance benchmarks' do
    it 'benchmarks tool execution performance' do
      # Warm up
      5.times { bridge_manager.execute_tool(user, configuration.id, 'echo', { warmup: true }) }
      
      iterations = 100
      
      benchmark_result = Benchmark.bm do |bm|
        bm.report("#{iterations} tool executions") do
          iterations.times do |i|
            bridge_manager.execute_tool(user, configuration.id, 'echo', { iteration: i })
          end
        end
      end
      
      puts "\nPerformance metrics:"
      puts "Total time: #{benchmark_result.first.total}s"
      puts "Average per call: #{(benchmark_result.first.total / iterations * 1000).round(2)}ms"
      
      # Performance expectations
      avg_time_ms = (benchmark_result.first.total / iterations * 1000)
      expect(avg_time_ms).to be < 100 # Less than 100ms per call
    end
    
    it 'benchmarks process lifecycle performance' do
      process_count = 10
      
      benchmark_result = Benchmark.bm do |bm|
        bm.report("spawn #{process_count} processes") do
          process_count.times do |i|
            test_user = create(:user, email: "bench#{i}@example.com")
            test_config = create_test_mcp_configuration(owner: test_user)
            bridge_manager.list_tools(test_user, test_config.id)
          end
        end
      end
      
      avg_spawn_time = (benchmark_result.first.total / process_count * 1000)
      puts "Average process spawn time: #{avg_spawn_time.round(2)}ms"
      
      # Process spawning should be reasonably fast
      expect(avg_spawn_time).to be < 500 # Less than 500ms per spawn
    end
  end
  
  private
  
  def get_memory_usage
    # Get current memory usage in MB
    `ps -o rss= -p #{Process.pid}`.to_i / 1024
  rescue
    0
  end
end