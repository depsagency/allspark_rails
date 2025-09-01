# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Pundit authorization
  include Pundit::Authorization

  # Responders and layout
  self.responder = ApplicationResponder
  respond_to :html
  layout :set_layout

  # Callbacks
  before_action :authenticate_user!, unless: :devise_controller?
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :check_impersonation_session

  # Pundit error handling
  rescue_from Pundit::NotAuthorizedError, with: :handle_unauthorized

  protected

  # Current user for Pundit
  # During impersonation, use the original user (impersonator) for authorization
  def pundit_user
    impersonating? ? current_impersonator : current_user
  end

  private

  def set_layout
    if devise_controller?
      "devise"
    else
      "application"
    end
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[first_name last_name email password password_confirmation])
    devise_parameter_sanitizer.permit(:account_update, keys: %i[first_name last_name email password password_confirmation current_password])
  end

  def handle_unauthorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_to(request.referrer || root_path)
  end

  # Helper method to check admin access
  def ensure_admin!
    # During impersonation, check the original user (impersonator) instead of current user
    user_to_check = impersonating? ? current_impersonator : current_user
    
    unless user_to_check&.system_admin?
      flash[:alert] = "Access denied."
      redirect_to root_path
    end
  end

  # Helper method for admin-only actions
  def admin_required
    authorize :admin, :access?
  end

  # Impersonation helper methods
  def impersonating?
    session[:impersonation].present?
  end

  def current_impersonator
    return nil unless impersonating?
    @current_impersonator ||= User.find_by(id: session[:impersonation]['original_user_id'])
  end

  def original_user
    current_impersonator
  end

  def impersonated_user
    return nil unless impersonating?
    current_user
  end

  # Make impersonation methods available to views
  helper_method :impersonating?, :current_impersonator, :original_user, :impersonated_user

  # Override current_user to handle impersonation
  def current_user
    if impersonating?
      @current_user ||= User.find_by(id: session[:impersonation]['impersonated_user_id'])
    else
      super
    end
  end

  def check_impersonation_session
    return unless impersonating?
    return if devise_controller?
    
    # Skip validation if we're in the process of stopping impersonation
    return if controller_name == 'impersonation' && action_name == 'stop'

    # Validate session integrity
    impersonation_data = session[:impersonation]
    
    # Check if the impersonation is still valid
    unless valid_impersonation_session?(impersonation_data)
      end_impersonation_session(reason: 'invalid_session')
      flash[:alert] = 'Impersonation session was invalid and has been ended.'
      redirect_to root_path
      return
    end

    # Check for timeout (default 4 hours)
    session_timeout = 4.hours.to_i
    if Time.current.to_i - impersonation_data['started_at'] > session_timeout
      end_impersonation_session(reason: 'timeout')
      flash[:alert] = 'Impersonation session has timed out.'
      redirect_to root_path
      return
    end

    # Validate IP address hasn't changed (security measure)
    if impersonation_data['ip_address'] != request.remote_ip
      end_impersonation_session(reason: 'ip_change')
      flash[:alert] = 'Impersonation session ended due to IP address change.'
      redirect_to root_path
      return
    end
  end

  private

  def valid_impersonation_session?(impersonation_data)
    return false unless impersonation_data.is_a?(Hash)
    return false unless impersonation_data['original_user_id'].present?
    return false unless impersonation_data['impersonated_user_id'].present?
    return false unless impersonation_data['audit_log_id'].present?
    
    # Ensure the audit log still exists and is active
    audit_log = ImpersonationAuditLog.find_by(id: impersonation_data['audit_log_id'])
    return false unless audit_log&.active?
    
    # Ensure current user matches the impersonated user
    return false unless current_user&.id == impersonation_data['impersonated_user_id']
    
    true
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
