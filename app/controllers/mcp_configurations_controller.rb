class McpConfigurationsController < ApplicationController
  before_action :authenticate_user!
  before_action :check_feature_enabled!
  before_action :set_configuration, only: [:show, :edit, :update, :destroy, :toggle]
  
  def index
    @configurations = current_user.mcp_configurations.includes(:owner)
    @templates = McpTemplate.all.group_by(&:category)
    
    respond_to do |format|
      format.html
      format.json { render json: @configurations }
    end
  end

  def show
    # Load available tools if the configuration is enabled and stdio type
    @tools = []
    @server_status = nil
    @error_message = nil
    
    if @configuration.enabled? && @configuration.server_type_stdio?
      begin
        bridge_manager = McpBridgeManager.new
        @tools = bridge_manager.list_tools(current_user, @configuration.id)
        @server_status = bridge_manager.server_status(current_user, @configuration.id)
      rescue => e
        @error_message = e.message
        Rails.logger.error "[MCP Configuration Show] Error loading tools: #{e.message}"
      end
    end
    
    respond_to do |format|
      format.html
      format.json { 
        render json: {
          configuration: @configuration,
          tools: @tools,
          server_status: @server_status,
          error: @error_message
        }
      }
    end
  end

  def new
    @configuration = current_user.mcp_configurations.build
    
    # If template is specified, use it to pre-fill
    if params[:template].present?
      @template = McpTemplate.find_by(key: params[:template])
      if @template
        @configuration = @template.instantiate_configuration
        @configuration.owner = current_user
      end
    end
  end

  def create
    @configuration = current_user.mcp_configurations.build(configuration_params)
    
    # Handle template-based creation
    if params[:template_key].present?
      template = McpTemplate.find_by(key: params[:template_key])
      if template
        # Merge template values with form values
        template_config = template.instantiate_configuration(params[:template_values] || {})
        @configuration.server_config = template_config.server_config
        @configuration.server_type = template_config.server_type
        @configuration.metadata = template_config.metadata
      end
    end
    
    # Validate configuration
    validator = McpConfigValidator.new
    if validator.validate(@configuration)
      if @configuration.save
        respond_to do |format|
          format.html { redirect_to mcp_configurations_path, notice: 'MCP configuration was successfully created.' }
          format.json { render json: @configuration, status: :created }
        end
      else
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @configuration.errors, status: :unprocessable_entity }
        end
      end
    else
      @configuration.errors.add(:base, validator.error_messages)
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: validator.errors }, status: :unprocessable_entity }
      end
    end
  end
  
  def from_template
    template = McpTemplate.find_by(key: params[:template_key])
    if template
      @configuration = template.instantiate_configuration(params[:values] || {})
      @configuration.owner = current_user
      
      if @configuration.save
        redirect_to mcp_configurations_path, notice: "#{template.name} configuration added successfully."
      else
        redirect_to mcp_configurations_path, alert: "Failed to create configuration: #{@configuration.errors.full_messages.join(', ')}"
      end
    else
      redirect_to mcp_configurations_path, alert: 'Template not found.'
    end
  end

  def edit
  end

  def update
    if @configuration.update(configuration_params)
      respond_to do |format|
        format.html { redirect_to mcp_configurations_path, notice: 'MCP configuration was successfully updated.' }
        format.json { render json: @configuration }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @configuration.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @configuration.destroy
    respond_to do |format|
      format.html { redirect_to mcp_configurations_path, notice: 'MCP configuration was successfully removed.' }
      format.json { head :no_content }
    end
  end

  def toggle
    @configuration.update!(enabled: !@configuration.enabled)
    
    respond_to do |format|
      format.html { redirect_to mcp_configurations_path, notice: "Configuration #{@configuration.enabled? ? 'enabled' : 'disabled'}." }
      format.json { render json: @configuration }
    end
  end
  
  def test
    @configuration = current_user.mcp_configurations.find(params[:id])
    result = @configuration.test_connection
    
    respond_to do |format|
      format.json { render json: result }
    end
  end

  private

  def set_configuration
    @configuration = current_user.mcp_configurations.find(params[:id])
  end

  def configuration_params
    params.require(:mcp_configuration).permit(:name, :server_type, :enabled, server_config: {})
  end
  
  def check_feature_enabled!
    unless current_user.mcp_configurations_enabled?
      respond_to do |format|
        format.html do
          flash[:alert] = "The new MCP configuration system is not yet available for your account."
          redirect_to root_path
        end
        format.json do
          render json: { error: "Feature not enabled" }, status: :forbidden
        end
      end
    end
  end
end