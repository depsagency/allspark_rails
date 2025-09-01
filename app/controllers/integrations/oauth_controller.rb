# frozen_string_literal: true

module Integrations
  class OauthController < ApplicationController
    before_action :authenticate_user!
    
    # Start OAuth flow
    def authorize
      service = params[:service]
      
      case service
      when 'todoist'
        redirect_to todoist_authorize_url
      when 'github'
        redirect_to github_authorize_url
      else
        redirect_to integrations_path, alert: "Unknown service: #{service}"
      end
    end
    
    # OAuth callback
    def callback
      service = params[:service]
      
      case service
      when 'todoist'
        handle_todoist_callback
      when 'github'
        handle_github_callback
      else
        redirect_to integrations_path, alert: "Unknown service: #{service}"
      end
    end
    
    # Disconnect a service
    def disconnect
      integration = current_user.external_integrations.find(params[:id])
      integration.destroy
      
      redirect_to integrations_path, notice: "#{integration.service.humanize} disconnected successfully."
    end
    
    private
    
    def todoist_authorize_url
      client_id = ENV['TODOIST_CLIENT_ID']
      redirect_uri = callback_integrations_oauth_url(service: 'todoist')
      scope = 'data:read_write'
      state = generate_state_token
      
      session[:oauth_state] = state
      
      "https://todoist.com/oauth/authorize?" + {
        client_id: client_id,
        scope: scope,
        state: state,
        redirect_uri: redirect_uri
      }.to_query
    end
    
    def handle_todoist_callback
      # Verify state
      unless valid_state?(params[:state])
        redirect_to integrations_path, alert: "Invalid OAuth state"
        return
      end
      
      # Exchange code for token
      token_response = exchange_todoist_code(params[:code])
      
      if token_response.success?
        data = JSON.parse(token_response.body)
        
        # Create or update integration
        integration = current_user.external_integrations.find_or_initialize_by(service: 'todoist')
        integration.update!(
          access_token: data['access_token'],
          active: true
        )
        
        redirect_to integrations_path, notice: "Todoist connected successfully!"
      else
        redirect_to integrations_path, alert: "Failed to connect Todoist"
      end
    end
    
    def exchange_todoist_code(code)
      HTTParty.post('https://todoist.com/oauth/access_token',
        body: {
          client_id: ENV['TODOIST_CLIENT_ID'],
          client_secret: ENV['TODOIST_CLIENT_SECRET'],
          code: code,
          redirect_uri: callback_integrations_oauth_url(service: 'todoist')
        }
      )
    end
    
    def github_authorize_url
      client = OAuth2::Client.new(
        ENV['GITHUB_CLIENT_ID'],
        ENV['GITHUB_CLIENT_SECRET'],
        site: 'https://github.com',
        authorize_url: '/login/oauth/authorize',
        token_url: '/login/oauth/access_token'
      )
      
      state = generate_state_token
      session[:oauth_state] = state
      
      client.auth_code.authorize_url(
        redirect_uri: callback_integrations_oauth_url(service: 'github'),
        scope: 'repo,user',
        state: state
      )
    end
    
    def handle_github_callback
      # Implementation for GitHub OAuth callback
      redirect_to integrations_path, notice: "GitHub integration coming soon!"
    end
    
    def generate_state_token
      SecureRandom.hex(32)
    end
    
    def valid_state?(state)
      session[:oauth_state].present? && session[:oauth_state] == state
    end
  end
end