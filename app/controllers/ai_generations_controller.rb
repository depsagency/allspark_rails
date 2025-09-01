# frozen_string_literal: true

class AiGenerationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_ai_generation, only: [ :show ]

  # GET /ai_generations
  def index
    # Build the base query with proper ordering and pagination
    base_query = AiGeneration.joins(:app_project)
                            .where(app_projects: { user: current_user })
                            .includes(:app_project)
                            .order(created_at: :desc)

    # Apply filters if present
    if params[:type].present?
      base_query = base_query.where(generation_type: params[:type])
    end

    if params[:provider].present?
      base_query = base_query.where(llm_provider: params[:provider])
    end

    if params[:status].present?
      base_query = base_query.where(status: params[:status])
    end

    if params[:project_id].present?
      base_query = base_query.where(app_project_id: params[:project_id])
    end

    # Paginate the results
    @ai_generations = base_query.page(params[:page]).per(25)

    # Calculate stats from all user's generations (not just current page)
    all_generations = AiGeneration.joins(:app_project)
                                 .where(app_projects: { user: current_user })

    @stats = {
      total: all_generations.count,
      successful: all_generations.where(status: "completed").count,
      failed: all_generations.where(status: "failed").count,
      total_cost: all_generations.sum(:cost) || 0
    }

    # Set individual variables for the view
    @total_cost = @stats[:total_cost].round(4)
    @success_rate = @stats[:total] > 0 ? ((@stats[:successful].to_f / @stats[:total]) * 100).round(1) : 0

    # Get all user's projects for the filter dropdown
    @projects = current_user.app_projects.order(:name)

    @by_provider = all_generations.group(:llm_provider).count
    @by_type = all_generations.group(:generation_type).count
  end

  # GET /ai_generations/:id
  def show
    unless @ai_generation.app_project.user == current_user || current_user.admin?
      redirect_to ai_generations_path, alert: "You can only view your own AI generations."
    end
  end

  private

  def set_ai_generation
    @ai_generation = AiGeneration.find(params[:id])
  end
end
