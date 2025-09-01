# frozen_string_literal: true

# Application Configuration
# This file provides a centralized place to configure your application
# Update these values for each new project

Rails.application.configure do
  # Application Identity
  config.app_name = ENV.fetch("APP_NAME", "Rails Template")
  config.app_description = ENV.fetch("APP_DESCRIPTION", "A modern Rails application")
  config.app_url = ENV.fetch("APP_URL", "http://localhost:3000")
  config.app_host = ENV.fetch("APP_HOST", "localhost:3000")

  # Contact Information
  config.support_email = ENV.fetch("SUPPORT_EMAIL", "support@example.com")
  config.contact_email = ENV.fetch("CONTACT_EMAIL", "hello@example.com")
  config.admin_email = ENV.fetch("ADMIN_EMAIL", "admin@example.com")

  # Feature Flags
  config.features = ActiveSupport::OrderedOptions.new
  config.features.registration_enabled = ENV.fetch("ENABLE_REGISTRATION", "true") == "true"
  config.features.social_login_enabled = ENV.fetch("ENABLE_SOCIAL_LOGIN", "false") == "true"
  config.features.maintenance_mode = ENV.fetch("MAINTENANCE_MODE", "false") == "true"
  config.features.analytics_enabled = ENV.fetch("ENABLE_ANALYTICS", "false") == "true"

  # Theme and Branding
  config.theme = ActiveSupport::OrderedOptions.new
  config.theme.primary_color = ENV.fetch("PRIMARY_COLOR", "#1AD1A5")
  config.theme.secondary_color = ENV.fetch("SECONDARY_COLOR", "#FF9903")
  config.theme.default_theme = ENV.fetch("DEFAULT_THEME", "light")
  config.theme.logo_url = ENV.fetch("LOGO_URL", "/icon.svg")

  # Business Logic
  config.business = ActiveSupport::OrderedOptions.new
  config.business.default_timezone = ENV.fetch("DEFAULT_TIMEZONE", "UTC")
  config.business.default_currency = ENV.fetch("DEFAULT_CURRENCY", "USD")
  config.business.items_per_page = ENV.fetch("ITEMS_PER_PAGE", "25").to_i

  # External Services
  config.services = ActiveSupport::OrderedOptions.new
  config.services.openai_enabled = ENV["OPENAI_API_KEY"].present?
  config.services.stripe_enabled = ENV["STRIPE_SECRET_KEY"].present?
  config.services.s3_enabled = ENV["AWS_ACCESS_KEY_ID"].present?
  config.services.redis_enabled = ENV["REDIS_URL"].present?

  # AI/LLM Configuration
  config.llm = ActiveSupport::OrderedOptions.new
  config.llm.provider = ENV.fetch("LLM_PROVIDER", "openrouter")
  config.llm.openrouter_enabled = ENV["OPENROUTER_API_KEY"].present?
  config.llm.openai_enabled = ENV["OPENAI_API_KEY"].present?
  config.llm.claude_enabled = ENV["CLAUDE_API_KEY"].present?
  config.llm.gemini_enabled = ENV["GEMINI_API_KEY"].present?

  # Security Settings
  config.security = ActiveSupport::OrderedOptions.new
  config.security.force_ssl = ENV.fetch("FORCE_SSL", Rails.env.production?).to_s == "true"
  config.security.session_timeout = ENV.fetch("SESSION_TIMEOUT", "24").to_i.hours
  config.security.password_min_length = ENV.fetch("PASSWORD_MIN_LENGTH", "8").to_i

  # Performance Settings
  config.performance = ActiveSupport::OrderedOptions.new
  config.performance.cache_enabled = ENV.fetch("CACHE_ENABLED", Rails.env.production?).to_s == "true"
  config.performance.slow_query_threshold = ENV.fetch("SLOW_QUERY_THRESHOLD", "1").to_f.seconds

  # Development Tools
  if Rails.env.development?
    config.dev_tools = ActiveSupport::OrderedOptions.new
    config.dev_tools.debug_enabled = ENV.fetch("DEBUG", "false") == "true"
    config.dev_tools.bullet_enabled = ENV.fetch("BULLET_ENABLED", "false") == "true"
    config.dev_tools.profiling_enabled = ENV.fetch("PROFILING_ENABLED", "false") == "true"
  end
end

# Helper method to access configuration easily
module AppConfig
  def self.method_missing(method_name, *args, &block)
    if Rails.application.config.respond_to?(method_name)
      Rails.application.config.send(method_name, *args, &block)
    else
      super
    end
  end

  def self.respond_to_missing?(method_name, include_private = false)
    Rails.application.config.respond_to?(method_name, include_private) || super
  end

  # Quick access methods
  def self.app_name
    Rails.application.config.app_name
  end

  def self.feature_enabled?(feature_name)
    Rails.application.config.features.send(feature_name) rescue false
  end

  def self.service_enabled?(service_name)
    Rails.application.config.services.send("#{service_name}_enabled") rescue false
  end
end
