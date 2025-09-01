# frozen_string_literal: true

class ExternalIntegration < ApplicationRecord
  belongs_to :user
  
  # Encryption for sensitive data
  encrypts :access_token
  encrypts :refresh_token
  
  # Service types
  enum :service, {
    todoist: 0,
    github: 1,
    google_calendar: 2
  }, default: :todoist
  
  # Validations
  validates :service, presence: true
  validates :access_token, presence: true
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :for_service, ->(service) { where(service: service) }
  
  # Check if token is expired
  def token_expired?
    return false unless expires_at
    expires_at < Time.current
  end
  
  # Refresh the token if needed
  def refresh_token_if_needed!
    return unless token_expired? && refresh_token.present?
    
    case service
    when 'todoist'
      refresh_todoist_token!
    else
      raise NotImplementedError, "Token refresh not implemented for #{service}"
    end
  end
  
  # Get authenticated client
  def client
    refresh_token_if_needed!
    
    case service
    when 'todoist'
      Integrations::TodoistClient.new(access_token)
    else
      raise NotImplementedError, "Client not implemented for #{service}"
    end
  end
  
  # Test the integration
  def test_connection
    client.authenticated?
  rescue => e
    Rails.logger.error "Integration test failed: #{e.message}"
    false
  end
  
  private
  
  def refresh_todoist_token!
    # Todoist tokens don't expire, but this is here for future compatibility
    # If they add OAuth2 with refresh tokens, implement here
  end
end