# frozen_string_literal: true

class IntegrationsController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @integrations = current_user.external_integrations.includes(:user)
    @available_services = available_services
  end
  
  def show
    @integration = current_user.external_integrations.find(params[:id])
    
    # Test the connection
    @connection_status = @integration.test_connection
    
    # Get service-specific data
    case @integration.service
    when 'todoist'
      load_todoist_data if @connection_status
    end
  end
  
  def new
    @service = params[:service]
    redirect_to integrations_path unless valid_service?(@service)
  end
  
  def create
    # For services that don't use OAuth (API key based)
    @integration = current_user.external_integrations.build(integration_params)
    
    if @integration.save && @integration.test_connection
      redirect_to integrations_path, notice: "#{@integration.service.humanize} connected successfully!"
    else
      flash.now[:alert] = "Failed to connect. Please check your credentials."
      render :new
    end
  end
  
  def destroy
    @integration = current_user.external_integrations.find(params[:id])
    @integration.destroy
    
    redirect_to integrations_path, notice: "Integration removed successfully."
  end
  
  private
  
  def integration_params
    params.require(:external_integration).permit(:service, :access_token)
  end
  
  def available_services
    [
      {
        id: 'todoist',
        name: 'Todoist',
        description: 'Task management and to-do lists',
        icon: '✓',
        oauth: true
      },
      {
        id: 'github',
        name: 'GitHub',
        description: 'Code repositories and issues',
        icon: '🐙',
        oauth: true
      }
    ]
  end
  
  def valid_service?(service)
    ExternalIntegration.services.keys.include?(service)
  end
  
  def load_todoist_data
    client = @integration.client
    
    @todoist_data = {
      projects: client.projects,
      tasks: client.tasks(filter: 'today | overdue')
    }
  rescue => e
    Rails.logger.error "Failed to load Todoist data: #{e.message}"
    @todoist_data = nil
  end
end