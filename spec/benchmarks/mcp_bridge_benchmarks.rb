# frozen_string_literal: true

require 'rails_helper'
require 'benchmark'
require 'json'

RSpec.describe 'MCP Bridge Performance Benchmarks', type: :integration do
  let(:user) { create(:user) }
  let(:configuration) { create_test_mcp_configuration(owner: user) }
  let(:bridge_manager) { McpBridgeManager.new }
  let(:process_pool) { McpProcessPoolService.instance }
  
  before do
    mock_open3_spawn(
      stdout_responses: [
        initialize_response,
        tools_list_response(tools: [
          { 'name' => 'echo', 'description' => 'Echo tool' },
          { 'name' => 'add', 'description' => 'Add numbers tool' }
        ])
      ] + Array.new(1000) { |i| tool_call_response(id: "bench-#{i}", content: "Result #{i}") }
    )
  end
  
  describe 'process spawn time benchmarks' do
    it 'benchmarks single process spawn time' do
      iterations = 10
      spawn_times = []
      
      iterations.times do |i|
        test_user = create(:user, email: "spawn#{i}@example.com")
        test_config = create_test_mcp_configuration(owner: test_user)
        
        spawn_time = Benchmark.realtime do
          bridge_manager.list_tools(test_user, test_config.id)
        end
        
        spawn_times << spawn_time * 1000 # Convert to milliseconds
      end
      
      avg_spawn_time = spawn_times.sum / spawn_times.size
      min_spawn_time = spawn_times.min
      max_spawn_time = spawn_times.max
      
      puts "\n=== Process Spawn Benchmarks ==="
      puts "Iterations: #{iterations}"
      puts "Average spawn time: #{avg_spawn_time.round(2)}ms"
      puts "Min spawn time: #{min_spawn_time.round(2)}ms"
      puts "Max spawn time: #{max_spawn_time.round(2)}ms"
      puts "Standard deviation: #{calculate_std_dev(spawn_times).round(2)}ms"
      
      # Performance assertions
      expect(avg_spawn_time).to be < 500 # Less than 500ms average
      expect(max_spawn_time).to be < 1000 # No spawn should take more than 1s
    end
    
    it 'benchmarks concurrent process spawning' do
      concurrent_spawns = 5
      spawn_results = Concurrent::Array.new
      
      start_time = Time.current
      
      threads = concurrent_spawns.times.map do |i|
        Thread.new do
          test_user = create(:user, email: "concurrent#{i}@example.com")
          test_config = create_test_mcp_configuration(owner: test_user)
          
          spawn_start = Time.current
          bridge_manager.list_tools(test_user, test_config.id)
          spawn_duration = (Time.current - spawn_start) * 1000
          
          spawn_results << spawn_duration
        end
      end
      
      threads.each(&:join)
      total_time = (Time.current - start_time) * 1000
      
      puts "\n=== Concurrent Spawn Benchmarks ==="
      puts "Concurrent spawns: #{concurrent_spawns}"
      puts "Total time: #{total_time.round(2)}ms"
      puts "Average spawn time: #{(spawn_results.sum / spawn_results.size).round(2)}ms"
      puts "Max spawn time: #{spawn_results.max.round(2)}ms"
      
      # Concurrent spawning should be efficient
      expect(total_time).to be < 2000 # All spawns complete within 2s
    end
  end
  
  describe 'tool execution benchmarks' do
    before do
      # Pre-spawn process for consistent benchmarking
      bridge_manager.list_tools(user, configuration.id)
    end
    
    it 'benchmarks single tool execution time' do
      iterations = 100
      execution_times = []
      
      iterations.times do |i|
        execution_time = Benchmark.realtime do
          bridge_manager.execute_tool(user, configuration.id, 'echo', { message: "Test #{i}" })
        end
        
        execution_times << execution_time * 1000 # Convert to milliseconds
      end
      
      avg_execution_time = execution_times.sum / execution_times.size
      min_execution_time = execution_times.min
      max_execution_time = execution_times.max
      p95_execution_time = execution_times.sort[(execution_times.size * 0.95).to_i]
      
      puts "\n=== Tool Execution Benchmarks ==="
      puts "Iterations: #{iterations}"
      puts "Average execution time: #{avg_execution_time.round(2)}ms"
      puts "Min execution time: #{min_execution_time.round(2)}ms"
      puts "Max execution time: #{max_execution_time.round(2)}ms"
      puts "95th percentile: #{p95_execution_time.round(2)}ms"
      puts "Standard deviation: #{calculate_std_dev(execution_times).round(2)}ms"
      
      # Performance assertions
      expect(avg_execution_time).to be < 100 # Less than 100ms average
      expect(p95_execution_time).to be < 200 # 95% under 200ms
    end
    
    it 'benchmarks rapid sequential tool executions' do
      rapid_calls = 50
      
      total_time = Benchmark.realtime do
        rapid_calls.times do |i|
          bridge_manager.execute_tool(user, configuration.id, 'echo', { rapid: i })
        end
      end
      
      total_time_ms = total_time * 1000
      avg_time_per_call = total_time_ms / rapid_calls
      calls_per_second = rapid_calls / total_time
      
      puts "\n=== Rapid Sequential Execution Benchmarks ==="
      puts "Rapid calls: #{rapid_calls}"
      puts "Total time: #{total_time_ms.round(2)}ms"
      puts "Average per call: #{avg_time_per_call.round(2)}ms"
      puts "Calls per second: #{calls_per_second.round(2)}"
      
      # Should handle rapid calls efficiently
      expect(calls_per_second).to be > 10 # At least 10 calls per second
      expect(avg_time_per_call).to be < 100 # Under 100ms per call
    end
  end
  
  describe 'JSON parsing benchmarks' do
    let(:sample_responses) do
      [
        { simple: 'string response' },
        { complex: { nested: { data: Array.new(100) { |i| "item_#{i}" } } } },
        { array: Array.new(1000) { |i| { id: i, name: "Item #{i}" } } }
      ]
    end
    
    it 'benchmarks JSON parsing overhead' do
      iterations = 1000
      
      parsing_times = sample_responses.map do |response|
        json_string = JSON.generate(response)
        
        parse_time = Benchmark.realtime do
          iterations.times do
            JSON.parse(json_string, symbolize_names: true)
          end
        end
        
        {
          type: response.keys.first,
          size: json_string.bytesize,
          total_time: parse_time * 1000,
          avg_per_parse: (parse_time / iterations) * 1000 * 1000 # microseconds
        }
      end
      
      puts "\n=== JSON Parsing Benchmarks ==="
      parsing_times.each do |result|
        puts "#{result[:type]} (#{result[:size]} bytes):"
        puts "  Total time: #{result[:total_time].round(2)}ms"
        puts "  Avg per parse: #{result[:avg_per_parse].round(2)}μs"
      end
      
      # JSON parsing should be fast
      parsing_times.each do |result|
        expect(result[:avg_per_parse]).to be < 1000 # Under 1ms per parse
      end
    end
    
    it 'compares JSON parsing performance with different libraries' do
      large_response = { data: Array.new(1000) { |i| { id: i, value: "data_#{i}" } } }
      json_string = JSON.generate(large_response)
      iterations = 100
      
      # Standard JSON
      standard_time = Benchmark.realtime do
        iterations.times { JSON.parse(json_string, symbolize_names: true) }
      end
      
      # Oj (if available)
      oj_time = if defined?(Oj)
        Benchmark.realtime do
          iterations.times { Oj.load(json_string, symbol_keys: true) }
        end
      else
        nil
      end
      
      puts "\n=== JSON Library Comparison ==="
      puts "Standard JSON: #{(standard_time * 1000).round(2)}ms"
      puts "Oj (if available): #{oj_time ? (oj_time * 1000).round(2) : 'Not available'}ms"
      
      if oj_time
        improvement = ((standard_time - oj_time) / standard_time * 100).round(2)
        puts "Oj improvement: #{improvement}%"
      end
    end
  end
  
  describe 'memory usage benchmarks' do
    it 'measures memory usage during process lifecycle' do
      initial_memory = get_memory_usage
      
      # Create multiple processes
      processes = []
      5.times do |i|
        test_user = create(:user, email: "memory#{i}@example.com")
        test_config = create_test_mcp_configuration(owner: test_user)
        bridge_manager.list_tools(test_user, test_config.id)
        processes << { user: test_user, config: test_config }
      end
      
      after_spawn_memory = get_memory_usage
      
      # Execute tools on each process
      processes.each_with_index do |(process_info), i|
        10.times do |j|
          bridge_manager.execute_tool(
            process_info[:user], 
            process_info[:config].id, 
            'echo', 
            { process: i, call: j }
          )
        end
      end
      
      after_execution_memory = get_memory_usage
      
      # Clean up
      GC.start
      after_gc_memory = get_memory_usage
      
      puts "\n=== Memory Usage Benchmarks ==="
      puts "Initial memory: #{initial_memory}MB"
      puts "After spawning 5 processes: #{after_spawn_memory}MB (+#{after_spawn_memory - initial_memory}MB)"
      puts "After 50 tool executions: #{after_execution_memory}MB (+#{after_execution_memory - initial_memory}MB)"
      puts "After garbage collection: #{after_gc_memory}MB (+#{after_gc_memory - initial_memory}MB)"
      
      spawn_overhead = after_spawn_memory - initial_memory
      execution_overhead = after_execution_memory - after_spawn_memory
      gc_cleanup = after_execution_memory - after_gc_memory
      
      puts "Spawn overhead: #{spawn_overhead}MB"
      puts "Execution overhead: #{execution_overhead}MB"
      puts "GC cleanup: #{gc_cleanup}MB"
      
      # Memory usage should be reasonable
      expect(spawn_overhead).to be < 50 # Less than 50MB for 5 processes
      expect(execution_overhead).to be < 20 # Less than 20MB for 50 executions
    end
  end
  
  describe 'comparison with direct execution' do
    it 'compares bridge overhead vs direct execution' do
      iterations = 50
      
      # Benchmark bridge execution
      bridge_time = Benchmark.realtime do
        iterations.times do |i|
          bridge_manager.execute_tool(user, configuration.id, 'echo', { bridge: i })
        end
      end
      
      # Benchmark direct process execution (simulated)
      direct_time = Benchmark.realtime do
        iterations.times do |i|
          # Simulate direct JSON-RPC call overhead
          request = JsonRpcMessage.request(
            method: 'tools/call',
            params: { name: 'echo', arguments: { direct: i } }
          )
          # Simulate JSON serialization/parsing
          JSON.parse(JSON.generate(request), symbolize_names: true)
        end
      end
      
      bridge_time_ms = bridge_time * 1000
      direct_time_ms = direct_time * 1000
      overhead_ms = bridge_time_ms - direct_time_ms
      overhead_percentage = (overhead_ms / direct_time_ms * 100).round(2)
      
      puts "\n=== Bridge vs Direct Execution Comparison ==="
      puts "Bridge execution: #{bridge_time_ms.round(2)}ms"
      puts "Direct execution (simulated): #{direct_time_ms.round(2)}ms"
      puts "Bridge overhead: #{overhead_ms.round(2)}ms (#{overhead_percentage}%)"
      puts "Avg overhead per call: #{(overhead_ms / iterations).round(2)}ms"
      
      # Bridge overhead should be reasonable
      expect(overhead_ms / iterations).to be < 50 # Less than 50ms overhead per call
    end
  end
  
  describe 'performance report generation' do
    it 'generates comprehensive performance report' do
      report = {
        timestamp: Time.current,
        test_configuration: {
          ruby_version: RUBY_VERSION,
          rails_version: Rails.version,
          platform: RUBY_PLATFORM
        },
        benchmarks: {}
      }
      
      # Process spawn benchmark
      spawn_time = Benchmark.realtime do
        test_user = create(:user, email: 'report@example.com')
        test_config = create_test_mcp_configuration(owner: test_user)
        bridge_manager.list_tools(test_user, test_config.id)
      end
      
      report[:benchmarks][:process_spawn] = {
        time_ms: (spawn_time * 1000).round(2),
        status: spawn_time < 0.5 ? 'PASS' : 'FAIL'
      }
      
      # Tool execution benchmark
      execution_time = Benchmark.realtime do
        bridge_manager.execute_tool(user, configuration.id, 'echo', { test: 'report' })
      end
      
      report[:benchmarks][:tool_execution] = {
        time_ms: (execution_time * 1000).round(2),
        status: execution_time < 0.1 ? 'PASS' : 'FAIL'
      }
      
      # Memory usage
      report[:benchmarks][:memory_usage] = {
        current_mb: get_memory_usage,
        status: get_memory_usage < 100 ? 'PASS' : 'WARN'
      }
      
      puts "\n=== Performance Report ==="
      puts JSON.pretty_generate(report)
      
      # Save report to file
      File.write('tmp/mcp_bridge_performance_report.json', JSON.pretty_generate(report))
      
      # All benchmarks should pass
      report[:benchmarks].each do |benchmark, results|
        expect(results[:status]).to be_in(['PASS', 'WARN'])
      end
    end
  end
  
  private
  
  def get_memory_usage
    # Get current memory usage in MB
    `ps -o rss= -p #{Process.pid}`.to_i / 1024
  rescue
    0
  end
  
  def calculate_std_dev(array)
    mean = array.sum / array.size
    variance = array.sum { |x| (x - mean) ** 2 } / array.size
    Math.sqrt(variance)
  end
end