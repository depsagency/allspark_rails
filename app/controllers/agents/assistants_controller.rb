# frozen_string_literal: true

module Agents
  class AssistantsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_assistant, only: [:show, :edit, :update, :destroy, :test]

    def index
      @assistants = current_user.assistants.active
    end

    def show
      # Get recent runs for this assistant
      @recent_runs = AgentRun.where(assistant: @assistant)
                             .order(created_at: :desc)
                             .limit(10)
    end

    def new
      @assistant = current_user.assistants.build
    end

    def create
      @assistant = current_user.assistants.build(assistant_params)
      @assistant.tools = build_tools_array(params[:tools], params[:mcp_config])
      
      if @assistant.save
        redirect_to agents_assistant_path(@assistant), notice: 'Assistant created successfully.'
      else
        render :new
      end
    end

    def edit
    end

    def update
      if @assistant.update(assistant_params)
        @assistant.tools = build_tools_array(params[:tools], params[:mcp_config])
        @assistant.save
        redirect_to agents_assistant_path(@assistant), notice: 'Assistant updated successfully.'
      else
        render :edit
      end
    end

    def destroy
      Rails.logger.info "=== DESTROY ACTION CALLED ==="
      Rails.logger.info "Assistant ID: #{@assistant.id}"
      Rails.logger.info "Assistant Name: #{@assistant.name}"
      
      begin
        @assistant.destroy!
        Rails.logger.info "Assistant destroyed successfully"
        redirect_to agents_assistants_path, notice: 'Assistant deleted successfully.'
      rescue => e
        Rails.logger.error "Failed to destroy assistant: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        redirect_to agents_assistants_path, alert: "Failed to delete assistant: #{e.message}"
      end
    end

    def test
      test_message = params[:message] || "Hello! Can you help me?"
      
      begin
        response = @assistant.run(content: test_message, user: current_user)
        flash[:notice] = "Assistant response: #{response.content}"
      rescue => e
        flash[:alert] = "Error: #{e.message}"
      end
      
      redirect_to agents_assistant_path(@assistant)
    end

    private

    def set_assistant
      @assistant = current_user.assistants.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to agents_assistants_path, alert: 'Assistant not found.'
    end

    def assistant_params
      params.require(:assistant).permit(
        :name, :instructions, :tool_choice, :model_provider, 
        :llm_model_name, :active
      )
    end
    
    def build_tools_array(tools_param, mcp_config_param = nil)
      return [] unless tools_param.present?
      
      tools_param.map do |tool_type|
        if tool_type == 'mcp_tools' && mcp_config_param.present?
          # Build MCP tools configuration
          mcp_tool_config = { 'type' => 'mcp_tools' }
          
          # Add enabled servers
          if mcp_config_param['enabled_servers'].present?
            mcp_tool_config['enabled_servers'] = mcp_config_param['enabled_servers'].reject(&:blank?)
          end
          
          # Add enabled tools
          if mcp_config_param['enabled_tools'].present?
            mcp_tool_config['enabled_tools'] = mcp_config_param['enabled_tools'].reject(&:blank?)
          end
          
          # Add disabled tools
          if mcp_config_param['disabled_tools'].present?
            mcp_tool_config['disabled_tools'] = mcp_config_param['disabled_tools'].reject(&:blank?)
          end
          
          # Add tool filters
          if mcp_config_param['tool_filters'].present?
            tool_filters = {}
            
            # Categories filter
            if mcp_config_param['tool_filters']['categories'].present?
              categories = mcp_config_param['tool_filters']['categories']
                          .split(',')
                          .map(&:strip)
                          .reject(&:blank?)
              tool_filters['categories'] = categories if categories.any?
            end
            
            # Name pattern filter
            if mcp_config_param['tool_filters']['name_pattern'].present?
              tool_filters['name_pattern'] = mcp_config_param['tool_filters']['name_pattern'].strip
            end
            
            # Description keywords filter
            if mcp_config_param['tool_filters']['description_contains'].present?
              keywords = mcp_config_param['tool_filters']['description_contains']
                        .split(',')
                        .map(&:strip)
                        .reject(&:blank?)
              tool_filters['description_contains'] = keywords if keywords.any?
            end
            
            mcp_tool_config['tool_filters'] = tool_filters if tool_filters.any?
          end
          
          mcp_tool_config
        else
          { 'type' => tool_type }
        end
      end
    end
  end
end