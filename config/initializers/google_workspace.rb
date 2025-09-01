# Google Workspace Integration Configuration
#
# This initializer sets up the Google Workspace integration for the application.
# It loads configuration from google_workspace.yml and provides helper methods
# for accessing Google API services.

class GoogleWorkspaceConfig
  include Singleton

  def initialize
    @config = load_config
  end

  def config
    @config[Rails.env.to_s]
  end

  def project_id
    config&.dig("project_id")
  end

  def service_accounts
    config&.dig("service_accounts") || {}
  end

  def service_account(name)
    service_accounts[name.to_s]
  end

  def enabled?
    config.present? && service_accounts.any?
  end

  private

  def load_config
    file_path = Rails.root.join("config", "google_workspace.yml")
    if File.exist?(file_path)
      YAML.load_file(file_path, aliases: true) || {}
    else
      {}
    end
  rescue => e
    Rails.logger.warn "Failed to load Google Workspace config: #{e.message}"
    {}
  end
end

# Make configuration available globally
Rails.application.config.google_workspace = GoogleWorkspaceConfig.instance

# Verify configuration on startup in development
if Rails.env.development?
  config = Rails.application.config.google_workspace
  if config.enabled?
    Rails.logger.info "Google Workspace integration enabled with #{config.service_accounts.keys.join(', ')}"
  else
    Rails.logger.warn "Google Workspace integration disabled - check config/google_workspace.yml"
  end
end
