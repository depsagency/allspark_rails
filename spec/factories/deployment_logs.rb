FactoryBot.define do
  factory :deployment_log do
    instance { nil }
    deployment_type { "MyString" }
    status { "MyString" }
    message { "MyText" }
    metadata { "" }
    started_at { "2025-07-11 03:54:28" }
    completed_at { "2025-07-11 03:54:28" }
  end
end
