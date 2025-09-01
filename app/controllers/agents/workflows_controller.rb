class Agents::WorkflowsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_team
  before_action :set_workflow, only: [:show, :edit, :update, :destroy, :execute, :export, :duplicate]
  before_action :authorize_workflow_access

  def index
    @workflows = @team.workflows.includes(:user)
    
    respond_to do |format|
      format.html
      format.json { render json: @workflows }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @workflow.as_json(include: :workflow_executions) }
    end
  end

  def new
    @workflow = @team.workflows.build(user: current_user)
    
    # Create default flow with start and end nodes
    @workflow.flow_definition = {
      'nodes' => [
        {
          'id' => 'start_1',
          'type' => 'start',
          'position' => { 'x' => 250, 'y' => 50 },
          'data' => {}
        },
        {
          'id' => 'end_1',
          'type' => 'end',
          'position' => { 'x' => 250, 'y' => 400 },
          'data' => {}
        }
      ],
      'edges' => []
    }
  end

  def create
    @workflow = @team.workflows.build(workflow_params)
    @workflow.user = current_user
    
    # Initialize flow_definition if not provided
    if @workflow.flow_definition.blank? || @workflow.flow_definition == {}
      @workflow.flow_definition = {
        'nodes' => [
          {
            'id' => 'start_1',
            'type' => 'start',
            'position' => { 'x' => 250, 'y' => 50 },
            'data' => {}
          },
          {
            'id' => 'end_1',
            'type' => 'end',
            'position' => { 'x' => 250, 'y' => 400 },
            'data' => {}
          }
        ],
        'edges' => []
      }
    end

    if @workflow.save
      respond_to do |format|
        format.html { redirect_to edit_agents_team_workflow_path(@team, @workflow), notice: 'Workflow was successfully created. You can now design your workflow.' }
        format.json { render json: @workflow, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @workflow.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
    # Workflow data will be loaded in the React component
  end

  def update
    if @workflow.update(workflow_params)
      # Increment version if flow definition changed
      if @workflow.saved_change_to_flow_definition?
        @workflow.increment!(:version)
      end
      
      respond_to do |format|
        format.html { redirect_to agents_team_workflow_path(@team, @workflow), notice: 'Workflow was successfully updated.' }
        format.json { render json: @workflow }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @workflow.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @workflow.update!(status: 'archived')
    redirect_to agents_team_workflows_path(@team), notice: 'Workflow was archived.'
  end

  def execute
    service = WorkflowExecutionService.new(@workflow, current_user)
    
    begin
      execution = service.execute(execution_params)
      
      respond_to do |format|
        format.html { redirect_to agents_team_workflow_execution_path(@team, @workflow, execution) }
        format.json { render json: execution }
      end
    rescue => e
      respond_to do |format|
        format.html { redirect_back(fallback_location: agents_team_workflow_path(@team, @workflow), alert: e.message) }
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  def export
    respond_to do |format|
      format.json do
        render json: {
          workflow: @workflow.as_json,
          mermaid: @workflow.to_mermaid
        }
      end
      
      format.text do
        send_data @workflow.to_mermaid,
          filename: "#{@workflow.name.parameterize}-workflow.mmd",
          type: 'text/plain'
      end
      
      format.png do
        # TODO: Implement PNG export using mermaid CLI or API
        redirect_back(fallback_location: agents_team_workflow_path(@team, @workflow), 
                     alert: 'PNG export not yet implemented')
      end
    end
  end

  def duplicate
    new_workflow = @workflow.dup
    new_workflow.name = "#{@workflow.name} (Copy)"
    new_workflow.user = current_user
    new_workflow.version = 1
    
    if new_workflow.save
      redirect_to edit_agents_team_workflow_path(@team, new_workflow), 
                  notice: 'Workflow was successfully duplicated.'
    else
      redirect_back(fallback_location: agents_team_workflow_path(@team, @workflow), 
                   alert: 'Failed to duplicate workflow.')
    end
  end

  private

  def set_team
    @team = current_user.agent_teams.find(params[:team_id])
  end

  def set_workflow
    @workflow = @team.workflows.find(params[:id])
  end

  def authorize_workflow_access
    # For now, allow access if user owns the team
    # In future, implement more granular permissions
    unless @team.user_id == current_user.id
      redirect_to agents_teams_path, alert: 'Not authorized to access this workflow.'
    end
  end

  def workflow_params
    params.require(:workflow).permit(:name, :description, :status, flow_definition: {})
  end

  def execution_params
    params.permit(:input_data).to_h
  end
end