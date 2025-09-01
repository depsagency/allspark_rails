# frozen_string_literal: true

require 'rails_helper'

RSpec.describe McpServerProcess, type: :model do
  let(:user) { create(:user) }
  let(:configuration) do
    create(:mcp_configuration,
      owner: user,
      server_config: {
        'command' => 'test',
        'max_restarts' => 3
      }
    )
  end
  let(:process) { described_class.new(configuration) }

  describe '#initialize' do
    it 'generates a unique ID' do
      expect(process.id).to be_present
      expect(process.id).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
    end

    it 'sets initial status to starting' do
      expect(process.status).to eq('starting')
    end

    it 'captures configuration details' do
      expect(process.configuration).to eq(configuration)
      expect(process.configuration_id).to eq(configuration.id)
      expect(process.user_id).to eq(user.id)
    end

    it 'initializes timestamps' do
      expect(process.last_activity).to be_within(1.second).of(Time.current)
      expect(process.start_time).to be_within(1.second).of(Time.current)
    end

    it 'initializes restart count to 0' do
      expect(process.restart_count).to eq(0)
    end

    it 'initializes empty capabilities and tools' do
      expect(process.capabilities).to eq({})
      expect(process.tools).to eq([])
    end
  end

  describe 'status methods' do
    it '#running? returns true for starting and ready states' do
      process.status = 'starting'
      expect(process.running?).to be true
      
      process.status = 'ready'
      expect(process.running?).to be true
      
      process.status = 'error'
      expect(process.running?).to be false
    end

    it '#ready? returns true only for ready state' do
      process.status = 'starting'
      expect(process.ready?).to be false
      
      process.status = 'ready'
      expect(process.ready?).to be true
    end

    it '#error? returns true only for error state' do
      process.status = 'ready'
      expect(process.error?).to be false
      
      process.status = 'error'
      expect(process.error?).to be true
    end

    it '#stopped? returns true for stopping and stopped states' do
      process.status = 'ready'
      expect(process.stopped?).to be false
      
      process.status = 'stopping'
      expect(process.stopped?).to be true
      
      process.status = 'stopped'
      expect(process.stopped?).to be true
    end
  end

  describe '#update_status' do
    it 'allows valid status transitions' do
      process.status = 'starting'
      
      expect { process.update_status('ready') }.not_to raise_error
      expect(process.status).to eq('ready')
      
      expect { process.update_status('error') }.not_to raise_error
      expect(process.status).to eq('error')
    end

    it 'rejects invalid status transitions' do
      process.status = 'stopped'
      
      expect { process.update_status('ready') }.to raise_error(ArgumentError, /Invalid status transition/)
    end

    it 'rejects invalid status values' do
      expect { process.update_status('invalid') }.to raise_error(ArgumentError, /Invalid status/)
    end

    it 'updates last_activity on status change' do
      old_activity = process.last_activity
      sleep 0.1
      
      process.update_status('ready')
      
      expect(process.last_activity).to be > old_activity
    end

    it 'logs status changes' do
      expect(Rails.logger).to receive(:info).with(/Status changed from starting to ready/)
      process.update_status('ready')
    end
  end

  describe '#increment_restart_count' do
    it 'increments the restart count' do
      expect { process.increment_restart_count }.to change { process.restart_count }.from(0).to(1)
      expect { process.increment_restart_count }.to change { process.restart_count }.from(1).to(2)
    end
  end

  describe '#exceeded_restart_limit?' do
    it 'returns false when under the limit' do
      process.restart_count = 2
      expect(process.exceeded_restart_limit?).to be false
    end

    it 'returns true when at or over the limit' do
      process.restart_count = 3
      expect(process.exceeded_restart_limit?).to be true
      
      process.restart_count = 4
      expect(process.exceeded_restart_limit?).to be true
    end

    it 'uses default limit of 3 when not configured' do
      configuration.server_config.delete('max_restarts')
      process.restart_count = 3
      expect(process.exceeded_restart_limit?).to be true
    end
  end

  describe '#age_in_seconds' do
    it 'returns time since last activity' do
      process.last_activity = 5.seconds.ago
      expect(process.age_in_seconds).to be_within(0.1).of(5)
    end
  end

  describe '#uptime_in_seconds' do
    it 'returns time since process start' do
      process.start_time = 10.seconds.ago
      expect(process.uptime_in_seconds).to be_within(0.1).of(10)
    end
  end

  describe '#stale?' do
    it 'returns true when no activity for longer than threshold' do
      process.last_activity = 6.minutes.ago
      expect(process.stale?(300)).to be true
    end

    it 'returns false when activity is recent' do
      process.last_activity = 1.minute.ago
      expect(process.stale?(300)).to be false
    end

    it 'uses default threshold of 300 seconds' do
      process.last_activity = 6.minutes.ago
      expect(process.stale?).to be true
    end
  end

  describe '#close_io_streams' do
    let(:stdin) { double('stdin', close: nil, closed?: false) }
    let(:stdout) { double('stdout', close: nil, closed?: false) }
    let(:stderr) { double('stderr', close: nil, closed?: false) }

    before do
      process.stdin = stdin
      process.stdout = stdout
      process.stderr = stderr
    end

    it 'closes all IO streams' do
      expect(stdin).to receive(:close)
      expect(stdout).to receive(:close)
      expect(stderr).to receive(:close)
      
      process.close_io_streams
    end

    it 'handles already closed streams' do
      allow(stdin).to receive(:closed?).and_return(true)
      expect(stdin).not_to receive(:close)
      
      process.close_io_streams
    end

    it 'handles IO errors gracefully' do
      allow(stdout).to receive(:close).and_raise(IOError, 'Already closed')
      expect(Rails.logger).to receive(:warn).with(/Error closing stream/)
      
      expect { process.close_io_streams }.not_to raise_error
    end
  end

  describe '#to_h' do
    before do
      process.process_id = 12345
      process.status = 'ready'
      process.restart_count = 1
      process.tools = [{ 'name' => 'tool1' }, { 'name' => 'tool2' }]
    end

    it 'returns process information as a hash' do
      hash = process.to_h
      
      expect(hash[:id]).to eq(process.id)
      expect(hash[:user_id]).to eq(user.id)
      expect(hash[:configuration_id]).to eq(configuration.id)
      expect(hash[:process_id]).to eq(12345)
      expect(hash[:status]).to eq('ready')
      expect(hash[:restart_count]).to eq(1)
      expect(hash[:tools_count]).to eq(2)
      expect(hash[:age_seconds]).to be >= 0
      expect(hash[:uptime_seconds]).to be >= 0
    end
  end

  describe '#process_alive?' do
    context 'with no process_id' do
      it 'returns false' do
        process.process_id = nil
        expect(process.process_alive?).to be false
      end
    end

    context 'with valid process_id' do
      before { process.process_id = Process.pid }

      it 'returns true for running process' do
        expect(process.process_alive?).to be true
      end

      it 'returns false for non-existent process' do
        process.process_id = 999999
        expect(process.process_alive?).to be false
      end
    end
  end

  describe '#wait_for_exit' do
    let(:wait_thread) { double('wait_thread') }

    before { process.wait_thread = wait_thread }

    it 'waits for thread without timeout' do
      allow(wait_thread).to receive(:alive?).and_return(true)
      expect(wait_thread).to receive(:join).with(no_args)
      
      process.wait_for_exit
    end

    it 'waits for thread with timeout' do
      allow(wait_thread).to receive(:alive?).and_return(true)
      expect(wait_thread).to receive(:join).with(5)
      
      process.wait_for_exit(5)
    end

    it 'returns immediately if thread is not alive' do
      allow(wait_thread).to receive(:alive?).and_return(false)
      expect(wait_thread).not_to receive(:join)
      
      process.wait_for_exit
    end
  end

  describe '#exit_status' do
    let(:wait_thread) { double('wait_thread') }

    before { process.wait_thread = wait_thread }

    it 'returns exit status for completed process' do
      allow(wait_thread).to receive(:alive?).and_return(false)
      allow(wait_thread).to receive(:value).and_return(double(exitstatus: 0))
      
      expect(process.exit_status).to eq(0)
    end

    it 'returns nil for running process' do
      allow(wait_thread).to receive(:alive?).and_return(true)
      
      expect(process.exit_status).to be_nil
    end

    it 'returns nil when no wait_thread' do
      process.wait_thread = nil
      expect(process.exit_status).to be_nil
    end
  end
end