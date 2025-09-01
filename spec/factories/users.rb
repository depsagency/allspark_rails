# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.unique.email }
    password { 'password123' }
    password_confirmation { 'password123' }
    role { :default }
    confirmed_at { Time.current }

    trait :admin do
      role { :system_admin }
    end

    trait :with_avatar do
      after(:build) do |user|
        user.avatar.attach(
          io: File.open(Rails.root.join('spec', 'fixtures', 'test_image.jpg')),
          filename: 'avatar.jpg',
          content_type: 'image/jpeg'
        )
      end
    end

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :with_notifications do
      after(:create) do |user|
        create_list(:notification, 3, user: user)
        create_list(:notification, 2, user: user, read_at: 1.hour.ago)
      end
    end

    # Named factories for common user types
    factory :admin_user, traits: [ :admin ]
    factory :user_with_avatar, traits: [ :with_avatar ]
    factory :unconfirmed_user, traits: [ :unconfirmed ]
  end
end
