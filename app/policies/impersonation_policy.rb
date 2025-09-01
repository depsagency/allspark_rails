# frozen_string_literal: true

class ImpersonationPolicy < ApplicationPolicy
  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    admin?
  end

  def start?
    return false unless admin?
    return false unless @record.is_a?(User)
    return false if @record == @user # Can't impersonate yourself
    return false if @record.system_admin? # Can't impersonate other admins
    true
  end

  def stop?
    admin?
  end

  def view_audit_logs?
    admin?
  end

  private

  def admin?
    @user&.system_admin?
  end
end