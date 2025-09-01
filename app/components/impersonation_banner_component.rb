# frozen_string_literal: true

class ImpersonationBannerComponent < ViewComponent::Base
  def initialize(current_user:, impersonating:, original_user:)
    @current_user = current_user
    @impersonating = impersonating
    @original_user = original_user
  end

  private

  attr_reader :current_user, :impersonating, :original_user

  def should_render?
    impersonating && original_user.present?
  end

  def impersonated_user_name
    current_user&.display_name || 'Unknown User'
  end

  def original_user_name
    original_user&.display_name || 'Unknown Admin'
  end
end
