# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def index?
    admin?
  end

  def show?
    same_user? || admin?
  end

  def create?
    admin?
  end

  def update?
    same_user? || admin?
  end

  def destroy?
    admin? && !same_user?
  end

  # Admin-specific actions
  def promote_to_admin?
    admin? && !same_user?
  end

  def demote_from_admin?
    admin? && !same_user? && record.system_admin?
  end

  def manage_roles?
    admin?
  end

  # Profile actions - users can always manage their own profile
  def edit_profile?
    same_user? || admin?
  end

  def change_password?
    same_user? || admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if admin?
        scope.all
      else
        scope.where(id: user.id)
      end
    end
  end
end
