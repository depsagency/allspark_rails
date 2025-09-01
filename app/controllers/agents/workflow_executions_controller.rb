class Agents::WorkflowExecutionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_team_and_workflow
  before_action :set_execution, only: [:show, :cancel]
  before_action :authorize_execution_access

  def index
    @executions = @workflow.workflow_executions
                          .includes(:user)
                          .order(created_at: :desc)
                          .page(params[:page])
    
    respond_to do |format|
      format.html
      format.json { render json: @executions }
    end
  end

  def show
    @tasks = @execution.workflow_tasks.includes(:assistant)
    
    respond_to do |format|
      format.html
      format.json { 
        render json: @execution.as_json(
          include: { 
            workflow_tasks: { 
              include: :assistant 
            } 
          },
          methods: [:progress_percentage, :elapsed_time]
        )
      }
    end
  end

  def create
    service = WorkflowExecutionService.new(@workflow, current_user)
    
    begin
      @execution = service.execute(execution_params)
      
      respond_to do |format|
        format.html { redirect_to agents_team_workflow_execution_path(@team, @workflow, @execution) }
        format.json { render json: @execution, status: :created }
      end
    rescue => e
      respond_to do |format|
        format.html { 
          redirect_back(
            fallback_location: agents_team_workflow_path(@team, @workflow), 
            alert: "Failed to start workflow: #{e.message}"
          )
        }
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  def cancel
    if @execution.cancel!
      respond_to do |format|
        format.html { 
          redirect_to agents_team_workflow_execution_path(@team, @workflow, @execution), 
          notice: 'Workflow execution was cancelled.'
        }
        format.json { render json: @execution }
      end
    else
      respond_to do |format|
        format.html { 
          redirect_back(
            fallback_location: agents_team_workflow_execution_path(@team, @workflow, @execution),
            alert: 'Cannot cancel this execution.'
          )
        }
        format.json { render json: { error: 'Cannot cancel this execution' }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_team_and_workflow
    @team = current_user.agent_teams.find(params[:team_id])
    @workflow = @team.workflows.find(params[:workflow_id])
  end

  def set_execution
    @execution = @workflow.workflow_executions.find(params[:id])
  end

  def authorize_execution_access
    # For now, allow access if user owns the team
    unless @team.user_id == current_user.id
      redirect_to agents_teams_path, alert: 'Not authorized to access this execution.'
    end
  end

  def execution_params
    params.permit(:input_data, :parameters).to_h
  end
end