# Rack configuration for standalone Sidekiq Web UI
require 'sidekiq/web'
require_relative 'environment'

# Configure Sidekiq Web
Sidekiq::Web.use Rack::Auth::Basic do |username, password|
  # Use environment variables or Rails credentials for production
  username == 'admin' && password == 'admin'
end

run Sidekiq::Web