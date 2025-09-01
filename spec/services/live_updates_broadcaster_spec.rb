# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LiveUpdatesBroadcaster, type: :service do
  include_examples 'with actioncable test adapter'

  let(:user) { create(:user) }
  let(:notification) { create(:notification, user: user) }

  describe '.broadcast_resource_update' do
    it 'broadcasts to resource-specific stream' do
      expect {
        described_class.broadcast_resource_update(notification, user: user)
      }.to have_broadcasted_to("notification_#{notification.id}_updates")
    end

    it 'broadcasts to global model stream' do
      expect {
        described_class.broadcast_resource_update(notification, user: user)
      }.to have_broadcasted_to('notifications_updates')
    end

    it 'includes resource data in broadcast' do
      expect {
        described_class.broadcast_resource_update(notification, user: user)
      }.to have_broadcasted_to("notification_#{notification.id}_updates").with(
        hash_including(
          type: 'resource_updated',
          resource_type: 'notification',
          resource_id: notification.id,
          resource_data: hash_including(id: notification.id)
        )
      )
    end

    it 'includes user data when provided' do
      expect {
        described_class.broadcast_resource_update(notification, user: user)
      }.to have_broadcasted_to("notification_#{notification.id}_updates").with(
        hash_including(
          user: hash_including(
            id: user.id,
            name: user.full_name,
            email: user.email
          )
        )
      )
    end

    it 'includes changes when provided' do
      changes = { 'title' => [ 'Old Title', 'New Title' ] }

      expect {
        described_class.broadcast_resource_update(notification, changes: changes, user: user)
      }.to have_broadcasted_to("notification_#{notification.id}_updates").with(
        hash_including(changes: changes)
      )
    end

    it 'accepts custom action' do
      expect {
        described_class.broadcast_resource_update(notification, action: :custom_action, user: user)
      }.to have_broadcasted_to("notification_#{notification.id}_updates").with(
        hash_including(type: 'resource_custom_action')
      )
    end
  end

  describe '.broadcast_resource_created' do
    it 'broadcasts resource creation' do
      expect {
        described_class.broadcast_resource_created(notification, user: user)
      }.to have_broadcasted_to("notification_#{notification.id}_updates").with(
        hash_including(type: 'resource_created')
      )
    end
  end

  describe '.broadcast_resource_deleted' do
    it 'broadcasts resource deletion' do
      expect {
        described_class.broadcast_resource_deleted(notification, user: user)
      }.to have_broadcasted_to("notification_#{notification.id}_updates").with(
        hash_including(
          type: 'resource_deleted',
          resource_id: notification.id
        )
      )
    end

    it 'does not include full resource data for deleted resources' do
      expect {
        described_class.broadcast_resource_deleted(notification, user: user)
      }.to have_broadcasted_to("notification_#{notification.id}_updates").with(
        hash_not_including(:resource_data)
      )
    end
  end

  describe '.broadcast_notification' do
    it 'broadcasts to user notification stream' do
      expect {
        described_class.broadcast_notification(notification)
      }.to have_broadcasted_to("user_#{user.id}_notifications")
    end

    it 'includes notification data and unread count' do
      create(:notification, user: user, read_at: nil) # Additional unread

      expect {
        described_class.broadcast_notification(notification)
      }.to have_broadcasted_to("user_#{user.id}_notifications").with(
        hash_including(
          type: 'new_notification',
          notification: hash_including(id: notification.id),
          unread_count: 2
        )
      )
    end

    it 'does not broadcast when notification has no user' do
      notification.update!(user: nil)

      expect {
        described_class.broadcast_notification(notification)
      }.not_to have_broadcasted_to(anything)
    end
  end

  describe '.broadcast_user_update' do
    let(:data) { { type: 'test_update', message: 'Test message' } }

    it 'broadcasts to user-specific stream' do
      expect {
        described_class.broadcast_user_update(user, data)
      }.to have_broadcasted_to("user_#{user.id}_updates")
    end

    it 'includes user data and timestamp' do
      expect {
        described_class.broadcast_user_update(user, data)
      }.to have_broadcasted_to("user_#{user.id}_updates").with(
        hash_including(
          type: 'user_update',
          data: data,
          timestamp: kind_of(String)
        )
      )
    end
  end

  describe '.broadcast_system_announcement' do
    let(:title) { 'System Maintenance' }
    let(:message) { 'The system will be down for maintenance.' }

    it 'broadcasts to system announcements stream' do
      expect {
        described_class.broadcast_system_announcement(title: title, message: message)
      }.to have_broadcasted_to('system_announcements')
    end

    it 'includes announcement data' do
      expect {
        described_class.broadcast_system_announcement(
          title: title,
          message: message,
          type: 'warning'
        )
      }.to have_broadcasted_to('system_announcements').with(
        hash_including(
          type: 'system_announcement',
          title: title,
          message: message,
          announcement_type: 'warning'
        )
      )
    end
  end

  describe '.broadcast_bulk_operation' do
    it 'broadcasts bulk operation result to user' do
      expect {
        described_class.broadcast_bulk_operation(
          user: user,
          operation: 'delete',
          resource_type: 'notification',
          count: 5
        )
      }.to have_broadcasted_to("user_#{user.id}_updates").with(
        hash_including(
          data: hash_including(
            type: 'bulk_operation_complete',
            operation: 'delete',
            resource_type: 'notification',
            count: 5,
            success: true
          )
        )
      )
    end
  end

  describe '.broadcast_metrics_update' do
    let(:metrics_data) { { total_users: 100, active_users: 75 } }

    context 'with specific users' do
      let(:users) { create_list(:user, 2, :admin) }

      it 'broadcasts to specified users' do
        users.each do |admin_user|
          expect {
            described_class.broadcast_metrics_update(users: users, data: metrics_data)
          }.to have_broadcasted_to("user_#{admin_user.id}_updates")
        end
      end
    end

    context 'without specific users' do
      let!(:admin_users) { create_list(:user, 2, :admin) }
      let!(:regular_users) { create_list(:user, 2) }

      it 'broadcasts to all admin users' do
        admin_users.each do |admin_user|
          expect {
            described_class.broadcast_metrics_update(data: metrics_data)
          }.to have_broadcasted_to("user_#{admin_user.id}_updates")
        end
      end

      it 'does not broadcast to regular users' do
        regular_users.each do |regular_user|
          expect {
            described_class.broadcast_metrics_update(data: metrics_data)
          }.not_to have_broadcasted_to("user_#{regular_user.id}_updates")
        end
      end
    end
  end

  describe '.broadcast_progress_update' do
    it 'broadcasts progress update to user' do
      expect {
        described_class.broadcast_progress_update(
          user: user,
          operation_id: 'test_op_123',
          progress: 50,
          message: 'Processing...'
        )
      }.to have_broadcasted_to("user_#{user.id}_updates").with(
        hash_including(
          data: hash_including(
            type: 'progress_update',
            operation_id: 'test_op_123',
            progress: 50,
            message: 'Processing...'
          )
        )
      )
    end
  end

  describe '.broadcast_upload_progress' do
    it 'broadcasts upload progress to user' do
      expect {
        described_class.broadcast_upload_progress(
          user: user,
          upload_id: 'upload_456',
          progress: 75,
          filename: 'document.pdf'
        )
      }.to have_broadcasted_to("user_#{user.id}_updates").with(
        hash_including(
          data: hash_including(
            type: 'upload_progress',
            upload_id: 'upload_456',
            progress: 75,
            filename: 'document.pdf'
          )
        )
      )
    end
  end

  describe '.broadcast_search_results' do
    let(:search_results) { [ { id: 1, title: 'Result 1' } ] }

    it 'broadcasts search results to user' do
      expect {
        described_class.broadcast_search_results(
          user: user,
          query: 'test query',
          results: search_results,
          search_id: 'search_789'
        )
      }.to have_broadcasted_to("user_#{user.id}_updates").with(
        hash_including(
          data: hash_including(
            type: 'search_results',
            query: 'test query',
            results: search_results,
            search_id: 'search_789'
          )
        )
      )
    end
  end

  describe 'private methods' do
    describe '#should_broadcast?' do
      it 'returns true for valid resources in non-test environment' do
        allow(Rails.env).to receive(:test?).and_return(false)

        result = described_class.send(:should_broadcast?, notification)
        expect(result).to be true
      end

      it 'returns false for nil resources' do
        result = described_class.send(:should_broadcast?, nil)
        expect(result).to be false
      end

      it 'respects skip_broadcasting? method if defined' do
        allow(notification).to receive(:skip_broadcasting?).and_return(true)

        result = described_class.send(:should_broadcast?, notification)
        expect(result).to be false
      end
    end

    describe '#serialize_resource' do
      context 'when resource responds to as_live_update_json' do
        before do
          allow(notification).to receive(:as_live_update_json).and_return({ custom: 'data' })
        end

        it 'uses custom serialization method' do
          result = described_class.send(:serialize_resource, notification)
          expect(result).to eq({ custom: 'data' })
        end
      end

      context 'when resource responds to as_json' do
        it 'uses as_json with safe attributes' do
          result = described_class.send(:serialize_resource, notification)
          expect(result).to include(:id, :title, :message)
        end
      end
    end

    describe '#serialize_user' do
      it 'returns nil for nil user' do
        result = described_class.send(:serialize_user, nil)
        expect(result).to be_nil
      end

      it 'serializes user data' do
        user_with_avatar = create(:user, :with_avatar)
        result = described_class.send(:serialize_user, user_with_avatar)

        expect(result).to include(
          id: user_with_avatar.id,
          name: user_with_avatar.full_name,
          email: user_with_avatar.email,
          role: user_with_avatar.role
        )
        expect(result[:avatar_url]).to be_present
      end
    end
  end
end
