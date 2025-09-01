# frozen_string_literal: true

# Helper methods for ActionCable channel specs
module ChannelHelpers
  def stub_connection(identifiers = {})
    connection = ActionCable::Channel::TestCase::StubConnection.new(identifiers)
    allow(connection).to receive(:logger).and_return(Rails.logger)
    connection
  end

  def create_user_connection(user = nil)
    user ||= create(:user)
    stub_connection(current_user: user)
  end

  def create_admin_connection
    admin = create(:user, :admin)
    stub_connection(current_user: admin)
  end

  def expect_subscription_confirmed
    expect(subscription).to be_confirmed
  end

  def expect_subscription_rejected
    expect(subscription).to be_rejected
  end

  def expect_broadcast(stream_name, data = nil)
    if data
      expect { yield }.to have_broadcasted_to(stream_name).with(data)
    else
      expect { yield }.to have_broadcasted_to(stream_name)
    end
  end

  def expect_no_broadcast(stream_name)
    expect { yield }.not_to have_broadcasted_to(stream_name)
  end

  def perform_action(action, data = {})
    subscription.perform(action, data)
  end

  def expect_transmitted(data = nil)
    if data
      expect(subscription).to have_transmitted(data)
    else
      expect(subscription).to have_transmitted
    end
  end

  def expect_stream_from(stream_name)
    expect(subscription).to have_stream_from(stream_name)
  end

  def expect_stream_stopped(stream_name)
    expect(subscription).to have_stopped_stream_from(stream_name)
  end

  # Notification channel helpers
  def expect_notification_broadcast(user, notification_data)
    stream_name = "user_#{user.id}_notifications"
    expect_broadcast(stream_name) do
      yield
    end
  end

  def simulate_notification_action(action, data = {})
    case action
    when 'mark_as_read'
      perform_action('mark_as_read', { 'notification_id' => data[:notification_id] })
    when 'mark_all_as_read'
      perform_action('mark_all_as_read')
    when 'get_recent_notifications'
      perform_action('get_recent_notifications', { 'limit' => data[:limit] || 20 })
    end
  end

  # Presence channel helpers
  def expect_presence_broadcast(event_type, user_data = nil)
    stream_name = 'presence'
    expected_data = { type: event_type }
    expected_data[:user] = user_data if user_data

    expect_broadcast(stream_name, hash_including(expected_data))
  end

  def simulate_presence_action(action, data = {})
    case action
    when 'update_activity'
      perform_action('update_activity', { 'activity' => data[:activity] })
    when 'update_status'
      perform_action('update_status', { 'status_message' => data[:status_message] })
    when 'start_typing'
      perform_action('start_typing', { 'context' => data[:context] })
    when 'stop_typing'
      perform_action('stop_typing', { 'context' => data[:context] })
    end
  end

  # Live updates channel helpers
  def expect_resource_update_broadcast(resource)
    resource_type = resource.class.name.underscore
    stream_name = "#{resource_type}_#{resource.id}_updates"
    expect_broadcast(stream_name)
  end

  def expect_model_update_broadcast(model_class)
    model_name = model_class.name.underscore.pluralize
    stream_name = "#{model_name}_updates"
    expect_broadcast(stream_name)
  end

  def simulate_live_update_action(action, data = {})
    case action
    when 'follow_resource'
      perform_action('follow_resource', {
        'resource_type' => data[:resource_type],
        'resource_id' => data[:resource_id]
      })
    when 'unfollow_resource'
      perform_action('unfollow_resource', {
        'resource_type' => data[:resource_type],
        'resource_id' => data[:resource_id]
      })
    when 'follow_model'
      perform_action('follow_model', { 'model_type' => data[:model_type] })
    when 'unfollow_model'
      perform_action('unfollow_model', { 'model_type' => data[:model_type] })
    when 'update_cursor_position'
      perform_action('update_cursor_position', {
        'resource_type' => data[:resource_type],
        'resource_id' => data[:resource_id],
        'position' => data[:position]
      })
    when 'update_selection'
      perform_action('update_selection', {
        'resource_type' => data[:resource_type],
        'resource_id' => data[:resource_id],
        'selection' => data[:selection]
      })
    end
  end

  # Helper for testing broadcasts with LiveUpdatesBroadcaster
  def expect_live_broadcaster_call(method, *args)
    expect(LiveUpdatesBroadcaster).to receive(method).with(*args)
  end

  # Timing helpers for real-time features
  def wait_for_broadcast
    sleep 0.1 # Give ActionCable time to process
  end

  def with_real_actioncable
    original_adapter = ActionCable.server.config.cable[:adapter]
    ActionCable.server.config.cable = { adapter: 'async' }
    yield
  ensure
    ActionCable.server.config.cable = { adapter: original_adapter }
  end
end
