# frozen_string_literal: true

require 'rails_helper'

RSpec.describe McpBridgeManager, type: :service do
  let(:manager) { described_class.new }
  let(:user) { create(:user) }
  let(:configuration) { create_test_mcp_configuration(owner: user) }
  let(:process_pool) { McpProcessPoolService.instance }
  
  before do
    # Clear any existing processes
    manager.instance_variable_get(:@active_processes).clear
    manager.instance_variable_get(:@restart_attempts).clear
    manager.instance_variable_get(:@circuit_breakers).clear
  end

  describe '#initialize' do
    it 'initializes with process pool instance' do
      pool = manager.instance_variable_get(:@process_pool)
      expect(pool).to eq(McpProcessPoolService.instance)
    end

    it 'initializes empty tracking hashes' do
      expect(manager.instance_variable_get(:@active_processes)).to eq({})
      expect(manager.instance_variable_get(:@restart_attempts)).to eq({})
      expect(manager.instance_variable_get(:@circuit_breakers)).to eq({})
    end
  end

  describe '#list_tools' do
    context 'with valid configuration' do
      before do
        mock_open3_spawn(
          stdout_responses: [
            initialize_response,
            tools_list_response(tools: [
              { 'name' => 'test_tool', 'description' => 'Test tool' }
            ])
          ]
        )
      end

      it 'returns tools from the MCP server' do
        tools = manager.list_tools(user, configuration.id)
        
        expect(tools).to be_an(Array)
        expect(tools.size).to eq(1)
        expect(tools.first['name']).to eq('test_tool')
      end

      it 'reuses existing process if ready' do
        # First call spawns process
        manager.list_tools(user, configuration.id)
        
        # Second call should reuse
        expect(process_pool).not_to receive(:spawn_mcp_server)
        tools = manager.list_tools(user, configuration.id)
        
        expect(tools).to be_an(Array)
      end
    end

    context 'with disabled configuration' do
      before { configuration.update!(enabled: false) }

      it 'raises ConfigurationError' do
        expect {
          manager.list_tools(user, configuration.id)
        }.to raise_error(McpBridgeErrors::ConfigurationError, /disabled/)
      end
    end

    context 'with non-existent configuration' do
      it 'raises RecordNotFound' do
        expect {
          manager.list_tools(user, 999999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '#execute_tool' do
    before do
      mock_open3_spawn(
        stdout_responses: [
          initialize_response,
          tools_list_response(tools: [{ 'name' => 'echo' }]),
          tool_call_response(id: 'test-123', content: 'Hello, World!')
        ]
      )
    end

    it 'executes tool and returns formatted result' do
      result = manager.execute_tool(user, configuration.id, 'echo', { message: 'Hello' })
      
      expect(result[:success]).to be true
      expect(result[:content]).to eq('Hello, World!')
      expect(result[:execution_time]).to be_a(Numeric)
    end

    it 'updates process last_activity' do
      # Ensure process exists
      manager.list_tools(user, configuration.id)
      
      process_key = "user_#{user.id}_config_#{configuration.id}"
      process = manager.instance_variable_get(:@active_processes)[process_key]
      old_activity = process.last_activity
      
      sleep 0.1
      manager.execute_tool(user, configuration.id, 'echo', {})
      
      expect(process.last_activity).to be > old_activity
    end

    context 'with tool execution error' do
      before do
        mock_open3_spawn(
          stdout_responses: [
            initialize_response,
            tools_list_response,
            error_response(id: 'test-123', code: -32601, message: 'Tool not found')
          ]
        )
      end

      it 'returns error result' do
        result = manager.execute_tool(user, configuration.id, 'unknown_tool', {})
        
        expect(result[:success]).to be false
        expect(result[:error][:message]).to eq('Tool not found')
        expect(result[:error][:code]).to eq(-32601)
      end
    end
  end

  describe '#server_status' do
    context 'with running process' do
      before do
        mock_open3_spawn(
          stdout_responses: [
            initialize_response,
            tools_list_response(tools: [{ 'name' => 'tool1' }, { 'name' => 'tool2' }])
          ]
        )
        
        # Create a process
        manager.list_tools(user, configuration.id)
      end

      it 'returns process status information' do
        status = manager.server_status(user, configuration.id)
        
        expect(status[:status]).to eq('ready')
        expect(status[:last_activity]).to be_a(Time)
        expect(status[:tools_count]).to eq(2)
      end
    end

    context 'with no process' do
      it 'returns stopped status' do
        status = manager.server_status(user, configuration.id)
        
        expect(status[:status]).to eq('stopped')
        expect(status[:last_activity]).to be_nil
        expect(status[:tools_count]).to eq(0)
      end
    end
  end

  describe 'error handling and recovery' do
    describe 'process crash detection' do
      before do
        mock_open3_spawn(
          stdout_responses: [
            initialize_response,
            tools_list_response
          ]
        )
        
        # Create initial process
        manager.list_tools(user, configuration.id)
      end

      it 'detects crashed process and spawns new one' do
        process_key = "user_#{user.id}_config_#{configuration.id}"
        process = manager.instance_variable_get(:@active_processes)[process_key]
        
        # Simulate crash
        process.status = 'error'
        allow(process).to receive(:process_alive?).and_return(false)
        
        # Should spawn new process
        expect(process_pool).to receive(:spawn_mcp_server).and_call_original
        
        manager.list_tools(user, configuration.id)
      end
    end

    describe 'circuit breaker' do
      it 'opens after repeated failures' do
        # Simulate 5 failures
        5.times do |i|
          allow(process_pool).to receive(:spawn_mcp_server).and_raise("Spawn failed")
          
          begin
            manager.list_tools(user, configuration.id)
          rescue McpBridgeErrors::ProcessSpawnError
            # Expected
          end
        end
        
        # Circuit should be open now
        expect {
          manager.list_tools(user, configuration.id)
        }.to raise_error(McpBridgeErrors::CircuitOpenError)
      end
    end

    describe 'exponential backoff' do
      it 'retries with increasing delays' do
        attempt = 0
        allow(process_pool).to receive(:spawn_mcp_server) do
          attempt += 1
          raise "Fail" if attempt < 3
          create_mock_mcp_process(configuration)
        end
        
        start_time = Time.current
        manager.send(:spawn_with_retry, configuration, user, 'test_key')
        elapsed = Time.current - start_time
        
        # Should have delays of 1s + 2s = 3s minimum
        expect(elapsed).to be >= 3.0
      end
    end
  end

  describe 'configuration validation' do
    it 'validates server type' do
      configuration.server_type = 'http'
      
      expect {
        manager.list_tools(user, configuration.id)
      }.to raise_error(McpBridgeErrors::ConfigurationError, /only supports stdio/)
    end

    it 'validates command presence' do
      configuration.server_config['command'] = ''
      
      expect {
        manager.list_tools(user, configuration.id)
      }.to raise_error(McpBridgeErrors::ConfigurationError, /Command is required/)
    end

    it 'blocks dangerous commands' do
      configuration.server_config['command'] = 'rm'
      
      expect {
        manager.list_tools(user, configuration.id)
      }.to raise_error(McpBridgeErrors::ConfigurationError, /not allowed for security/)
    end

    it 'blocks shell operators' do
      configuration.server_config['command'] = 'echo; cat /etc/passwd'
      
      expect {
        manager.list_tools(user, configuration.id)
      }.to raise_error(McpBridgeErrors::ConfigurationError, /dangerous shell operators/)
    end

    it 'validates args type' do
      configuration.server_config['args'] = 'not-an-array'
      
      expect {
        manager.list_tools(user, configuration.id)
      }.to raise_error(McpBridgeErrors::ConfigurationError, /Args must be an array/)
    end

    it 'validates env type' do
      configuration.server_config['env'] = 'not-a-hash'
      
      expect {
        manager.list_tools(user, configuration.id)
      }.to raise_error(McpBridgeErrors::ConfigurationError, /Env must be a hash/)
    end

    it 'checks required environment variables' do
      configuration.server_config['command'] = 'linear-mcp'
      configuration.server_config['env'] = {}
      
      expect {
        manager.list_tools(user, configuration.id)
      }.to raise_error(McpBridgeErrors::ConfigurationError, /Missing required environment variables/)
    end
  end

  describe 'result formatting' do
    it 'formats array content' do
      result = manager.send(:format_tool_result, {
        result: {
          content: [
            { type: 'text', text: 'Line 1' },
            { type: 'text', text: 'Line 2' }
          ]
        }
      })
      
      expect(result[:success]).to be true
      expect(result[:content]).to eq("Line 1\nLine 2")
    end

    it 'formats hash content' do
      result = manager.send(:format_tool_result, {
        result: {
          content: { text: 'Hello' }
        }
      })
      
      expect(result[:success]).to be true
      expect(result[:content]).to eq('Hello')
    end

    it 'formats string content' do
      result = manager.send(:format_tool_result, {
        result: { content: 'Simple string' }
      })
      
      expect(result[:success]).to be true
      expect(result[:content]).to eq('Simple string')
    end

    it 'formats error responses' do
      result = manager.send(:format_tool_result, {
        error: { code: -32601, message: 'Method not found' }
      })
      
      expect(result[:success]).to be false
      expect(result[:error][:code]).to eq(-32601)
      expect(result[:error][:message]).to eq('Method not found')
    end
  end
end