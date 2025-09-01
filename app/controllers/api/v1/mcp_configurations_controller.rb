module Api
  module V1
    class McpConfigurationsController < ApplicationController
      before_action :set_configuration, only: [:show, :update, :destroy, :test]
      
      def index
        configurations = current_user.mcp_configurations.active
        
        render json: {
          configurations: configurations.map { |config| serialize_configuration(config) },
          templates: McpTemplate.all.map { |template| serialize_template(template) }
        }
      end
      
      def show
        render json: serialize_configuration(@configuration)
      end
      
      def create
        configuration = current_user.mcp_configurations.build(configuration_params)
        
        # Handle template-based creation
        if params[:template_key].present?
          template = McpTemplate.find_by(key: params[:template_key])
          if template
            template_config = template.instantiate_configuration(params[:template_values] || {})
            configuration.server_config = template_config.server_config
            configuration.server_type = template_config.server_type
            configuration.metadata = template_config.metadata
          end
        end
        
        validator = McpConfigValidator.new
        if validator.validate(configuration) && configuration.save
          render json: serialize_configuration(configuration), status: :created
        else
          errors = configuration.errors.full_messages + validator.errors
          render json: { errors: errors }, status: :unprocessable_entity
        end
      end
      
      def update
        if @configuration.update(configuration_params)
          render json: serialize_configuration(@configuration)
        else
          render json: { errors: @configuration.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      def destroy
        @configuration.destroy
        head :no_content
      end
      
      def test
        result = @configuration.test_connection
        render json: result
      end
      
      private
      
      def set_configuration
        @configuration = current_user.mcp_configurations.find(params[:id])
      end
      
      def configuration_params
        params.require(:mcp_configuration).permit(
          :name, 
          :server_type, 
          :enabled,
          server_config: {},
          metadata: {}
        )
      end
      
      def serialize_configuration(config)
        {
          id: config.id,
          name: config.name,
          server_type: config.server_type,
          enabled: config.enabled,
          server_config: config.server_config,
          metadata: config.metadata,
          created_at: config.created_at,
          updated_at: config.updated_at,
          bridge_required: config.server_type_stdio? && !config.bridge_available?
        }
      end
      
      def serialize_template(template)
        {
          key: template.key,
          name: template.name,
          description: template.description,
          category: template.category,
          required_fields: template.required_fields,
          documentation_url: template.documentation_url
        }
      end
    end
  end
end