# frozen_string_literal: true

require 'test_helper'

class Agents::HealthCheckTest < ActiveSupport::TestCase
  def setup
    @health_check = Agents::HealthCheck.new
  end

  test "run returns health status structure" do
    result = @health_check.run
    
    assert result.key?(:status)
    assert result.key?(:timestamp)
    assert result.key?(:checks)
    assert %w[healthy degraded unhealthy].include?(result[:status])
  end

  test "checks include all required components" do
    result = @health_check.run
    checks = result[:checks]
    
    assert checks.key?(:llm)
    assert checks.key?(:tools)
    assert checks.key?(:assistants)
    assert checks.key?(:background_jobs)
  end

  test "llm check includes provider status" do
    result = @health_check.run
    llm_check = result[:checks][:llm]
    
    assert llm_check.key?(:status)
    assert llm_check.key?(:providers)
    assert llm_check[:providers].is_a?(Hash)
  end

  test "tools check includes tool status" do
    result = @health_check.run
    tools_check = result[:checks][:tools]
    
    assert tools_check.key?(:status)
    assert tools_check.key?(:tools)
    assert tools_check[:tools].is_a?(Hash)
  end

  test "assistants check includes metrics" do
    result = @health_check.run
    assistants_check = result[:checks][:assistants]
    
    assert assistants_check.key?(:status)
    assert assistants_check.key?(:total_assistants)
    assert assistants_check.key?(:active_assistants)
    assert assistants_check.key?(:recent_runs)
    assert assistants_check.key?(:failed_runs)
    assert assistants_check.key?(:failure_rate)
  end

  test "background jobs check includes queue metrics" do
    result = @health_check.run
    jobs_check = result[:checks][:background_jobs]
    
    assert jobs_check.key?(:status)
    assert jobs_check.key?(:redis)
    assert jobs_check.key?(:queue_size)
    assert jobs_check.key?(:scheduled_size)
    assert jobs_check.key?(:retry_size)
  end
end