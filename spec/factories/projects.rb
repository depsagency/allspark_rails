FactoryBot.define do
  factory :project do
    name { "MyString" }
    description { "MyText" }
    user { nil }
    settings { "" }
  end
end
