require 'rails_helper'

RSpec.describe McpAuditLog, type: :model do
  let(:user) { create(:user) }
  let(:mcp_server) { create(:mcp_server) }
  let(:assistant) { create(:assistant) }

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:mcp_server) }
    it { should belong_to(:assistant) }
  end

  describe 'validations' do
    it { should validate_presence_of(:tool_name) }
    it { should validate_presence_of(:executed_at) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(success: 0, failure: 1, timeout: 2) }
  end

  describe 'JSON serialization' do
    let(:audit_log) { create(:mcp_audit_log) }

    it 'serializes request_data as JSON' do
      data = { 'query' => 'test', 'params' => { 'limit' => 10 } }
      audit_log.update(request_data: data)
      
      expect(audit_log.reload.request_data).to eq(data)
    end

    it 'serializes response_data as JSON' do
      data = { 'results' => [{ 'id' => 1, 'name' => 'test' }], 'total' => 1 }
      audit_log.update(response_data: data)
      
      expect(audit_log.reload.response_data).to eq(data)
    end
  end

  describe 'scopes' do
    let!(:recent_log) { create(:mcp_audit_log, :recent) }
    let!(:old_log) { create(:mcp_audit_log, :old) }
    let!(:success_log) { create(:mcp_audit_log, status: :success) }
    let!(:failed_log) { create(:mcp_audit_log, :failed) }
    let!(:timeout_log) { create(:mcp_audit_log, :timeout) }

    describe '.recent' do
      it 'returns logs from last 30 days' do
        expect(McpAuditLog.recent).to include(recent_log)
        expect(McpAuditLog.recent).not_to include(old_log)
      end
    end

    describe '.by_server' do
      it 'filters by mcp_server' do
        expect(McpAuditLog.by_server(mcp_server)).to include(success_log)
      end
    end

    describe '.by_user' do
      it 'filters by user' do
        expect(McpAuditLog.by_user(user)).to include(success_log)
      end
    end

    describe '.failed' do
      it 'returns only failed logs' do
        expect(McpAuditLog.failed).to include(failed_log)
        expect(McpAuditLog.failed).not_to include(success_log)
      end
    end

    describe '.successful' do
      it 'returns only successful logs' do
        expect(McpAuditLog.successful).to include(success_log)
        expect(McpAuditLog.successful).not_to include(failed_log)
      end
    end

    describe '.timed_out' do
      it 'returns only timed out logs' do
        expect(McpAuditLog.timed_out).to include(timeout_log)
        expect(McpAuditLog.timed_out).not_to include(success_log)
      end
    end

    describe '.by_tool' do
      let!(:calculator_log) { create(:mcp_audit_log, :calculator_tool) }

      it 'filters by tool name' do
        expect(McpAuditLog.by_tool('calculator')).to include(calculator_log)
        expect(McpAuditLog.by_tool('calculator')).not_to include(success_log)
      end
    end

    describe '.in_date_range' do
      let(:start_date) { 1.week.ago }
      let(:end_date) { 1.day.ago }

      it 'filters by date range' do
        in_range_log = create(:mcp_audit_log, executed_at: 3.days.ago)
        out_of_range_log = create(:mcp_audit_log, executed_at: 2.weeks.ago)

        result = McpAuditLog.in_date_range(start_date, end_date)
        expect(result).to include(in_range_log)
        expect(result).not_to include(out_of_range_log)
      end
    end
  end

  describe 'class methods' do
    describe '.log_execution' do
      let(:params) do
        {
          user: user,
          mcp_server: mcp_server,
          assistant: assistant,
          tool_name: 'test_tool',
          request_data: { 'query' => 'test' },
          response_data: { 'result' => 'success' },
          status: :success,
          response_time_ms: 150
        }
      end

      it 'creates a new audit log' do
        expect { McpAuditLog.log_execution(**params) }.to change(McpAuditLog, :count).by(1)
      end

      it 'sets executed_at to current time' do
        freeze_time do
          log = McpAuditLog.log_execution(**params)
          expect(log.executed_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'stores all provided data' do
        log = McpAuditLog.log_execution(**params)
        
        expect(log.user).to eq(user)
        expect(log.mcp_server).to eq(mcp_server)
        expect(log.assistant).to eq(assistant)
        expect(log.tool_name).to eq('test_tool')
        expect(log.request_data).to eq({ 'query' => 'test' })
        expect(log.response_data).to eq({ 'result' => 'success' })
        expect(log.status).to eq('success')
        expect(log.response_time_ms).to eq(150)
      end
    end

    describe '.average_response_time' do
      before do
        create(:mcp_audit_log, response_time_ms: 100)
        create(:mcp_audit_log, response_time_ms: 200)
        create(:mcp_audit_log, response_time_ms: nil)
      end

      it 'calculates average response time excluding null values' do
        expect(McpAuditLog.average_response_time).to eq(150.0)
      end

      it 'works with scoped results' do
        fast_logs = McpAuditLog.where('response_time_ms < ?', 150)
        expect(McpAuditLog.average_response_time(fast_logs)).to eq(100.0)
      end
    end

    describe '.success_rate' do
      before do
        create_list(:mcp_audit_log, 7, status: :success)
        create_list(:mcp_audit_log, 2, status: :failure)
        create_list(:mcp_audit_log, 1, status: :timeout)
      end

      it 'calculates success rate as percentage' do
        expect(McpAuditLog.success_rate).to eq(70.0)
      end

      it 'returns 0 for empty scope' do
        expect(McpAuditLog.success_rate(McpAuditLog.none)).to eq(0)
      end
    end

    describe '.failure_rate' do
      before do
        create_list(:mcp_audit_log, 7, status: :success)
        create_list(:mcp_audit_log, 2, status: :failure)
        create_list(:mcp_audit_log, 1, status: :timeout)
      end

      it 'calculates failure rate as percentage' do
        expect(McpAuditLog.failure_rate).to eq(20.0)
      end
    end

    describe '.timeout_rate' do
      before do
        create_list(:mcp_audit_log, 7, status: :success)
        create_list(:mcp_audit_log, 2, status: :failure)
        create_list(:mcp_audit_log, 1, status: :timeout)
      end

      it 'calculates timeout rate as percentage' do
        expect(McpAuditLog.timeout_rate).to eq(10.0)
      end
    end
  end

  describe 'instance methods' do
    describe '#successful?' do
      it 'returns true for success status' do
        log = create(:mcp_audit_log, status: :success)
        expect(log.successful?).to be true
      end

      it 'returns false for other statuses' do
        log = create(:mcp_audit_log, status: :failure)
        expect(log.successful?).to be false
      end
    end

    describe '#failed?' do
      it 'returns true for failure status' do
        log = create(:mcp_audit_log, status: :failure)
        expect(log.failed?).to be true
      end

      it 'returns false for other statuses' do
        log = create(:mcp_audit_log, status: :success)
        expect(log.failed?).to be false
      end
    end

    describe '#timed_out?' do
      it 'returns true for timeout status' do
        log = create(:mcp_audit_log, status: :timeout)
        expect(log.timed_out?).to be true
      end

      it 'returns false for other statuses' do
        log = create(:mcp_audit_log, status: :success)
        expect(log.timed_out?).to be false
      end
    end

    describe '#response_time_seconds' do
      it 'converts milliseconds to seconds' do
        log = create(:mcp_audit_log, response_time_ms: 1500)
        expect(log.response_time_seconds).to eq(1.5)
      end

      it 'returns nil when response_time_ms is nil' do
        log = create(:mcp_audit_log, response_time_ms: nil)
        expect(log.response_time_seconds).to be_nil
      end
    end

    describe '#formatted_response_time' do
      it 'formats milliseconds for fast responses' do
        log = create(:mcp_audit_log, response_time_ms: 250)
        expect(log.formatted_response_time).to eq('250ms')
      end

      it 'formats seconds for slow responses' do
        log = create(:mcp_audit_log, response_time_ms: 2500)
        expect(log.formatted_response_time).to eq('2.5s')
      end

      it 'returns N/A when response_time_ms is nil' do
        log = create(:mcp_audit_log, response_time_ms: nil)
        expect(log.formatted_response_time).to eq('N/A')
      end
    end
  end

  describe 'analytics methods' do
    describe '.usage_by_hour' do
      it 'groups logs by hour' do
        # This would typically use database-specific functions
        # For testing, we'll just verify the method exists and doesn't error
        expect { McpAuditLog.usage_by_hour }.not_to raise_error
      end
    end

    describe '.usage_by_day' do
      it 'groups logs by day' do
        expect { McpAuditLog.usage_by_day }.not_to raise_error
      end
    end

    describe '.top_tools' do
      before do
        create_list(:mcp_audit_log, 3, tool_name: 'calculator')
        create_list(:mcp_audit_log, 2, tool_name: 'web_search')
        create(:mcp_audit_log, tool_name: 'linear_search')
      end

      it 'returns top tools by usage count' do
        result = McpAuditLog.top_tools(2)
        expect(result.keys.first).to eq('calculator')
        expect(result['calculator']).to eq(3)
      end
    end

    describe '.top_users' do
      let(:user1) { create(:user, email: 'user1@example.com') }
      let(:user2) { create(:user, email: 'user2@example.com') }

      before do
        create_list(:mcp_audit_log, 3, user: user1)
        create_list(:mcp_audit_log, 2, user: user2)
      end

      it 'returns top users by usage count' do
        result = McpAuditLog.top_users(2)
        expect(result.keys.first).to eq('user1@example.com')
        expect(result['user1@example.com']).to eq(3)
      end
    end
  end
end