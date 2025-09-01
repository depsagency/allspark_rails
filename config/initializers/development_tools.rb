# frozen_string_literal: true

# Development Tools Configuration
# This file configures various development and debugging tools

# TEMPORARILY DISABLE TO FIX BOOT LOOP
if false && Rails.env.development?
  # Better error pages
  Rails.application.config.consider_all_requests_local = true

  # Bullet gem configuration (if enabled)
  if AppConfig.dev_tools&.bullet_enabled && defined?(Bullet)
    Rails.application.configure do
      config.after_initialize do
        Bullet.enable = true
        Bullet.alert = true
        Bullet.bullet_logger = true
        Bullet.console = true
        Bullet.rails_logger = true
        Bullet.add_footer = true
      end
    end
  end

  # Debug output helper
  if AppConfig.dev_tools&.debug_enabled
    # Add debug helper to all controllers
    module DebugHelper
      def debug_log(message, data = nil)
        return unless Rails.env.development?

        Rails.logger.debug "🐛 DEBUG: #{message}"
        Rails.logger.debug "   Data: #{data.inspect}" if data
      end
    end

    ActionController::Base.include DebugHelper
  end

  # Custom development middleware for performance monitoring
  if AppConfig.dev_tools&.profiling_enabled
    Rails.application.config.middleware.use(
      Class.new do
        def initialize(app)
          @app = app
        end

        def call(env)
          start_time = Time.current
          status, headers, response = @app.call(env)
          duration = Time.current - start_time

          if duration > 1.0 # Log slow requests
            Rails.logger.warn "🐌 SLOW REQUEST: #{env['REQUEST_METHOD']} #{env['PATH_INFO']} took #{duration.round(2)}s"
          end

          [ status, headers, response ]
        end
      end
    )
  end

  # Development console helpers
  Rails.application.console do
    puts "🚀 Rails Console Helpers Loaded:"
    puts "   - reload!        # Reload the application"
    puts "   - app            # Application instance"
    puts "   - helper         # View helpers"
    puts "   - u              # Create test user: u('test@example.com')"
    puts "   - clear_cache    # Clear all caches"
    puts ""

    # Helper to quickly create users
    def u(email = "test@example.com", password = "password123")
      User.find_or_create_by(email: email) do |user|
        user.password = password
        user.password_confirmation = password
      end
    end

    # Helper to clear all caches
    def clear_cache
      Rails.cache.clear
      puts "✅ Cache cleared"
    end

    # Helper to show current configuration
    def show_config
      puts "📋 Current Configuration:"
      puts "   App Name: #{AppConfig.app_name}"
      puts "   Environment: #{Rails.env}"
      puts "   Database: #{ActiveRecord::Base.connection.current_database}"
      puts "   Redis: #{Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')).ping rescue 'Not connected'}"
      puts "   Features: #{Rails.application.config.features.to_h}"
    end
  end
end

# Add custom logging for important events
module CustomLogging
  extend ActiveSupport::Concern

  included do
    after_action :log_user_activity, if: :user_signed_in?
  end

  private

  def log_user_activity
    return unless Rails.env.development? && AppConfig.dev_tools&.debug_enabled

    Rails.logger.info "👤 User Activity: #{current_user.email} #{request.method} #{request.path}"
  end
end

# Include in ApplicationController if it exists
if defined?(ApplicationController)
  ApplicationController.include CustomLogging
end
