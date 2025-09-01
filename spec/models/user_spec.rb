# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  include_examples 'a model with uuid primary key'
  include_examples 'a model with timestamps'

  describe 'associations' do
    include_examples 'has many', :notifications, :sent_notifications
    include_examples 'has one', :avatar_attachment
  end

  describe 'validations' do
    subject { build(:user) }

    include_examples 'validates presence of', :email
    include_examples 'validates uniqueness of', :email

    it { should validate_presence_of(:password) }
    it { should validate_length_of(:password).is_at_least(6) }
  end

  describe 'enums' do
    it { should define_enum_for(:role).with_values(default: 0, system_admin: 1) }
  end

  describe 'impersonation methods' do
    let(:admin_user) { create(:user, :admin) }
    let(:regular_user) { create(:user) }
    let(:another_admin) { create(:user, :admin) }

    describe '#can_impersonate?' do
      context 'when user is an admin' do
        it 'returns true for regular users' do
          expect(admin_user.can_impersonate?(regular_user)).to be true
        end

        it 'returns false for other admins' do
          expect(admin_user.can_impersonate?(another_admin)).to be false
        end

        it 'returns false for self' do
          expect(admin_user.can_impersonate?(admin_user)).to be false
        end
      end

      context 'when user is not an admin' do
        it 'returns false for any user' do
          expect(regular_user.can_impersonate?(admin_user)).to be false
          expect(regular_user.can_impersonate?(regular_user)).to be false
        end
      end
    end

    describe '#being_impersonated?' do
      it 'returns true when there is an active impersonation session' do
        create(:impersonation_audit_log, impersonated_user: regular_user, ended_at: nil)
        expect(regular_user.being_impersonated?).to be true
      end

      it 'returns false when there are no active impersonation sessions' do
        create(:impersonation_audit_log, impersonated_user: regular_user, ended_at: Time.current)
        expect(regular_user.being_impersonated?).to be false
      end

      it 'returns false when there are no impersonation sessions' do
        expect(regular_user.being_impersonated?).to be false
      end
    end

    describe '#current_impersonator' do
      it 'returns the impersonator when being impersonated' do
        log = create(:impersonation_audit_log, 
                     impersonator: admin_user,
                     impersonated_user: regular_user, 
                     ended_at: nil)
        expect(regular_user.current_impersonator).to eq(admin_user)
      end

      it 'returns nil when not being impersonated' do
        expect(regular_user.current_impersonator).to be_nil
      end
    end

    describe '#active_impersonation_log' do
      it 'returns the active impersonation log' do
        log = create(:impersonation_audit_log, 
                     impersonated_user: regular_user, 
                     ended_at: nil)
        expect(regular_user.active_impersonation_log).to eq(log)
      end

      it 'returns nil when not being impersonated' do
        expect(regular_user.active_impersonation_log).to be_nil
      end
    end
  end

  describe 'callbacks' do
    it 'sets default role on initialization' do
      user = User.new
      expect(user.role).to eq('default')
    end
  end

  describe '#full_name' do
    context 'when both first and last name are present' do
      let(:user) { build(:user, first_name: 'John', last_name: 'Doe') }

      it 'returns the full name' do
        expect(user.full_name).to eq('John Doe')
      end
    end

    context 'when only first name is present' do
      let(:user) { build(:user, first_name: 'John', last_name: nil) }

      it 'returns the first name' do
        expect(user.full_name).to eq('John')
      end
    end

    context 'when neither name is present' do
      let(:user) { build(:user, first_name: nil, last_name: nil) }

      it 'returns nil' do
        expect(user.full_name).to be_nil
      end
    end
  end

  describe '#display_name' do
    context 'when full name is available' do
      let(:user) { build(:user, first_name: 'John', last_name: 'Doe') }

      it 'returns the full name' do
        expect(user.display_name).to eq('John Doe')
      end
    end

    context 'when full name is not available' do
      let(:user) { build(:user, first_name: nil, last_name: nil) }

      it 'returns the email' do
        expect(user.display_name).to eq(user.email)
      end
    end
  end

  describe '#admin?' do
    context 'when user is system admin' do
      let(:user) { build(:user, :admin) }

      it 'returns true' do
        expect(user.admin?).to be true
      end
    end

    context 'when user is not admin' do
      let(:user) { build(:user) }

      it 'returns false' do
        expect(user.admin?).to be false
      end
    end
  end

  describe '#can_access_admin?' do
    it 'is an alias for admin?' do
      user = build(:user, :admin)
      expect(user.can_access_admin?).to eq(user.admin?)
    end
  end

  describe '#role_name' do
    it 'returns humanized role name' do
      user = build(:user, role: :system_admin)
      expect(user.role_name).to eq('System admin')
    end
  end

  describe 'notification methods' do
    let(:user) { create(:user) }

    describe '#notify!' do
      it 'creates a notification for the user' do
        expect {
          user.notify!(title: 'Test', message: 'Test message')
        }.to change(user.notifications, :count).by(1)
      end

      it 'accepts notification type' do
        notification = user.notify!(
          title: 'Test',
          message: 'Test message',
          type: 'success'
        )
        expect(notification.notification_type).to eq('success')
      end
    end

    describe '#send_notification' do
      it 'creates and delivers a notification' do
        expect {
          user.send_notification(title: 'Test', message: 'Test message')
        }.to change(user.notifications, :count).by(1)
      end

      it 'marks notification as delivered' do
        notification = user.send_notification(title: 'Test', message: 'Test message')
        expect(notification.delivered_at).to be_present
      end
    end

    describe '#unread_notifications_count' do
      before do
        create(:notification, user: user, read_at: nil)
        create(:notification, user: user, read_at: nil)
        create(:notification, user: user, read_at: 1.hour.ago)
      end

      it 'returns count of unread notifications' do
        expect(user.unread_notifications_count).to eq(2)
      end
    end

    describe '#mark_all_notifications_read!' do
      before do
        create_list(:notification, 3, user: user, read_at: nil)
      end

      it 'marks all notifications as read' do
        expect {
          user.mark_all_notifications_read!
        }.to change { user.notifications.unread.count }.from(3).to(0)
      end
    end
  end

  describe 'avatar attachment' do
    let(:user) { create(:user, :with_avatar) }

    it 'can have an avatar attached' do
      expect(user.avatar).to be_attached
    end
  end

  describe 'devise modules' do
    it 'includes database_authenticatable' do
      expect(User.devise_modules).to include(:database_authenticatable)
    end

    it 'includes registerable' do
      expect(User.devise_modules).to include(:registerable)
    end

    it 'includes recoverable' do
      expect(User.devise_modules).to include(:recoverable)
    end

    it 'includes rememberable' do
      expect(User.devise_modules).to include(:rememberable)
    end

    it 'includes validatable' do
      expect(User.devise_modules).to include(:validatable)
    end
  end
end
