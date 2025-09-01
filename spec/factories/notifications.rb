# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    association :user
    title { Faker::Lorem.sentence(word_count: 3) }
    message { Faker::Lorem.paragraph(sentence_count: 2) }
    notification_type { %w[info success warning error].sample }
    priority { rand(0..10) }
    read_at { nil }
    delivered_at { Time.current }

    trait :read do
      read_at { Faker::Time.between(from: 1.day.ago, to: Time.current) }
    end

    trait :unread do
      read_at { nil }
    end

    trait :expired do
      expires_at { 1.hour.ago }
    end

    trait :persistent do
      persistent { true }
      expires_at { nil }
    end

    trait :high_priority do
      priority { rand(8..10) }
    end

    trait :low_priority do
      priority { rand(0..2) }
    end

    trait :with_sender do
      association :sender, factory: :user
    end

    trait :with_action_url do
      action_url { Faker::Internet.url }
    end

    trait :with_metadata do
      metadata do
        {
          source: 'system',
          category: Faker::Lorem.word,
          tags: Faker::Lorem.words(number: 3)
        }
      end
    end

    # Specific notification types
    factory :info_notification do
      notification_type { 'info' }
    end

    factory :success_notification do
      notification_type { 'success' }
    end

    factory :warning_notification do
      notification_type { 'warning' }
      priority { 5 }
    end

    factory :error_notification do
      notification_type { 'error' }
      priority { 8 }
    end

    factory :system_notification do
      notification_type { 'system' }
      title { 'System Maintenance' }
      message { 'The system will be under maintenance from 2 AM to 4 AM.' }
      persistent { true }
      priority { 7 }
    end

    factory :mention_notification do
      notification_type { 'mention' }
      title { 'You were mentioned' }
      message { 'Someone mentioned you in a comment.' }
      trait :with_sender
    end

    factory :task_notification do
      notification_type { 'task_assigned' }
      title { 'New task assigned' }
      message { 'You have been assigned a new task.' }
      trait :with_sender
      trait :with_action_url

      metadata do
        {
          task_id: SecureRandom.uuid,
          due_date: 3.days.from_now.iso8601
        }
      end
    end

    factory :deadline_notification do
      notification_type { 'deadline_reminder' }
      title { 'Deadline approaching' }
      message { 'Your task is due in 24 hours.' }
      priority { 6 }

      metadata do
        {
          task_id: SecureRandom.uuid,
          due_date: 1.day.from_now.iso8601
        }
      end
    end

    factory :security_notification do
      notification_type { 'security_alert' }
      title { 'Security Alert' }
      message { 'Unusual activity detected on your account.' }
      priority { 9 }
      persistent { true }

      metadata do
        {
          ip_address: Faker::Internet.ip_v4_address,
          location: Faker::Address.city,
          timestamp: Time.current.iso8601
        }
      end
    end

    # Bulk notifications for testing
    factory :bulk_notifications do
      transient do
        count { 5 }
        users { create_list(:user, 3) }
      end

      after(:create) do |notification, evaluator|
        evaluator.users.each do |user|
          create(:notification,
                 user: user,
                 title: notification.title,
                 message: notification.message,
                 notification_type: notification.notification_type)
        end
      end
    end
  end
end
