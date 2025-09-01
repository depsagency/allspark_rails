# frozen_string_literal: true

module Agents
  class HealthCheck
    def self.run
      new.run
    end
    
    def run
      {
        status: overall_status,
        timestamp: Time.current,
        checks: {
          llm: check_llm_providers,
          tools: check_tools,
          assistants: check_assistants,
          background_jobs: check_background_jobs
        }
      }
    end
    
    private
    
    def overall_status
      checks = [
        check_llm_providers[:status],
        check_tools[:status],
        check_assistants[:status],
        check_background_jobs[:status]
      ]
      
      return 'healthy' if checks.all? { |s| s == 'healthy' }
      return 'degraded' if checks.any? { |s| s == 'healthy' }
      'unhealthy'
    end
    
    def check_llm_providers
      providers = {}
      
      %w[openai claude gemini].each do |provider|
        begin
          client = Llm::Client.new(provider: provider.to_sym)
          providers[provider] = client.available? ? 'available' : 'unavailable'
        rescue => e
          providers[provider] = "error: #{e.message}"
        end
      end
      
      status = providers.values.any? { |v| v == 'available' } ? 'healthy' : 'unhealthy'
      
      {
        status: status,
        providers: providers
      }
    end
    
    def check_tools
      tools = {
        calculator: check_tool(Agents::Tools::CalculatorTool),
        ruby_code: check_tool(Agents::Tools::RubyCodeTool),
        web_search: check_tool(Agents::Tools::WebSearchTool),
        chat: check_tool(Agents::Tools::ChatTool)
      }
      
      status = tools.values.all? { |v| v[:status] == 'operational' } ? 'healthy' : 'degraded'
      
      {
        status: status,
        tools: tools
      }
    end
    
    def check_tool(tool_class)
      tool = tool_class.new
      
      # Basic instantiation check
      {
        status: 'operational',
        class: tool_class.name
      }
    rescue => e
      {
        status: 'error',
        class: tool_class.name,
        error: e.message
      }
    end
    
    def check_assistants
      total = Assistant.count
      active = Assistant.active.count
      recent_runs = AgentRun.where(created_at: 1.hour.ago..).count
      failed_runs = AgentRun.where(created_at: 1.hour.ago.., status: :failed).count
      
      failure_rate = recent_runs > 0 ? (failed_runs.to_f / recent_runs * 100).round(2) : 0
      
      {
        status: failure_rate > 50 ? 'unhealthy' : 'healthy',
        total_assistants: total,
        active_assistants: active,
        recent_runs: recent_runs,
        failed_runs: failed_runs,
        failure_rate: failure_rate
      }
    rescue => e
      {
        status: 'error',
        error: e.message
      }
    end
    
    def check_background_jobs
      redis_connected = Sidekiq.redis(&:ping) == 'PONG'
      
      {
        status: redis_connected ? 'healthy' : 'unhealthy',
        redis: redis_connected ? 'connected' : 'disconnected',
        queue_size: Sidekiq::Queue.new.size,
        scheduled_size: Sidekiq::ScheduledSet.new.size,
        retry_size: Sidekiq::RetrySet.new.size
      }
    rescue => e
      {
        status: 'error',
        error: e.message
      }
    end
  end
end