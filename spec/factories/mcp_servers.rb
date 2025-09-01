FactoryBot.define do
  factory :mcp_server do
    sequence(:name) { |n| "MCP Server #{n}" }
    sequence(:endpoint) { |n| "https://mcp-server-#{n}.example.com" }
    protocol_version { "1.0" }
    auth_type { :api_key }
    status { :active }
    config { { "timeout" => 30, "max_retries" => 3 } }
    credentials { { "api_key" => "test-api-key-#{SecureRandom.hex(8)}" } }
    
    association :user, factory: :user

    trait :system_wide do
      user { nil }
      instance { nil }
    end

    trait :instance_scoped do
      association :instance, factory: :instance
      user { nil }
    end

    trait :user_scoped do
      association :user, factory: :user
      instance { nil }
    end

    trait :inactive do
      status { :inactive }
    end

    trait :error do
      status { :error }
    end

    trait :oauth do
      auth_type { :oauth }
      credentials { { "access_token" => "oauth-token-#{SecureRandom.hex(8)}", "refresh_token" => "refresh-#{SecureRandom.hex(8)}" } }
    end

    trait :bearer_token do
      auth_type { :bearer_token }
      credentials { { "token" => "bearer-#{SecureRandom.hex(16)}" } }
    end

    trait :no_auth do
      auth_type { :no_auth }
      credentials { {} }
    end
  end
end