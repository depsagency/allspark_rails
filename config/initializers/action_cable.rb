# frozen_string_literal: true

# Configure ActionCable to use cookies for authentication
# Note: disable_request_forgery_protection is now set in config/environments/development.rb for dev

# Ensure ActionCable can access session cookies
Rails.application.config.action_cable.allow_same_origin_as_host = true