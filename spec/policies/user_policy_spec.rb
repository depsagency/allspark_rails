# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserPolicy, type: :policy do
  include_examples 'a pundit policy'

  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  subject { described_class }

  describe '#index?' do
    it 'allows admin users' do
      expect(subject).to permit(admin, User)
    end

    it 'denies regular users' do
      expect(subject).not_to permit(user, User)
    end
  end

  describe '#show?' do
    it 'allows admin users to view any user' do
      expect(subject).to permit(admin, other_user)
    end

    it 'allows users to view themselves' do
      expect(subject).to permit(user, user)
    end

    it 'denies users from viewing other users' do
      expect(subject).not_to permit(user, other_user)
    end
  end

  describe '#create?' do
    it 'allows admin users' do
      expect(subject).to permit(admin, User)
    end

    it 'denies regular users' do
      expect(subject).not_to permit(user, User)
    end
  end

  describe '#update?' do
    it 'allows admin users to update any user' do
      expect(subject).to permit(admin, other_user)
    end

    it 'allows users to update themselves' do
      expect(subject).to permit(user, user)
    end

    it 'denies users from updating other users' do
      expect(subject).not_to permit(user, other_user)
    end
  end

  describe '#destroy?' do
    it 'allows admin users to destroy other users' do
      expect(subject).to permit(admin, other_user)
    end

    it 'denies admin users from destroying themselves' do
      expect(subject).not_to permit(admin, admin)
    end

    it 'denies regular users from destroying anyone' do
      expect(subject).not_to permit(user, other_user)
      expect(subject).not_to permit(user, user)
    end
  end

  describe '#manage_roles?' do
    it 'allows admin users' do
      expect(subject).to permit(admin, other_user)
    end

    it 'denies regular users' do
      expect(subject).not_to permit(user, other_user)
    end

    it 'denies users from managing their own roles' do
      expect(subject).not_to permit(user, user)
    end
  end

  describe 'scope' do
    let!(:admin_user) { create(:user, :admin) }
    let!(:regular_users) { create_list(:user, 3) }

    context 'when user is admin' do
      it 'returns all users' do
        scope = UserPolicy::Scope.new(admin_user, User).resolve
        expect(scope).to include(admin_user, *regular_users)
      end
    end

    context 'when user is regular user' do
      it 'returns only the user themselves' do
        scope = UserPolicy::Scope.new(user, User).resolve
        expect(scope).to eq([ user ])
      end
    end
  end

  describe 'permitted_attributes' do
    context 'for admin users' do
      it 'allows all user attributes including role' do
        policy = described_class.new(admin, user)
        attributes = policy.permitted_attributes

        expect(attributes).to include(
          :first_name, :last_name, :email, :password,
          :password_confirmation, :role
        )
      end
    end

    context 'for regular users updating themselves' do
      it 'allows basic attributes but not role' do
        policy = described_class.new(user, user)
        attributes = policy.permitted_attributes

        expect(attributes).to include(
          :first_name, :last_name, :email, :password,
          :password_confirmation
        )
        expect(attributes).not_to include(:role)
      end
    end

    context 'for regular users updating others' do
      it 'returns empty array' do
        policy = described_class.new(user, other_user)
        attributes = policy.permitted_attributes

        expect(attributes).to be_empty
      end
    end
  end

  describe 'custom policy methods' do
    describe '#can_impersonate?' do
      it 'allows admin to impersonate other users' do
        policy = described_class.new(admin, user)
        expect(policy.can_impersonate?).to be true
      end

      it 'denies admin from impersonating themselves' do
        policy = described_class.new(admin, admin)
        expect(policy.can_impersonate?).to be false
      end

      it 'denies regular users from impersonating anyone' do
        policy = described_class.new(user, other_user)
        expect(policy.can_impersonate?).to be false
      end
    end

    describe '#can_reset_password?' do
      it 'allows admin to reset any user password' do
        policy = described_class.new(admin, user)
        expect(policy.can_reset_password?).to be true
      end

      it 'allows users to reset their own password' do
        policy = described_class.new(user, user)
        expect(policy.can_reset_password?).to be true
      end

      it 'denies users from resetting other passwords' do
        policy = described_class.new(user, other_user)
        expect(policy.can_reset_password?).to be false
      end
    end

    describe '#can_view_admin_panel?' do
      it 'allows admin users' do
        policy = described_class.new(admin, user)
        expect(policy.can_view_admin_panel?).to be true
      end

      it 'denies regular users' do
        policy = described_class.new(user, user)
        expect(policy.can_view_admin_panel?).to be false
      end
    end
  end
end
