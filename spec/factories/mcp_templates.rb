FactoryBot.define do
  factory :mcp_template do
    sequence(:key) { |n| "template_#{n}" }
    sequence(:name) { |n| "Template #{n}" }
    description { "A test MCP template" }
    config_template do
      {
        "server_type" => "http",
        "server_config" => {
          "endpoint" => "https://api.example.com/{{API_KEY}}"
        }
      }
    end
    required_fields { ["API_KEY"] }
    category { "custom" }
    
    trait :linear do
      key { "linear" }
      name { "Linear" }
      description { "Linear issue tracking integration" }
      config_template do
        {
          "server_type" => "stdio",
          "server_config" => {
            "command" => "npx",
            "args" => ["@modelcontextprotocol/server-linear"],
            "env" => { "LINEAR_API_KEY" => "{{LINEAR_API_KEY}}" }
          }
        }
      end
      required_fields { ["LINEAR_API_KEY"] }
      category { "productivity" }
      icon_url { "https://linear.app/icon.png" }
      documentation_url { "https://docs.linear.app" }
    end
    
    trait :github do
      key { "github" }
      name { "GitHub" }
      description { "GitHub repository integration" }
      config_template do
        {
          "server_type" => "stdio",
          "server_config" => {
            "command" => "npx",
            "args" => ["@modelcontextprotocol/server-github"],
            "env" => { "GITHUB_TOKEN" => "{{GITHUB_TOKEN}}" }
          }
        }
      end
      required_fields { ["GITHUB_TOKEN"] }
      category { "development" }
    end
    
    trait :http do
      key { "custom_http" }
      name { "Custom HTTP" }
      description { "Custom HTTP MCP server" }
      config_template do
        {
          "server_type" => "http",
          "server_config" => {
            "endpoint" => "https://{{DOMAIN}}/mcp",
            "headers" => {
              "Authorization" => "Bearer {{API_TOKEN}}",
              "X-Client-Id" => "{{CLIENT_ID}}"
            }
          }
        }
      end
      required_fields { ["DOMAIN", "API_TOKEN", "CLIENT_ID"] }
      category { "custom" }
    end
    
    trait :no_required_fields do
      required_fields { [] }
      config_template do
        {
          "server_type" => "http",
          "server_config" => {
            "endpoint" => "https://public-api.example.com/mcp"
          }
        }
      end
    end
  end
end