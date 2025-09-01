# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notification, type: :model do
  include_examples 'a model with uuid primary key'
  include_examples 'a model with timestamps'
  include_examples 'a live updates model'

  describe 'associations' do
    include_examples 'belongs to', :user

    it { should belong_to(:sender).class_name('User').optional }
  end

  describe 'validations' do
    include_examples 'validates presence of', :title, :message, :notification_type

    it { should validate_length_of(:title).is_at_most(255) }
    it { should validate_length_of(:message).is_at_most(1000) }
    it { should validate_numericality_of(:priority).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:priority).is_less_than_or_equal_to(10) }
  end

  describe 'enums' do
    it 'defines notification_type enum' do
      expect(described_class.notification_types.keys).to include(
        'info', 'success', 'warning', 'error', 'system', 'mention',
        'follow', 'like', 'comment', 'message', 'task_assigned',
        'task_completed', 'deadline_reminder', 'system_maintenance',
        'security_alert'
      )
    end
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let!(:read_notification) { create(:notification, user: user, read_at: 1.hour.ago) }
    let!(:unread_notification) { create(:notification, user: user, read_at: nil) }
    let!(:expired_notification) { create(:notification, user: user, expires_at: 1.hour.ago) }

    describe '.unread' do
      it 'returns unread notifications' do
        expect(Notification.unread).to include(unread_notification)
        expect(Notification.unread).not_to include(read_notification)
      end
    end

    describe '.read' do
      it 'returns read notifications' do
        expect(Notification.read).to include(read_notification)
        expect(Notification.read).not_to include(unread_notification)
      end
    end

    describe '.recent' do
      it 'orders by created_at desc' do
        expect(Notification.recent.first).to eq(expired_notification)
      end
    end

    describe '.unexpired' do
      it 'excludes expired notifications' do
        expect(Notification.unexpired).not_to include(expired_notification)
        expect(Notification.unexpired).to include(unread_notification)
      end
    end

    describe '.for_user' do
      let(:other_user) { create(:user) }
      let!(:other_notification) { create(:notification, user: other_user) }

      it 'returns notifications for specific user' do
        expect(Notification.for_user(user)).to include(read_notification, unread_notification)
        expect(Notification.for_user(user)).not_to include(other_notification)
      end
    end

    describe '.of_type' do
      let!(:success_notification) { create(:notification, notification_type: 'success') }
      let!(:error_notification) { create(:notification, notification_type: 'error') }

      it 'returns notifications of specific type' do
        expect(Notification.of_type('success')).to include(success_notification)
        expect(Notification.of_type('success')).not_to include(error_notification)
      end
    end
  end

  describe 'callbacks' do
    it 'broadcasts notification after create' do
      user = create(:user)
      expect(LiveUpdatesBroadcaster).to receive(:broadcast_resource_created)
      create(:notification, user: user)
    end

    it 'sets delivered_at before save' do
      notification = build(:notification, delivered_at: nil)
      notification.save!
      expect(notification.delivered_at).to be_present
    end
  end

  describe 'class methods' do
    describe '.create_and_deliver!' do
      let(:user) { create(:user) }

      it 'creates and delivers notification' do
        notification = Notification.create_and_deliver!(
          user: user,
          title: 'Test',
          message: 'Test message'
        )

        expect(notification).to be_persisted
        expect(notification.delivered_at).to be_present
      end
    end

    describe '.create_for_users' do
      let(:users) { create_list(:user, 3) }

      it 'creates notifications for multiple users' do
        notifications = Notification.create_for_users(
          users,
          title: 'Bulk notification',
          message: 'This is a bulk notification'
        )

        expect(notifications.count).to eq(3)
        expect(notifications.map(&:user)).to match_array(users)
      end
    end

    describe '.create_system_announcement' do
      let!(:users) { create_list(:user, 2) }

      it 'creates system notifications for all users' do
        expect {
          Notification.create_system_announcement(
            title: 'Maintenance',
            message: 'System will be down for maintenance'
          )
        }.to change(Notification, :count).by(2)

        announcements = Notification.where(notification_type: 'system')
        expect(announcements.all?(&:persistent?)).to be true
        expect(announcements.map(&:priority).uniq).to eq([ 8 ])
      end
    end

    describe '.cleanup_expired' do
      let!(:expired_notifications) { create_list(:notification, 2, expires_at: 1.hour.ago) }
      let!(:valid_notification) { create(:notification, expires_at: 1.hour.from_now) }

      it 'removes expired notifications' do
        count = Notification.cleanup_expired
        expect(count).to eq(2)
        expect(Notification.exists?(expired_notifications.first.id)).to be false
        expect(Notification.exists?(valid_notification.id)).to be true
      end
    end

    describe '.mark_old_as_read' do
      let!(:old_notifications) { create_list(:notification, 2, created_at: 35.days.ago, read_at: nil) }
      let!(:recent_notification) { create(:notification, created_at: 1.day.ago, read_at: nil) }

      it 'marks old unread notifications as read' do
        count = Notification.mark_old_as_read(older_than: 30.days.ago)
        expect(count).to eq(2)

        old_notifications.each(&:reload)
        expect(old_notifications.all?(&:read?)).to be true
        expect(recent_notification.reload.read?).to be false
      end
    end
  end

  describe 'instance methods' do
    let(:notification) { create(:notification) }

    describe '#read?' do
      context 'when read_at is present' do
        before { notification.update!(read_at: Time.current) }

        it 'returns true' do
          expect(notification.read?).to be true
        end
      end

      context 'when read_at is nil' do
        before { notification.update!(read_at: nil) }

        it 'returns false' do
          expect(notification.read?).to be false
        end
      end
    end

    describe '#unread?' do
      it 'is opposite of read?' do
        expect(notification.unread?).to eq(!notification.read?)
      end
    end

    describe '#expired?' do
      context 'when expires_at is in the past' do
        before { notification.update!(expires_at: 1.hour.ago) }

        it 'returns true' do
          expect(notification.expired?).to be true
        end
      end

      context 'when expires_at is in the future' do
        before { notification.update!(expires_at: 1.hour.from_now) }

        it 'returns false' do
          expect(notification.expired?).to be false
        end
      end

      context 'when expires_at is nil' do
        before { notification.update!(expires_at: nil) }

        it 'returns false' do
          expect(notification.expired?).to be false
        end
      end
    end

    describe '#mark_as_read!' do
      let(:unread_notification) { create(:notification, read_at: nil) }

      it 'sets read_at timestamp' do
        expect {
          unread_notification.mark_as_read!
        }.to change(unread_notification, :read_at).from(nil)
      end

      it 'does not change already read notification' do
        read_notification = create(:notification, read_at: 1.hour.ago)
        original_read_at = read_notification.read_at

        read_notification.mark_as_read!
        expect(read_notification.read_at).to eq(original_read_at)
      end
    end

    describe '#mark_as_unread!' do
      let(:read_notification) { create(:notification, read_at: 1.hour.ago) }

      it 'clears read_at timestamp' do
        expect {
          read_notification.mark_as_unread!
        }.to change(read_notification, :read_at).to(nil)
      end
    end

    describe '#deliver_now' do
      let(:notification) { build(:notification, delivered_at: nil) }

      it 'sets delivered_at timestamp' do
        notification.save!
        notification.update!(delivered_at: nil) # Reset after creation callback

        expect {
          notification.deliver_now
        }.to change(notification, :delivered_at).from(nil)
      end

      it 'broadcasts notification' do
        notification.save!
        expect(LiveUpdatesBroadcaster).to receive(:broadcast_notification)
        notification.deliver_now
      end
    end

    describe '#icon' do
      it 'returns appropriate icon for notification type' do
        notification = build(:notification, notification_type: 'success')
        expect(notification.icon).to eq('✅')

        notification = build(:notification, notification_type: 'error')
        expect(notification.icon).to eq('❌')

        notification = build(:notification, notification_type: 'warning')
        expect(notification.icon).to eq('⚠️')
      end
    end

    describe '#color_class' do
      it 'returns appropriate color class for notification type' do
        notification = build(:notification, notification_type: 'success')
        expect(notification.color_class).to eq('text-success')

        notification = build(:notification, notification_type: 'error')
        expect(notification.color_class).to eq('text-error')

        notification = build(:notification, notification_type: 'warning')
        expect(notification.color_class).to eq('text-warning')
      end
    end

    describe '#time_ago' do
      it 'returns human readable time ago for recent notifications' do
        notification = create(:notification, created_at: 1.hour.ago)
        expect(notification.time_ago).to include('hour')
        expect(notification.time_ago).to include('ago')
      end

      it 'returns formatted date for old notifications' do
        notification = create(:notification, created_at: 2.days.ago)
        expect(notification.time_ago).to match(/\d{2}\/\d{2}\/\d{4}/)
      end
    end
  end

  describe 'broadcasting' do
    let(:user) { create(:user) }

    context 'on create' do
      it 'broadcasts new notification' do
        expect(ActionCable.server).to receive(:broadcast).with(
          "user_#{user.id}_notifications",
          hash_including(type: 'new_notification')
        )

        create(:notification, user: user)
      end
    end

    context 'on update' do
      let!(:notification) { create(:notification, user: user, read_at: nil) }

      it 'broadcasts update when read status changes' do
        expect(ActionCable.server).to receive(:broadcast).with(
          "user_#{user.id}_notifications",
          hash_including(type: 'notification_updated')
        )

        notification.update!(read_at: Time.current)
      end
    end
  end
end
