# frozen_string_literal: true

# Test helpers for MCP Bridge testing
module McpTestHelpers
  # Create a test MCP configuration
  def create_test_mcp_configuration(owner:, **options)
    defaults = {
      name: 'Test MCP Server',
      server_type: 'stdio',
      enabled: true,
      server_config: {
        'command' => 'echo',
        'args' => ['test'],
        'env' => { 'TEST_MODE' => 'true' }
      }
    }
    
    McpConfiguration.create!(
      owner: owner,
      **defaults.merge(options)
    )
  end
  
  # Create a mock MCP server process
  def create_mock_mcp_process(configuration, status: 'ready')
    process = McpServerProcess.new(configuration)
    process.status = status
    process.process_id = 12345
    process.tools = [
      { 'name' => 'test_tool', 'description' => 'A test tool' }
    ]
    process
  end
  
  # Mock Open3 for process spawning
  def mock_open3_spawn(stdin_responses: [], stdout_responses: [], stderr_responses: [])
    stdin = double('stdin')
    stdout = double('stdout')
    stderr = double('stderr')
    wait_thread = double('wait_thread', pid: 12345, alive?: true, value: double(exitstatus: 0))
    
    # Setup stdin
    stdin_responses.each do |response|
      allow(stdin).to receive(:puts).with(response[:input]) if response[:input]
    end
    allow(stdin).to receive(:puts)
    allow(stdin).to receive(:close)
    allow(stdin).to receive(:closed?).and_return(false)
    
    # Setup stdout
    stdout_queue = stdout_responses.dup
    allow(stdout).to receive(:readline) do
      response = stdout_queue.shift
      raise EOFError if response.nil?
      response
    end
    allow(stdout).to receive(:close)
    allow(stdout).to receive(:closed?).and_return(false)
    
    # Setup stderr
    allow(stderr).to receive(:close)
    allow(stderr).to receive(:closed?).and_return(false)
    
    allow(Open3).to receive(:popen3).and_return([stdin, stdout, stderr, wait_thread])
    
    { stdin: stdin, stdout: stdout, stderr: stderr, wait_thread: wait_thread }
  end
  
  # Create standard JSON-RPC responses
  def json_rpc_response(id:, result: nil, error: nil)
    response = { jsonrpc: '2.0', id: id }
    
    if error
      response[:error] = error
    else
      response[:result] = result
    end
    
    response.to_json
  end
  
  def initialize_response(id: 1)
    json_rpc_response(
      id: id,
      result: {
        protocolVersion: '2024-11-05',
        capabilities: { tools: {} },
        serverInfo: { name: 'test-server', version: '1.0.0' }
      }
    )
  end
  
  def tools_list_response(id: 2, tools: [])
    json_rpc_response(
      id: id,
      result: { tools: tools }
    )
  end
  
  def tool_call_response(id:, content: 'Success')
    json_rpc_response(
      id: id,
      result: {
        content: [{ type: 'text', text: content }]
      }
    )
  end
  
  def error_response(id:, code: -32601, message: 'Method not found')
    json_rpc_response(
      id: id,
      error: { code: code, message: message }
    )
  end
end

# Include in RSpec
RSpec.configure do |config|
  config.include McpTestHelpers
end