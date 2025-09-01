# frozen_string_literal: true

require 'rails_helper'

RSpec.describe McpProcessPoolService, type: :service do
  let(:service) { described_class.instance }
  let(:user) { create(:user) }
  let(:configuration) do
    create(:mcp_configuration,
      owner: user,
      server_type: 'stdio',
      server_config: {
        'command' => 'echo',
        'args' => ['test'],
        'env' => { 'TEST_VAR' => 'value' }
      }
    )
  end

  describe '#spawn_mcp_server' do
    context 'with valid configuration' do
      it 'spawns a process using Open3' do
        allow(Open3).to receive(:popen3).and_return([
          double('stdin', puts: nil),
          double('stdout', readline: '{"jsonrpc":"2.0","id":1,"result":{"capabilities":{}}}'),
          double('stderr'),
          double('wait_thread', pid: 12345)
        ])
        
        allow_any_instance_of(McpServerProcess).to receive(:tools=)
        
        process = service.spawn_mcp_server(configuration)
        
        expect(process).to be_a(McpServerProcess)
        expect(process.process_id).to eq(12345)
        expect(process.configuration_id).to eq(configuration.id)
        expect(process.user_id).to eq(user.id)
      end

      it 'extracts command, args, and env from configuration' do
        expect(Open3).to receive(:popen3).with(
          { 'TEST_VAR' => 'value' },
          'echo',
          'test'
        ).and_return([
          double('stdin', puts: nil),
          double('stdout', readline: '{"jsonrpc":"2.0","id":1,"result":{"capabilities":{}}}'),
          double('stderr'),
          double('wait_thread', pid: 12345)
        ])
        
        allow_any_instance_of(McpServerProcess).to receive(:tools=)
        
        service.spawn_mcp_server(configuration)
      end

      it 'stores process in internal hashes' do
        allow(Open3).to receive(:popen3).and_return([
          double('stdin', puts: nil),
          double('stdout', readline: '{"jsonrpc":"2.0","id":1,"result":{"capabilities":{}}}'),
          double('stderr'),
          double('wait_thread', pid: 12345)
        ])
        
        allow_any_instance_of(McpServerProcess).to receive(:tools=)
        
        process = service.spawn_mcp_server(configuration)
        
        # Access private instance variables for testing
        processes = service.instance_variable_get(:@processes)
        process_pool = service.instance_variable_get(:@process_pool)
        
        expect(processes[process.id]).to eq(process)
        expect(process_pool[process.id]).to include(:stdin, :stdout, :stderr, :wait_thread)
      end

      it 'initializes MCP protocol after spawning' do
        stdin = double('stdin')
        stdout = double('stdout')
        
        allow(Open3).to receive(:popen3).and_return([
          stdin,
          stdout,
          double('stderr'),
          double('wait_thread', pid: 12345)
        ])
        
        # Expect initialize request
        expect(stdin).to receive(:puts).with(
          hash_including(
            'jsonrpc' => '2.0',
            'method' => 'initialize',
            'id' => 1
          ).to_json
        )
        
        # Mock initialize response
        allow(stdout).to receive(:readline).and_return(
          '{"jsonrpc":"2.0","id":1,"result":{"capabilities":{"tools":{}}}}'
        )
        
        # Expect tools/list request
        expect(stdin).to receive(:puts).with(
          hash_including(
            'jsonrpc' => '2.0',
            'method' => 'tools/list',
            'id' => 2
          ).to_json
        )
        
        # Mock tools/list response
        allow(stdout).to receive(:readline).and_return(
          '{"jsonrpc":"2.0","id":2,"result":{"tools":[]}}'
        )
        
        process = service.spawn_mcp_server(configuration)
        expect(process.status).to eq('ready')
      end
    end

    context 'with invalid command' do
      let(:invalid_config) do
        create(:mcp_configuration,
          owner: user,
          server_type: 'stdio',
          server_config: {
            'command' => '/nonexistent/command'
          }
        )
      end

      it 'raises an error when command cannot be spawned' do
        allow(Open3).to receive(:popen3).and_raise(Errno::ENOENT)
        
        expect {
          service.spawn_mcp_server(invalid_config)
        }.to raise_error(Errno::ENOENT)
      end
    end

    context 'with thread safety' do
      it 'uses mutex for thread safety' do
        mutex = service.instance_variable_get(:@mutex)
        expect(mutex).to receive(:synchronize).and_yield
        
        allow(Open3).to receive(:popen3).and_return([
          double('stdin', puts: nil),
          double('stdout', readline: '{"jsonrpc":"2.0","id":1,"result":{"capabilities":{}}}'),
          double('stderr'),
          double('wait_thread', pid: 12345)
        ])
        
        allow_any_instance_of(McpServerProcess).to receive(:tools=)
        
        service.spawn_mcp_server(configuration)
      end
    end
  end

  describe '#call_tool' do
    let(:mcp_process) do
      process = McpServerProcess.new(configuration)
      process.id = 'test-process-id'
      process.status = 'ready'
      process
    end

    before do
      # Setup process in the service
      service.instance_variable_get(:@processes)[mcp_process.id] = mcp_process
      service.instance_variable_get(:@process_pool)[mcp_process.id] = {
        stdin: double('stdin'),
        stdout: double('stdout'),
        stderr: double('stderr'),
        wait_thread: double('wait_thread')
      }
    end

    it 'sends tool call request and returns response' do
      stdin = service.instance_variable_get(:@process_pool)[mcp_process.id][:stdin]
      stdout = service.instance_variable_get(:@process_pool)[mcp_process.id][:stdout]
      
      # Expect the tool call request to be sent
      expect(stdin).to receive(:puts) do |json|
        request = JSON.parse(json)
        expect(request['method']).to eq('tools/call')
        expect(request['params']['name']).to eq('test_tool')
        expect(request['params']['arguments']).to eq({ 'arg1' => 'value1' })
      end
      
      # Mock the response
      response = {
        jsonrpc: '2.0',
        id: anything,
        result: { content: [{ type: 'text', text: 'Tool executed successfully' }] }
      }
      allow(stdout).to receive(:readline).and_return(response.to_json)
      
      result = service.call_tool(mcp_process, 'test_tool', { 'arg1' => 'value1' })
      
      expect(result[:result][:content]).to eq([{ type: 'text', text: 'Tool executed successfully' }])
    end

    it 'handles tool execution errors gracefully' do
      stdin = service.instance_variable_get(:@process_pool)[mcp_process.id][:stdin]
      stdout = service.instance_variable_get(:@process_pool)[mcp_process.id][:stdout]
      
      expect(stdin).to receive(:puts)
      
      # Mock error response
      error_response = {
        jsonrpc: '2.0',
        id: anything,
        error: { code: -32601, message: 'Tool not found' }
      }
      allow(stdout).to receive(:readline).and_return(error_response.to_json)
      
      result = service.call_tool(mcp_process, 'nonexistent_tool', {})
      
      expect(result[:error]).to be_present
      expect(result[:error][:message]).to eq('Tool not found')
    end

    it 'handles exceptions during tool execution' do
      stdin = service.instance_variable_get(:@process_pool)[mcp_process.id][:stdin]
      stdout = service.instance_variable_get(:@process_pool)[mcp_process.id][:stdout]
      
      expect(stdin).to receive(:puts).and_raise(IOError, 'Broken pipe')
      
      result = service.call_tool(mcp_process, 'test_tool', {})
      
      expect(result[:error]).to be_present
      expect(result[:error][:code]).to eq(-32603)
      expect(result[:error][:message]).to include('Internal error: Broken pipe')
    end
  end

  describe 'private methods' do
    describe '#send_message' do
      let(:mcp_process) do
        process = McpServerProcess.new(configuration)
        process.id = 'test-process-id'
        process
      end

      before do
        service.instance_variable_get(:@process_pool)[mcp_process.id] = {
          stdin: double('stdin'),
          stdout: double('stdout')
        }
      end

      it 'sends message and waits for response with matching ID' do
        stdin = service.instance_variable_get(:@process_pool)[mcp_process.id][:stdin]
        stdout = service.instance_variable_get(:@process_pool)[mcp_process.id][:stdout]
        
        message = { jsonrpc: '2.0', method: 'test', id: 'test-123' }
        
        expect(stdin).to receive(:puts).with(message.to_json)
        expect(stdout).to receive(:readline).and_return(
          { jsonrpc: '2.0', id: 'test-123', result: 'success' }.to_json
        )
        
        result = service.send(:send_message, mcp_process, message)
        
        expect(result[:result]).to eq('success')
      end

      it 'raises error on timeout' do
        stdin = service.instance_variable_get(:@process_pool)[mcp_process.id][:stdin]
        stdout = service.instance_variable_get(:@process_pool)[mcp_process.id][:stdout]
        
        message = { jsonrpc: '2.0', method: 'test', id: 'test-123' }
        
        expect(stdin).to receive(:puts).with(message.to_json)
        expect(stdout).to receive(:readline) { sleep 31 } # Simulate timeout
        
        expect {
          service.send(:send_message, mcp_process, message)
        }.to raise_error('MCP request timeout')
      end

      it 'raises error on ID mismatch' do
        stdin = service.instance_variable_get(:@process_pool)[mcp_process.id][:stdin]
        stdout = service.instance_variable_get(:@process_pool)[mcp_process.id][:stdout]
        
        message = { jsonrpc: '2.0', method: 'test', id: 'test-123' }
        
        expect(stdin).to receive(:puts).with(message.to_json)
        expect(stdout).to receive(:readline).and_return(
          { jsonrpc: '2.0', id: 'wrong-id', result: 'success' }.to_json
        )
        
        expect {
          service.send(:send_message, mcp_process, message)
        }.to raise_error('Message ID mismatch')
      end
    end
  end
end