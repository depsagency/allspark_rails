# frozen_string_literal: true

# Google Workspace Integration Concern
#
# Provides common functionality for Google API services including:
# - Authentication setup
# - Error handling and retries
# - Rate limiting
# - Request/response logging
#
module GoogleWorkspaceIntegration
  extend ActiveSupport::Concern

  class GoogleWorkspaceError < StandardError; end
  class AuthenticationError < GoogleWorkspaceError; end
  class RateLimitError < GoogleWorkspaceError; end
  class QuotaExceededError < GoogleWorkspaceError; end

  included do
    # Maximum retry attempts for API calls
    MAX_RETRY_ATTEMPTS = 3

    # Rate limiting configuration
    RATE_LIMIT_DELAY = 0.1 # seconds between requests

    attr_reader :service_account_name, :impersonate_user
  end

  private

  # Setup Google API client with service account credentials
  #
  # @param service_account_name [String] Name of service account from config
  # @param impersonate_user [String] Email of user to impersonate
  # @param scopes [Array<String>] OAuth scopes required
  # @return [Google::Auth::ServiceAccountCredentials]
  def setup_google_auth(service_account_name, impersonate_user = nil, scopes = [])
    @service_account_name = service_account_name
    @impersonate_user = impersonate_user

    service_account_config = Rails.application.config.google_workspace.service_account(service_account_name)

    raise AuthenticationError, "Service account '#{service_account_name}' not found in config" unless service_account_config

    key_content = load_service_account_key(service_account_config)

    authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: StringIO.new(key_content),
      scope: scopes.presence || service_account_config["scopes"]
    )

    if impersonate_user || service_account_config["impersonate_user"]
      authorizer.sub = impersonate_user || service_account_config["impersonate_user"]
    end

    authorizer
  end

  # Load service account key from Rails credentials or file
  #
  # @param service_account_config [Hash] Service account configuration
  # @return [String] JSON key content
  def load_service_account_key(service_account_config)
    # Try to load from Rails credentials first
    credentials_key = "google_workspace_#{Rails.env}_#{service_account_name}_key"

    if Rails.application.credentials.dig(:google_workspace, Rails.env.to_sym, "#{service_account_name}_key".to_sym)
      return Rails.application.credentials.dig(:google_workspace, Rails.env.to_sym, "#{service_account_name}_key".to_sym)
    end

    # Fallback to file path
    key_path = service_account_config["key_path"]
    full_path = Rails.root.join(key_path)

    if File.exist?(full_path)
      File.read(full_path)
    else
      raise AuthenticationError, "Service account key not found in credentials or at #{full_path}"
    end
  end

  # Execute Google API request with error handling and retries
  #
  # @param operation [String] Description of the operation for logging
  # @yield Block containing the API call
  # @return [Object] API response
  def execute_with_retry(operation, &block)
    attempt = 1

    begin
      log_api_request(operation, attempt)

      # Rate limiting
      sleep(RATE_LIMIT_DELAY) if attempt > 1

      start_time = Time.current
      result = yield
      duration = ((Time.current - start_time) * 1000).round(2)

      log_api_response(operation, "success", duration)
      result

    rescue Google::Apis::RateLimitError, Google::Apis::ServerError => e
      handle_retry(e, operation, attempt, &block)
    rescue Google::Apis::AuthorizationError => e
      log_api_response(operation, "auth_error", 0, e.message)
      raise AuthenticationError, "Authentication failed: #{e.message}"
    rescue Google::Apis::ClientError => e
      log_api_response(operation, "client_error", 0, e.message)
      raise GoogleWorkspaceError, "Client error: #{e.message}"
    rescue => e
      log_api_response(operation, "error", 0, e.message)
      raise GoogleWorkspaceError, "Unexpected error: #{e.message}"
    end
  end

  # Handle retry logic for API calls
  def handle_retry(error, operation, attempt, &block)
    if attempt < MAX_RETRY_ATTEMPTS
      wait_time = [ 2**attempt, 32 ].min # Exponential backoff, max 32 seconds
      Rails.logger.warn "Google API retry #{attempt}/#{MAX_RETRY_ATTEMPTS} for #{operation}: #{error.message}. Waiting #{wait_time}s"

      sleep(wait_time)
      execute_with_retry(operation, &block)
    else
      log_api_response(operation, "max_retries_exceeded", 0, error.message)

      case error
      when Google::Apis::RateLimitError
        raise RateLimitError, "Rate limit exceeded after #{MAX_RETRY_ATTEMPTS} attempts: #{error.message}"
      else
        raise GoogleWorkspaceError, "Max retries exceeded for #{operation}: #{error.message}"
      end
    end
  end

  # Log API request
  def log_api_request(operation, attempt)
    Rails.logger.info "Google API Request: #{operation} (attempt #{attempt}) - Service Account: #{service_account_name}"
  end

  # Log API response
  def log_api_response(operation, status, duration_ms, error_message = nil)
    log_data = {
      operation: operation,
      service_account: service_account_name,
      impersonate_user: impersonate_user,
      status: status,
      duration_ms: duration_ms
    }

    log_data[:error] = error_message if error_message

    if status == "success"
      Rails.logger.info "Google API Success: #{log_data}"
    else
      Rails.logger.error "Google API Error: #{log_data}"
    end
  end

  # Test connection to Google API
  #
  # @return [Boolean] True if connection successful
  def test_connection
    begin
      test_api_access
      true
    rescue => e
      Rails.logger.error "Google API connection test failed: #{e.message}"
      false
    end
  end

  # Override in implementing classes to provide service-specific connection test
  def test_api_access
    raise NotImplementedError, "#{self.class} must implement #test_api_access"
  end

  # Validate that required scopes are present
  #
  # @param required_scopes [Array<String>] Scopes that must be present
  # @return [Boolean] True if all required scopes are present
  def validate_scopes(required_scopes)
    service_account_config = Rails.application.config.google_workspace.service_account(service_account_name)
    return false unless service_account_config

    configured_scopes = service_account_config["scopes"] || []
    missing_scopes = required_scopes - configured_scopes

    if missing_scopes.any?
      Rails.logger.error "Missing required scopes for #{service_account_name}: #{missing_scopes.join(', ')}"
      return false
    end

    true
  end
end
