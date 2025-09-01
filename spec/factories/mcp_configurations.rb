FactoryBot.define do
  factory :mcp_configuration do
    association :owner, factory: :user
    sequence(:name) { |n| "MCP Configuration #{n}" }
    server_type { "http" }
    server_config do
      {
        "endpoint" => "https://api.example.com/mcp",
        "headers" => {
          "Authorization" => "Bearer test_token_#{SecureRandom.hex(8)}"
        }
      }
    end
    enabled { true }
    metadata { {} }

    trait :stdio do
      server_type { "stdio" }
      server_config do
        {
          "command" => "mcp-server",
          "args" => ["--test"],
          "env" => { "DEBUG" => "true" }
        }
      end
    end

    trait :websocket do
      server_type { "websocket" }
      server_config do
        {
          "endpoint" => "wss://api.example.com/mcp"
        }
      end
    end

    trait :sse do
      server_type { "sse" }
      server_config do
        {
          "url" => "https://api.example.com/sse"
        }
      end
    end

    trait :disabled do
      enabled { false }
    end

    trait :with_template do
      metadata do
        {
          "template_key" => "github",
          "template_version" => "1.0"
        }
      end
    end

    trait :for_instance do
      association :owner, factory: :instance
    end

    trait :linear do
      name { "Linear Integration" }
      server_type { "stdio" }
      server_config do
        {
          "command" => "npx",
          "args" => ["@modelcontextprotocol/server-linear"],
          "env" => { "LINEAR_API_KEY" => "test_linear_key" }
        }
      end
      metadata { { "template_key" => "linear" } }
    end

    trait :github do
      name { "GitHub Integration" }
      server_type { "stdio" }
      server_config do
        {
          "command" => "npx",
          "args" => ["@modelcontextprotocol/server-github"],
          "env" => { "GITHUB_TOKEN" => "test_github_token" }
        }
      end
      metadata { { "template_key" => "github" } }
    end
  end
end