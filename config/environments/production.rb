require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  # Temporarily disabled due to missing files issue
  config.eager_load = false

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Enable serving static files from the public directory in production (needed for Render.com)
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = ENV.fetch("DISABLE_SSL", "true") != "true"

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # Allow disabling SSL for development deployment platforms
  config.force_ssl = ENV.fetch("DISABLE_SSL", "true") != "true"

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # MCP Configuration Settings
  # Path for temporary MCP configuration files
  config.mcp_config_path = ENV.fetch("MCP_CONFIG_PATH", Rails.root.join("tmp", "mcp_configs").to_s)
  
  # Ensure MCP config directory exists with proper permissions
  FileUtils.mkdir_p(config.mcp_config_path) unless File.exist?(config.mcp_config_path)
  File.chmod(0700, config.mcp_config_path) if File.exist?(config.mcp_config_path)
  
  # MCP Bridge Service URL (future enhancement)
  config.mcp_bridge_url = ENV.fetch("MCP_BRIDGE_URL", nil)

  # Replace the default in-process memory cache store with a durable alternative.
  # This will be overridden below if Redis is available

  # Replace the default in-process and non-durable queuing backend for Active Job.
  # Use Sidekiq for background jobs when Redis is available, otherwise fallback to Solid Queue
  if ENV["REDIS_URL"].present?
    config.active_job.queue_adapter = :sidekiq

    # Configure Redis cache store with SSL verification disabled for Heroku
    redis_cache_config = {
      url: ENV["REDIS_URL"],
      reconnect_attempts: 1,
      error_handler: ->(method:, returning:, exception:) {
        Rails.logger.error { "Redis cache error: #{exception}" }
      }
    }

    # Disable SSL verification for Heroku Redis
    if ENV["REDIS_URL"]&.start_with?("rediss://")
      redis_cache_config[:ssl_params] = { verify_mode: OpenSSL::SSL::VERIFY_NONE }
    end

    config.cache_store = :redis_cache_store, redis_cache_config
  else
    config.active_job.queue_adapter = :solid_queue
    config.solid_queue.connects_to = { database: { writing: :queue } }
    config.cache_store = :solid_cache_store
  end


  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates and URL helpers.
  host = ENV.fetch("APP_HOST", "134.209.167.43")
  protocol = ENV.fetch("DISABLE_SSL", "true") == "true" ? "http" : "https"
  config.action_mailer.default_url_options = { host: host, protocol: protocol }

  # Set default URL options for all Rails URL helpers (needed for Active Storage URLs)
  Rails.application.routes.default_url_options = { host: host, protocol: protocol }

  # Specify outgoing SMTP server. Remember to add smtp/* credentials via rails credentials:edit.
  # config.action_mailer.smtp_settings = {
  #   user_name: Rails.application.credentials.dig(:smtp, :user_name),
  #   password: Rails.application.credentials.dig(:smtp, :password),
  #   address: "smtp.example.com",
  #   port: 587,
  #   authentication: :plain
  # }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  config.hosts = [
    "allspark.build",    # Allow requests from domain
    "104.131.168.59",    # Allow requests from IP
    "localhost"          # Allow localhost for health checks
  ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
