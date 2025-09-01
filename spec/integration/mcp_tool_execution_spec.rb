require 'rails_helper'

RSpec.describe "MCP Tool Execution Integration", type: :integration do
  let(:user) { create(:user) }
  let(:assistant) { create(:assistant, user: user) }
  let(:server) { create(:mcp_server, :active, user: user) }
  let(:client) { McpClient.new(server) }

  describe "Tool discovery" do
    it "successfully discovers tools from server" do
      mock_successful_tool_discovery(server, default_mock_tools)
      
      events = capture_mcp_notifications do
        tools = client.discover_tools
        
        expect(tools).to have(2).items
        expect(tools.first['name']).to eq('linear_search')
        expect(tools.last['name']).to eq('linear_create_issue')
      end

      expect(events).to include(
        hash_including(
          name: McpInstrumentation::EVENTS[:tool_discovery]
        )
      )
    end

    it "handles empty tool lists" do
      mock_successful_tool_discovery(server, [])
      
      tools = client.discover_tools
      expect(tools).to be_empty
    end

    it "handles tool discovery failures" do
      mock_failed_tool_discovery(server, "Server unreachable")
      
      errors = capture_mcp_errors do
        tools = client.discover_tools
        expect(tools).to be_empty
      end

      expect(errors).to include(
        hash_including(
          error: an_instance_of(McpConnection::Base::ConnectionError)
        )
      )
    end

    it "caches discovered tools" do
      mock_successful_tool_discovery(server, default_mock_tools)
      
      # First call should hit the server
      tools1 = server.available_tools
      
      # Second call should use cache
      expect(Rails.cache).to receive(:fetch).with("mcp_server_#{server.id}_tools", expires_in: 5.minutes).and_call_original
      tools2 = server.available_tools
      
      expect(tools1).to eq(tools2)
    end
  end

  describe "Tool execution" do
    it "successfully executes a tool" do
      mock_successful_tool_execution(server, 'linear_search', default_search_result)
      
      events = capture_mcp_notifications do
        result = client.call_tool('linear_search', { query: 'test', limit: 5 }, user: user, assistant: assistant)
        
        expect(result[:success]).to be true
        expect(result[:content]).to be_present
      end

      expect(events).to include(
        hash_including(
          name: McpInstrumentation::EVENTS[:tool_execution]
        )
      )
    end

    it "logs tool execution in audit log" do
      mock_successful_tool_execution(server, 'linear_search', default_search_result)
      
      expect {
        client.call_tool('linear_search', { query: 'test' }, user: user, assistant: assistant)
      }.to change(McpAuditLog, :count).by(1)
      
      audit_log = McpAuditLog.last
      expect(audit_log.user).to eq(user)
      expect(audit_log.mcp_server).to eq(server)
      expect(audit_log.assistant).to eq(assistant)
      expect(audit_log.tool_name).to eq('linear_search')
      expect(audit_log.status).to eq('success')
    end

    it "handles tool execution failures" do
      mock_failed_tool_execution(server, 'linear_search', "Tool not found")
      
      errors = capture_mcp_errors do
        result = client.call_tool('linear_search', { query: 'test' }, user: user, assistant: assistant)
        expect(result[:error]).to be_present
      end

      expect(errors).to include(
        hash_including(
          error: an_instance_of(McpConnection::Base::ProtocolError)
        )
      )
    end

    it "logs failed executions in audit log" do
      mock_failed_tool_execution(server, 'linear_search', "Tool not found")
      
      expect {
        client.call_tool('linear_search', { query: 'test' }, user: user, assistant: assistant)
      }.to change(McpAuditLog, :count).by(1)
      
      audit_log = McpAuditLog.last
      expect(audit_log.status).to eq('failure')
      expect(audit_log.response_data['error']).to include('Tool not found')
    end

    it "tracks execution performance" do
      mock_successful_tool_execution(server, 'linear_search', default_search_result)
      
      client.call_tool('linear_search', { query: 'test' }, user: user, assistant: assistant)
      
      instrumentation = McpInstrumentation.instance
      metrics = instrumentation.get_metrics("tool_execution_duration_#{server.id}_linear_search", 1.minute)
      
      expect(metrics[:count]).to be > 0
      expect(metrics[:avg]).to be > 0
    end

    it "handles timeout errors" do
      simulate_connection_timeout(server)
      
      result = client.call_tool('linear_search', { query: 'test' }, user: user, assistant: assistant)
      
      expect(result[:error]).to include('timed out')
      
      # Should log as timeout in audit log
      audit_log = McpAuditLog.last
      expect(audit_log.status).to eq('timeout')
    end

    it "handles large responses efficiently" do
      large_data = "x" * (50 * 1024) # 50KB of data
      large_result = { "data" => large_data }
      
      mock_successful_tool_execution(server, 'linear_search', large_result)
      
      result = client.call_tool('linear_search', { query: 'test' }, user: user, assistant: assistant)
      
      expect(result[:success]).to be true
      expect(result[:content]).to include(large_data)
    end
  end

  describe "Tool integration with Assistant" do
    let(:assistant_with_mcp) do
      create(:assistant, user: user, tools: [{ 'type' => 'mcp_tools' }])
    end

    before do
      mock_successful_tool_discovery(server, default_mock_tools)
    end

    it "loads MCP tools in assistant" do
      tools = assistant_with_mcp.send(:configured_tools)
      mcp_tools = tools.select { |t| t.is_a?(Agents::Tools::McpTool) }
      
      expect(mcp_tools).to have(2).items
      expect(mcp_tools.map(&:name)).to include('mcp_linear_search', 'mcp_linear_create_issue')
    end

    it "executes MCP tools through assistant" do
      mock_successful_tool_execution(server, 'linear_search', default_search_result)
      
      # Get MCP tool instance
      tools = assistant_with_mcp.send(:configured_tools)
      search_tool = tools.find { |t| t.name == 'mcp_linear_search' }
      
      expect(search_tool).to be_present
      
      result = search_tool.execute(query: 'test', limit: 5)
      
      expect(result[:success]).to be true
      expect(result[:tool_name]).to eq('linear_search')
      expect(result[:server]).to eq(server.name)
    end

    it "handles tool execution errors gracefully" do
      mock_failed_tool_execution(server, 'linear_search', "API error")
      
      tools = assistant_with_mcp.send(:configured_tools)
      search_tool = tools.find { |t| t.name == 'mcp_linear_search' }
      
      result = search_tool.execute(query: 'test')
      
      expect(result[:error]).to include('API error')
      expect(result[:tool_name]).to eq('linear_search')
    end

    it "filters tools by server availability" do
      # Create an inactive server
      inactive_server = create(:mcp_server, :inactive, user: user)
      
      tools = assistant_with_mcp.send(:configured_tools)
      mcp_tools = tools.select { |t| t.is_a?(Agents::Tools::McpTool) }
      
      # Should only load tools from active servers
      server_ids = mcp_tools.map { |t| t.instance_variable_get(:@mcp_server).id }
      expect(server_ids).to include(server.id)
      expect(server_ids).not_to include(inactive_server.id)
    end
  end

  describe "Multi-tenant tool access" do
    let(:instance) { create(:instance) }
    let(:other_user) { create(:user) }
    let(:instance_server) { create(:mcp_server, :instance_scoped, :active, instance: instance) }
    let(:other_user_server) { create(:mcp_server, :user_scoped, :active, user: other_user) }

    before do
      user.instances << instance
      mock_successful_tool_discovery(instance_server, default_mock_tools)
      mock_successful_tool_discovery(other_user_server, default_mock_tools)
    end

    it "allows access to instance servers for instance users" do
      assistant_in_instance = create(:assistant, user: user, tools: [{ 'type' => 'mcp_tools' }])
      
      # Mock current user context
      assistant_in_instance.instance_variable_set(:@current_user, user)
      
      servers = assistant_in_instance.send(:available_mcp_servers)
      expect(servers).to include(instance_server)
    end

    it "prevents access to other users' servers" do
      assistant_with_mcp = create(:assistant, user: user, tools: [{ 'type' => 'mcp_tools' }])
      assistant_with_mcp.instance_variable_set(:@current_user, user)
      
      servers = assistant_with_mcp.send(:available_mcp_servers)
      expect(servers).not_to include(other_user_server)
    end

    it "includes system-wide servers for all users" do
      system_server = create(:mcp_server, :system_wide, :active)
      mock_successful_tool_discovery(system_server, default_mock_tools)
      
      assistant_with_mcp = create(:assistant, user: user, tools: [{ 'type' => 'mcp_tools' }])
      assistant_with_mcp.instance_variable_set(:@current_user, user)
      
      servers = assistant_with_mcp.send(:available_mcp_servers)
      expect(servers).to include(system_server)
    end
  end

  describe "Tool schema validation" do
    before do
      mock_successful_tool_discovery(server, default_mock_tools)
    end

    it "provides tool schema information" do
      schema = client.get_tool_schema('linear_search')
      
      expect(schema).to be_present
      expect(schema[:name]).to eq('linear_search')
      expect(schema[:description]).to include('Search Linear issues')
      expect(schema[:parameters]['properties']).to have_key('query')
    end

    it "returns nil for unknown tools" do
      schema = client.get_tool_schema('unknown_tool')
      expect(schema).to be_nil
    end

    it "validates tool parameters in MCP tool" do
      tools = assistant.send(:configured_tools)
      assistant.tools = [{ 'type' => 'mcp_tools' }]
      assistant.instance_variable_set(:@current_user, user)
      
      mcp_tools = assistant.send(:load_mcp_tools)
      search_tool = mcp_tools.find { |t| t.instance_variable_get(:@tool_name) == 'linear_search' }
      
      expect(search_tool).to be_present
      
      # Tool should have schema information
      expect(search_tool.instance_variable_get(:@tool_schema)).to be_present
    end
  end

  describe "Performance and reliability" do
    it "handles concurrent tool executions" do
      mock_successful_tool_execution(server, 'linear_search', default_search_result)
      
      threads = []
      results = []
      
      10.times do
        threads << Thread.new do
          result = client.call_tool('linear_search', { query: "test#{Thread.current.object_id}" }, user: user, assistant: assistant)
          results << result
        end
      end
      
      threads.each(&:join)
      
      expect(results).to have(10).items
      expect(results.all? { |r| r[:success] }).to be true
    end

    it "maintains performance under load" do
      mock_successful_tool_execution(server, 'linear_search', default_search_result)
      
      start_time = Time.current
      
      20.times do |i|
        client.call_tool('linear_search', { query: "test#{i}" }, user: user, assistant: assistant)
      end
      
      total_time = Time.current - start_time
      
      # Should complete 20 calls in reasonable time (under 5 seconds in test)
      expect(total_time).to be < 5.seconds
    end

    it "cleans up resources properly" do
      mock_successful_tool_execution(server, 'linear_search', default_search_result)
      
      initial_connections = McpConnectionManager.instance.pool_status[:total_connections]
      
      10.times do
        client.call_tool('linear_search', { query: 'test' }, user: user, assistant: assistant)
      end
      
      # Connection count should not grow indefinitely
      final_connections = McpConnectionManager.instance.pool_status[:total_connections]
      expect(final_connections - initial_connections).to be <= 1
    end
  end
end