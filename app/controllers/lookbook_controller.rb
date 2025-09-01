# frozen_string_literal: true

class LookbookController < ActionController::Base
  # Inherit from ActionController::Base to avoid authentication requirements
  # This allows Lookbook to work in development without requiring login

  layout "lookbook"

  # Skip CSRF for Lookbook requests
  skip_before_action :verify_authenticity_token

  # Add any custom helper methods for previews
  helper_method :current_theme, :sample_data

  private

  def current_theme
    params[:theme] || "light"
  end

  def sample_data
    {
      users: [
        { name: "Alice Johnson", role: "Admin", status: "online" },
        { name: "Bob Smith", role: "User", status: "away" },
        { name: "Carol Davis", role: "User", status: "offline" }
      ],
      notifications: [
        { title: "Welcome!", message: "Welcome to the app", type: "success" },
        { title: "Update Available", message: "A new version is available", type: "info" },
        { title: "Error Occurred", message: "Something went wrong", type: "error" }
      ]
    }
  end
end
