# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MCP Bridge Integration', type: :integration do
  let(:user) { create(:user) }
  let(:bridge_manager) { McpBridgeManager.new }
  let(:process_pool) { McpProcessPoolService.instance }
  
  describe 'full MCP server lifecycle' do
    let(:configuration) do
      create(:mcp_configuration,
        owner: user,
        server_type: 'stdio',
        enabled: true,
        server_config: {
          'command' => ENV['MCP_MOCK_SERVER_PATH'] || Rails.root.join('spec/support/mock_mcp_server.rb').to_s,
          'args' => [],
          'env' => { 'MOCK_MODE' => 'true' }
        }
      )
    end

    it 'spawns process, discovers tools, executes tool, and shuts down' do
      # 1. List tools (spawns process)
      tools = bridge_manager.list_tools(user, configuration.id)
      
      expect(tools).to be_an(Array)
      expect(tools.size).to eq(2)
      expect(tools.map { |t| t['name'] }).to contain_exactly('echo', 'add')
      
      # 2. Check server status
      status = bridge_manager.server_status(user, configuration.id)
      
      expect(status[:status]).to eq('ready')
      expect(status[:tools_count]).to eq(2)
      
      # 3. Execute echo tool
      result = bridge_manager.execute_tool(user, configuration.id, 'echo', { message: 'Hello, MCP!' })
      
      expect(result[:success]).to be true
      expect(result[:content]).to eq('Hello, MCP!')
      
      # 4. Execute add tool
      result = bridge_manager.execute_tool(user, configuration.id, 'add', { a: 5, b: 3 })
      
      expect(result[:success]).to be true
      expect(result[:content]).to eq('Result: 8')
      
      # 5. Shutdown
      process_pool.shutdown_all_processes
      
      # 6. Verify shutdown
      status = bridge_manager.server_status(user, configuration.id)
      expect(status[:status]).to eq('stopped')
    end
  end

  describe 'error recovery' do
    let(:configuration) do
      create(:mcp_configuration,
        owner: user,
        server_type: 'stdio',
        enabled: true,
        server_config: {
          'command' => 'bash',
          'args' => ['-c', 'exit 1'],  # Command that exits immediately
          'env' => {}
        }
      )
    end

    it 'handles process crash and retries' do
      expect {
        bridge_manager.list_tools(user, configuration.id)
      }.to raise_error(McpBridgeErrors::ProcessSpawnError)
      
      # Should have attempted retries
      process_key = "user_#{user.id}_config_#{configuration.id}"
      attempts = bridge_manager.instance_variable_get(:@restart_attempts)[process_key]
      expect(attempts).to be >= 1
    end
  end

  describe 'concurrent process management' do
    let(:user2) { create(:user) }
    let(:config1) do
      create(:mcp_configuration,
        owner: user,
        name: 'Server 1',
        server_type: 'stdio',
        server_config: {
          'command' => 'echo',
          'args' => ['{"jsonrpc":"2.0","id":1,"result":{"capabilities":{}}}']
        }
      )
    end
    let(:config2) do
      create(:mcp_configuration,
        owner: user2,
        name: 'Server 2',
        server_type: 'stdio',
        server_config: {
          'command' => 'echo',
          'args' => ['{"jsonrpc":"2.0","id":1,"result":{"capabilities":{}}}']
        }
      )
    end

    it 'manages multiple processes for different users' do
      # Start processes for both users
      thread1 = Thread.new { bridge_manager.list_tools(user, config1.id) }
      thread2 = Thread.new { bridge_manager.list_tools(user2, config2.id) }
      
      thread1.join
      thread2.join
      
      # Check both processes are running
      status1 = bridge_manager.server_status(user, config1.id)
      status2 = bridge_manager.server_status(user2, config2.id)
      
      expect(status1[:status]).to eq('ready')
      expect(status2[:status]).to eq('ready')
      
      # Verify process isolation
      active_processes = bridge_manager.instance_variable_get(:@active_processes)
      expect(active_processes.size).to eq(2)
      expect(active_processes.keys).to contain_exactly(
        "user_#{user.id}_config_#{config1.id}",
        "user_#{user2.id}_config_#{config2.id}"
      )
    end
  end

  describe 'health monitoring' do
    let(:configuration) do
      create(:mcp_configuration,
        owner: user,
        server_type: 'stdio',
        server_config: {
          'command' => ENV['MCP_MOCK_SERVER_PATH'] || Rails.root.join('spec/support/mock_mcp_server.rb').to_s
        }
      )
    end

    it 'detects and handles stale processes' do
      # Start process
      bridge_manager.list_tools(user, configuration.id)
      
      # Get process
      process_key = "user_#{user.id}_config_#{configuration.id}"
      process = bridge_manager.instance_variable_get(:@active_processes)[process_key]
      
      # Make it stale
      process.last_activity = 10.minutes.ago
      
      # Run health check
      job = McpHealthMonitorJob.new
      allow(job).to receive(:schedule_next_check)  # Don't schedule in tests
      
      job.perform
      
      # Process should have been pinged or marked unhealthy
      expect(process.last_activity).to be > 10.minutes.ago
    end
  end

  describe 'performance' do
    let(:configuration) do
      create(:mcp_configuration,
        owner: user,
        server_type: 'stdio',
        server_config: {
          'command' => 'echo',
          'args' => ['{"jsonrpc":"2.0","id":1,"result":{"tools":[{"name":"test"}]}}']
        }
      )
    end

    it 'caches tool lists' do
      # First call
      start_time = Time.current
      tools1 = bridge_manager.list_tools(user, configuration.id)
      first_call_time = Time.current - start_time
      
      # Second call should be cached
      start_time = Time.current
      tools2 = bridge_manager.list_tools(user, configuration.id)
      second_call_time = Time.current - start_time
      
      expect(tools1).to eq(tools2)
      expect(second_call_time).to be < (first_call_time / 2)  # Much faster
    end

    it 'handles rapid tool executions' do
      # Ensure process is running
      bridge_manager.list_tools(user, configuration.id)
      
      # Execute multiple tools rapidly
      results = []
      10.times do |i|
        result = bridge_manager.execute_tool(user, configuration.id, 'test', { count: i })
        results << result
      end
      
      expect(results).to all(include(success: true))
      expect(results.map { |r| r[:execution_time] }).to all(be < 1.0)  # All under 1 second
    end
  end

  describe 'authorization' do
    let(:other_user) { create(:user) }
    let(:configuration) do
      create(:mcp_configuration,
        owner: user,
        server_type: 'stdio',
        server_config: { 'command' => 'echo' }
      )
    end

    it 'prevents access to other users configurations' do
      expect {
        bridge_manager.list_tools(other_user, configuration.id)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end