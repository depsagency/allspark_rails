# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    user_signed_in?
  end

  def show?
    user_signed_in? && (owner? || admin?)
  end

  def create?
    user_signed_in?
  end

  def new?
    create?
  end

  def update?
    user_signed_in? && (owner? || admin?)
  end

  def edit?
    update?
  end

  def destroy?
    user_signed_in? && (owner? || admin?)
  end

  # Admin-only actions
  def admin_access?
    admin?
  end

  def manage?
    admin?
  end

  protected

  # Helper methods for common authorization checks
  def user_signed_in?
    user.present?
  end

  def admin?
    user&.system_admin?
  end

  def owner?
    return false unless user_signed_in?
    return false unless record.respond_to?(:user_id) || record.respond_to?(:user)

    if record.respond_to?(:user_id)
      record.user_id == user.id
    elsif record.respond_to?(:user)
      record.user == user
    else
      false
    end
  end

  def same_user?
    record == user
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      if admin?
        scope.all
      elsif user_signed_in?
        scope.where(user: user)
      else
        scope.none
      end
    end

    protected

    def user_signed_in?
      user.present?
    end

    def admin?
      user&.system_admin?
    end

    private

    attr_reader :user, :scope
  end
end
