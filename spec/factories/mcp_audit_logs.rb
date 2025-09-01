FactoryBot.define do
  factory :mcp_audit_log do
    association :user, factory: :user
    association :mcp_server, factory: :mcp_server
    association :assistant, factory: :assistant
    
    tool_name { "linear_search" }
    request_data { { "query" => "search term", "limit" => 10 } }
    response_data { { "results" => [{ "id" => "issue-123", "title" => "Test Issue" }] } }
    executed_at { Time.current }
    status { :success }
    response_time_ms { rand(100..5000) }

    trait :failed do
      status { :failure }
      response_data { { "error" => "Connection timeout" } }
    end

    trait :timeout do
      status { :timeout }
      response_time_ms { 30000 }
      response_data { { "error" => "Request timed out after 30 seconds" } }
    end

    trait :fast_response do
      response_time_ms { rand(50..200) }
    end

    trait :slow_response do
      response_time_ms { rand(2000..10000) }
    end

    trait :recent do
      executed_at { rand(1.hour.ago..Time.current) }
    end

    trait :old do
      executed_at { rand(1.month.ago..1.week.ago) }
    end

    trait :calculator_tool do
      tool_name { "calculator" }
      request_data { { "expression" => "2 + 2" } }
      response_data { { "result" => 4, "formatted" => "2 + 2 = 4" } }
    end

    trait :web_search_tool do
      tool_name { "web_search" }
      request_data { { "query" => "rails testing", "num_results" => 5 } }
      response_data { { "results" => [{ "title" => "Rails Testing Guide", "url" => "https://guides.rubyonrails.org/testing.html" }] } }
    end

    trait :linear_tool do
      tool_name { "linear_search" }
      request_data { { "query" => "bug reports", "team_id" => "team-123" } }
      response_data { { "issues" => [{ "id" => "issue-456", "title" => "Critical Bug" }] } }
    end
  end
end