# frozen_string_literal: true

class Admin::ImpersonationController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :set_user, only: [:start]

  # GET /admin/impersonation
  def index
    authorize :impersonation, :index?
    
    @audit_logs = ImpersonationAuditLog.includes(:impersonator, :impersonated_user)
                                      .recent
                                      .page(params[:page])
                                      .per(25)
    
    # Filter by status if requested
    @audit_logs = @audit_logs.active if params[:status] == 'active'
  end

  # POST /admin/impersonation/start
  def start
    authorize @user, :start?, policy_class: ImpersonationPolicy
    
    # End any existing impersonation sessions for this user
    end_existing_impersonation(@user)

    # Create audit log
    @audit_log = ImpersonationAuditLog.create_start_log(
      impersonator: current_user,
      impersonated_user: @user,
      request: request,
      reason: params[:reason]
    )

    # Store impersonation data in session
    session[:impersonation] = {
      original_user_id: current_user.id,
      impersonated_user_id: @user.id,
      audit_log_id: @audit_log.id,
      started_at: Time.current.to_i,
      ip_address: request.remote_ip
    }

    # Impersonation is now active via session data
    # current_user method will return the impersonated user
    flash[:notice] = "You are now impersonating #{@user.display_name}"
    redirect_to root_path
  end

  # DELETE /admin/impersonation/stop
  def stop
    authorize :impersonation, :stop?
    
    if impersonating?
      end_impersonation_session(reason: params[:reason] || 'manual')
      flash[:notice] = 'Impersonation ended successfully'
      redirect_to admin_impersonation_index_path
    else
      flash[:alert] = 'You are not currently impersonating anyone'
      redirect_to root_path
    end
  end

  private

  def set_user
    @user = User.find(params[:user_id])
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = 'User not found'
    redirect_to admin_impersonation_index_path
  end


  def end_existing_impersonation(user)
    # End any active impersonation sessions for this user
    user.impersonated_audit_logs.active.each do |log|
      log.end_impersonation!(reason: 'new_session_started')
    end
  end

  def impersonating?
    session[:impersonation].present?
  end

  def end_impersonation_session(reason: 'manual')
    return unless session[:impersonation]

    # Find and end the audit log
    if session[:impersonation]['audit_log_id']
      audit_log = ImpersonationAuditLog.find_by(id: session[:impersonation]['audit_log_id'])
      audit_log&.end_impersonation!(reason: reason)
    end

    # Clear impersonation session - this will make current_user return to original user
    session.delete(:impersonation)
    
    # Clear the current_user instance variable so it gets reloaded
    @current_user = nil
  end
end
