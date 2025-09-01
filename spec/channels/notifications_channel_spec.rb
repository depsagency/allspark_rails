# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NotificationsChannel, type: :channel do
  include_examples 'an actioncable channel'

  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  describe '#subscribed' do
    context 'with authenticated user' do
      before do
        stub_connection current_user: user
      end

      it 'confirms subscription' do
        subscribe
        expect_subscription_confirmed
      end

      it 'streams from user notifications' do
        subscribe
        expect_stream_from("user_#{user.id}_notifications")
      end

      it 'transmits current unread count' do
        create_list(:notification, 3, user: user, read_at: nil)
        create(:notification, user: user, read_at: 1.hour.ago)

        subscribe
        expect_transmitted(hash_including(type: 'unread_count', count: 3))
      end

      context 'when user is admin' do
        before do
          stub_connection current_user: admin
        end

        it 'streams from system announcements' do
          subscribe
          expect_stream_from('system_announcements')
        end
      end

      context 'when user is not admin' do
        it 'does not stream from system announcements' do
          subscribe
          expect(subscription).not_to have_stream_from('system_announcements')
        end
      end
    end

    context 'without authenticated user' do
      before do
        stub_connection
      end

      it 'rejects subscription' do
        subscribe
        expect_subscription_rejected
      end
    end
  end

  describe '#unsubscribed' do
    before do
      stub_connection current_user: user
      subscribe
    end

    it 'logs unsubscription' do
      expect(Rails.logger).to receive(:info).with(/unsubscribed/)
      unsubscribe
    end
  end

  describe '#mark_as_read' do
    let!(:notification) { create(:notification, user: user, read_at: nil) }

    before do
      stub_connection current_user: user
      subscribe
    end

    context 'with valid notification id' do
      it 'marks notification as read' do
        expect {
          perform_action('mark_as_read', 'notification_id' => notification.id)
        }.to change { notification.reload.read? }.from(false).to(true)
      end

      it 'transmits confirmation' do
        perform_action('mark_as_read', 'notification_id' => notification.id)

        expect_transmitted(hash_including(
          type: 'marked_as_read',
          notification_id: notification.id
        ))
      end
    end

    context 'with invalid notification id' do
      it 'does not transmit anything' do
        perform_action('mark_as_read', 'notification_id' => 'invalid')

        expect(subscription).not_to have_transmitted
      end
    end

    context 'with notification belonging to another user' do
      let(:other_notification) { create(:notification) }

      it 'does not mark notification as read' do
        expect {
          perform_action('mark_as_read', 'notification_id' => other_notification.id)
        }.not_to change { other_notification.reload.read_at }
      end
    end
  end

  describe '#mark_all_as_read' do
    before do
      create_list(:notification, 3, user: user, read_at: nil)
      stub_connection current_user: user
      subscribe
    end

    it 'marks all user notifications as read' do
      expect {
        perform_action('mark_all_as_read')
      }.to change { user.notifications.unread.count }.from(3).to(0)
    end

    it 'transmits confirmation' do
      perform_action('mark_all_as_read')

      expect_transmitted(hash_including(
        type: 'all_marked_as_read',
        unread_count: 0
      ))
    end
  end

  describe '#get_recent_notifications' do
    before do
      create_list(:notification, 15, user: user)
      stub_connection current_user: user
      subscribe
    end

    it 'transmits recent notifications with default limit' do
      perform_action('get_recent_notifications')

      expect_transmitted(hash_including(
        type: 'recent_notifications',
        notifications: array_of_size(15)
      ))
    end

    it 'respects custom limit' do
      perform_action('get_recent_notifications', 'limit' => 5)

      expect_transmitted(hash_including(
        type: 'recent_notifications',
        notifications: array_of_size(5)
      ))
    end

    it 'enforces maximum limit of 50' do
      perform_action('get_recent_notifications', 'limit' => 100)

      expect_transmitted(hash_including(
        type: 'recent_notifications',
        notifications: array_of_size(15) # Only 15 notifications exist
      ))
    end

    it 'includes notification data' do
      notification = user.notifications.first
      perform_action('get_recent_notifications', 'limit' => 1)

      expect_transmitted(hash_including(
        type: 'recent_notifications',
        notifications: array_including(
          hash_including(
            id: notification.id,
            title: notification.title,
            message: notification.message,
            type: notification.notification_type
          )
        )
      ))
    end
  end

  describe 'broadcasting integration' do
    before do
      stub_connection current_user: user
      subscribe
    end

    it 'receives broadcasts when notifications are created' do
      expect_notification_broadcast(user) do
        create(:notification, user: user)
      end
    end

    it 'receives broadcasts when notifications are updated' do
      notification = create(:notification, user: user, read_at: nil)

      expect_notification_broadcast(user) do
        notification.update!(read_at: Time.current)
      end
    end
  end

  describe 'serialization' do
    let(:sender) { create(:user, :with_avatar) }
    let(:notification) do
      create(:notification,
             user: user,
             sender: sender,
             title: 'Test Notification',
             message: 'Test message',
             notification_type: 'info',
             action_url: 'http://example.com',
             metadata: { key: 'value' })
    end

    before do
      stub_connection current_user: user
      subscribe
    end

    it 'includes all notification data in serialization' do
      perform_action('get_recent_notifications', 'limit' => 1)

      expect_transmitted(hash_including(
        notifications: array_including(
          hash_including(
            id: notification.id,
            title: 'Test Notification',
            message: 'Test message',
            type: 'info',
            action_url: 'http://example.com',
            metadata: { 'key' => 'value' },
            sender: hash_including(
              id: sender.id,
              name: sender.full_name
            )
          )
        )
      ))
    end
  end
end
