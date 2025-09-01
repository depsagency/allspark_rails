redis_config = {
  url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
}

# Disable SSL verification for Heroku Redis in production
if Rails.env.production? && ENV["REDIS_URL"]&.start_with?("rediss://")
  redis_config[:ssl_params] = { verify_mode: OpenSSL::SSL::VERIFY_NONE }
end

Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end

# Queue routing based on container role for dual Sidekiq setup
module QueueHelper
  def self.queue_for(job_type)
    container_role = ENV['CONTAINER_ROLE']
    
    case container_role
    when 'builder', 'builder_sidekiq'
      case job_type
      when :ai_generation
        'builder_ai'
      when :notifications
        'builder_notifications'
      else
        'builder_default'
      end
    when 'target', 'target_sidekiq'
      case job_type
      when :claude_session
        'target_claude'
      when :file_operation
        'target_files'
      else
        'target_development'
      end
    else
      'default' # Fallback for development
    end
  end
end
