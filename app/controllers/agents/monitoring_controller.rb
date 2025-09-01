# frozen_string_literal: true

module Agents
  class MonitoringController < ApplicationController
    before_action :authenticate_user!
    
    def index
      @health_status = Agents::HealthCheck.run
      @error_stats = Agents::ErrorMonitor.instance.error_stats
      @recent_runs = AgentRun.joins(:assistant)
                             .where(assistants: { user_id: current_user.id })
                             .includes(:assistant)
                             .order(created_at: :desc)
                             .limit(20)
      
      # Activity metrics
      @metrics = calculate_metrics
    end
    
    def errors
      @errors = Agents::ErrorMonitor.instance.recent_errors(limit: 100)
      
      respond_to do |format|
        format.html
        format.json { render json: @errors }
      end
    end
    
    def health
      @health = Agents::HealthCheck.run
      
      respond_to do |format|
        format.html
        format.json { render json: @health }
      end
    end
    
    def clear_errors
      Agents::ErrorMonitor.instance.clear!
      redirect_to errors_agents_monitoring_index_path, notice: 'Error logs cleared successfully.'
    end
    
    private
    
    def calculate_metrics
      runs = AgentRun.joins(:assistant)
                     .where(assistants: { user_id: current_user.id })
                     .where(created_at: 7.days.ago..)
      
      {
        total_runs: runs.count,
        successful_runs: runs.completed.count,
        failed_runs: runs.failed.count,
        average_duration: runs.completed.average("CAST(metadata->>'duration_ms' AS FLOAT)")&.to_i || 0,
        runs_by_day: runs_by_day(runs),
        runs_by_status: runs.group(:status).count,
        top_assistants: top_assistants
      }
    end
    
    def runs_by_day(runs)
      runs.group_by_day(:created_at, last: 7).count
    end
    
    def top_assistants
      current_user.assistants
                  .joins(:agent_runs)
                  .where(agent_runs: { created_at: 7.days.ago.. })
                  .group('assistants.id', 'assistants.name')
                  .order('COUNT(agent_runs.id) DESC')
                  .limit(5)
                  .pluck('assistants.name', 'COUNT(agent_runs.id)')
    end
  end
end