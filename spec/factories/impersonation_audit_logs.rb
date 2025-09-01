FactoryBot.define do
  factory :impersonation_audit_log do
    association :impersonator, factory: [:user, :admin]
    association :impersonated_user, factory: :user
    action { 'start' }
    reason { 'Testing purposes' }
    ip_address { '127.0.0.1' }
    user_agent { 'Mozilla/5.0 (Test Browser)' }
    session_id { SecureRandom.hex(16) }
    started_at { Time.current }
    ended_at { nil }
    metadata { {} }

    trait :ended do
      ended_at { Time.current }
      metadata { { 'end_reason' => 'manual', 'duration' => 3600 } }
    end

    trait :active do
      ended_at { nil }
    end
  end
end
