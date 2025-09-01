# frozen_string_literal: true

# Configure session store with container-specific cookie names
container_role = ENV['CONTAINER_ROLE'] || 'builder'

# Set different session cookie names for each container
session_key = case container_role
when 'builder', 'builder_sidekiq'
  '_allspark_builder_session'
when 'target', 'target_sidekiq'  
  '_allspark_target_session'
else
  '_allspark_session'
end

# Configure for HTTPS iframe compatibility
Rails.application.config.session_store :cookie_store,
  key: session_key,
  httponly: true,
  same_site: :none,  # Required for cross-origin iframe
  secure: true       # Required with SameSite=None

# Rails.logger.info "Session configured: #{session_key} (SameSite: none, Secure: true)"
