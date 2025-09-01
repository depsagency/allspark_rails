FactoryBot.define do
  factory :assistant do
    association :user
    sequence(:name) { |n| "Assistant #{n}" }
    description { "A test assistant" }
    tool_choice { "auto" }
    instructions { "You are a helpful assistant." }
    model { "gpt-4" }
    tools { [] }
    metadata { {} }
    
    trait :with_mcp_tools do
      after(:create) do |assistant|
        # Create MCP configurations for testing
        create(:mcp_configuration, owner: assistant.user, enabled: true)
      end
    end
    
    trait :with_knowledge do
      after(:create) do |assistant|
        create(:knowledge_document, assistant: assistant)
      end
    end
  end
end