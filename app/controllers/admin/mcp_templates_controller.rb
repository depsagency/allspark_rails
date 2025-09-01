class Admin::McpTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :set_template, only: [:show, :edit, :update, :destroy]
  
  def index
    @templates = McpTemplate.all.order(:category, :name)
    @templates_by_category = @templates.group_by(&:category)
    
    respond_to do |format|
      format.html
      format.json { render json: @templates }
    end
  end
  
  def show
    @sample_config = @template.instantiate_configuration
    @usage_count = McpConfiguration.where("metadata->>'template_key' = ?", @template.key).count
  end
  
  def new
    @template = McpTemplate.new
  end
  
  def create
    @template = McpTemplate.new(template_params)
    
    if @template.save
      redirect_to admin_mcp_templates_path, notice: 'Template was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @template.update(template_params)
      redirect_to admin_mcp_templates_path, notice: 'Template was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    if @template.destroy
      redirect_to admin_mcp_templates_path, notice: 'Template was successfully deleted.'
    else
      redirect_to admin_mcp_templates_path, alert: 'Failed to delete template.'
    end
  end
  
  def preview
    template = McpTemplate.new(template_params)
    config = template.instantiate_configuration(params[:preview_values] || {})
    
    render json: {
      name: config.name,
      server_type: config.server_type,
      server_config: config.server_config,
      metadata: config.metadata
    }
  end
  
  def import
    if params[:file].present?
      imported_count = 0
      failed_count = 0
      
      begin
        data = JSON.parse(params[:file].read)
        data['templates'].each do |template_data|
          template = McpTemplate.find_or_initialize_by(key: template_data['key'])
          if template.update(template_data.except('id', 'created_at', 'updated_at'))
            imported_count += 1
          else
            failed_count += 1
          end
        end
        
        redirect_to admin_mcp_templates_path, 
                    notice: "Imported #{imported_count} templates. #{failed_count} failed."
      rescue => e
        redirect_to admin_mcp_templates_path, 
                    alert: "Import failed: #{e.message}"
      end
    else
      redirect_to admin_mcp_templates_path, alert: 'No file provided.'
    end
  end
  
  def export
    templates = McpTemplate.all
    
    respond_to do |format|
      format.json do
        render json: {
          exported_at: Time.current,
          templates: templates.as_json(except: [:id, :created_at, :updated_at])
        }
      end
    end
  end
  
  def refresh_from_constants
    # Refresh templates from the TEMPLATES constant
    count = 0
    
    McpTemplate::TEMPLATES.each do |key, template_data|
      template = McpTemplate.find_or_initialize_by(key: key.to_s)
      template.attributes = {
        name: template_data[:name],
        description: template_data[:description],
        config_template: template_data[:config_template],
        required_fields: template_data[:required_fields],
        category: template_data[:category],
        documentation_url: template_data[:documentation_url]
      }
      
      if template.save
        count += 1
      end
    end
    
    redirect_to admin_mcp_templates_path, 
                notice: "Refreshed #{count} templates from constants."
  end
  
  private
  
  def set_template
    @template = McpTemplate.find(params[:id])
  end
  
  def template_params
    params.require(:mcp_template).permit(
      :key, :name, :description, :category, 
      :icon_url, :documentation_url, :featured,
      config_template: {},
      required_fields: []
    )
  end
  
  def ensure_admin!
    redirect_to root_path, alert: 'Access denied' unless current_user.system_admin?
  end
end