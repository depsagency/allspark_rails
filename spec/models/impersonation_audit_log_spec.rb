require 'rails_helper'

RSpec.describe ImpersonationAuditLog, type: :model do
  let(:admin_user) { create(:user, role: :system_admin) }
  let(:regular_user) { create(:user, role: :default) }
  let(:request_mock) do
    double('request', 
           remote_ip: '127.0.0.1', 
           user_agent: 'Test Browser',
           session_options: { id: 'test_session_123' })
  end

  describe 'associations' do
    it 'belongs to impersonator' do
      expect(described_class.reflect_on_association(:impersonator).macro).to eq(:belongs_to)
    end

    it 'belongs to impersonated_user' do
      expect(described_class.reflect_on_association(:impersonated_user).macro).to eq(:belongs_to)
    end
  end

  describe 'validations' do
    let(:audit_log) { build(:impersonation_audit_log) }

    it 'validates presence of action' do
      audit_log.action = nil
      expect(audit_log).not_to be_valid
      expect(audit_log.errors[:action]).to include("can't be blank")
    end

    it 'validates inclusion of action in allowed values' do
      audit_log.action = 'invalid_action'
      expect(audit_log).not_to be_valid
      expect(audit_log.errors[:action]).to include("is not included in the list")
    end

    it 'validates presence of ip_address' do
      audit_log.ip_address = nil
      expect(audit_log).not_to be_valid
      expect(audit_log.errors[:ip_address]).to include("can't be blank")
    end
  end

  describe '.create_start_log' do
    it 'creates a new audit log with correct attributes' do
      log = described_class.create_start_log(
        impersonator: admin_user,
        impersonated_user: regular_user,
        request: request_mock,
        reason: 'Testing purposes'
      )

      expect(log).to be_persisted
      expect(log.impersonator).to eq(admin_user)
      expect(log.impersonated_user).to eq(regular_user)
      expect(log.action).to eq('start')
      expect(log.reason).to eq('Testing purposes')
      expect(log.ip_address).to eq('127.0.0.1')
      expect(log.user_agent).to eq('Test Browser')
      expect(log.session_id).to eq('test_session_123')
      expect(log.started_at).to be_present
    end
  end

  describe '#end_impersonation!' do
    let(:audit_log) { create(:impersonation_audit_log, ended_at: nil) }

    it 'sets ended_at timestamp' do
      expect { audit_log.end_impersonation! }.to change { audit_log.ended_at }.from(nil)
    end

    it 'does not update if already ended' do
      audit_log.update!(ended_at: 1.hour.ago)
      original_ended_at = audit_log.ended_at
      
      audit_log.end_impersonation!
      
      expect(audit_log.reload.ended_at).to eq(original_ended_at)
    end

    it 'updates metadata with end reason and duration' do
      audit_log.end_impersonation!(reason: 'timeout')
      
      expect(audit_log.metadata['end_reason']).to eq('timeout')
      expect(audit_log.metadata['duration']).to be_present
    end
  end

  describe '#active?' do
    it 'returns true when ended_at is nil' do
      log = build(:impersonation_audit_log, ended_at: nil)
      expect(log).to be_active
    end

    it 'returns false when ended_at is present' do
      log = build(:impersonation_audit_log, ended_at: Time.current)
      expect(log).not_to be_active
    end
  end

  describe '#duration_in_words' do
    it 'returns "Active" for active sessions' do
      log = build(:impersonation_audit_log, ended_at: nil)
      expect(log.duration_in_words).to eq('Active')
    end

    it 'returns seconds for short durations' do
      log = build(:impersonation_audit_log, 
                  started_at: 30.seconds.ago, 
                  ended_at: Time.current)
      expect(log.duration_in_words).to match(/\d+ seconds/)
    end

    it 'returns minutes for medium durations' do
      log = build(:impersonation_audit_log, 
                  started_at: 5.minutes.ago, 
                  ended_at: Time.current)
      expect(log.duration_in_words).to match(/\d+ minutes/)
    end

    it 'returns hours for long durations' do
      log = build(:impersonation_audit_log, 
                  started_at: 2.hours.ago, 
                  ended_at: Time.current)
      expect(log.duration_in_words).to match(/\d+ hours/)
    end
  end
end
