# frozen_string_literal: true

require 'ostruct' if defined?(Lookbook)

if defined?(Lookbook) && Rails.env.development?

  Lookbook.configure do |config|
    # Set the project name that will be displayed in the Lookbook UI
    config.project_name = "Rails Template Component Library"

    # Listen for changes and auto-reload
    config.listen = true

    # Preview paths - where to look for preview files
    config.preview_paths = [
      Rails.root.join("app/components/previews")
    ]

    # Page paths for additional documentation
    config.page_paths = [
      Rails.root.join("docs/components")
    ]

    # Leave preview controller as default - ViewComponentsController should work
    # config.preview_controller = "Lookbook::PreviewController"

    # Use default markdown processing - no custom configuration
  end

  # Add custom helpers for previews
  Lookbook::Preview.extend(Module.new do
    def daisyui_themes
      %w[
        light dark cupcake bumblebee emerald corporate synthwave retro
        cyberpunk valentine halloween garden forest aqua lofi pastel
        fantasy wireframe black luxury dracula cmyk autumn business
        acid lemonade night coffee winter dim nord sunset
      ]
    end

    def sample_notification
      {
        id: SecureRandom.uuid,
        title: "Sample Notification",
        message: "This is a sample notification message for preview purposes.",
        type: "info",
        icon: "info-circle",
        created_at: Time.current
      }
    end

    def sample_user
      {
        id: SecureRandom.uuid,
        name: "John Doe",
        email: "john@example.com",
        avatar_url: "https://ui-avatars.com/api/?name=John+Doe&background=570df8&color=fff"
      }
    end

    def sample_chat_thread(name: "General Discussion", user: nil, messages: [])
      user ||= sample_user
      thread_id = SecureRandom.uuid
      
      OpenStruct.new(
        id: thread_id,
        name: name,
        created_by: OpenStruct.new(user),
        created_at: 1.hour.ago,
        updated_at: 1.hour.ago,
        messages: messages,
        participants: [],
        participant?: ->(u) { true },
        unread_count_for: ->(u) { messages.size > 2 ? 2 : 0 },
        last_message: messages.last
      )
    end

    def sample_chat_message(content: "Hello!", user: nil, thread: nil)
      user ||= sample_user
      
      OpenStruct.new(
        id: SecureRandom.uuid,
        content: content,
        user: OpenStruct.new(user.merge(display_name: user[:name])),
        chat_thread: thread,
        chat_thread_id: thread&.id,
        created_at: 5.minutes.ago,
        updated_at: 5.minutes.ago,
        edited: false,
        edited_at: nil,
        user_id: user[:id]
      )
    end

    def sample_chat_messages(count: 3)
      users = [sample_user, { 
        id: SecureRandom.uuid, 
        name: "Jane Smith", 
        email: "jane@example.com",
        avatar_url: "https://ui-avatars.com/api/?name=Jane+Smith&background=f59e0b&color=fff"
      }]
      
      messages = []
      count.times do |i|
        user = users[i % 2]
        messages << sample_chat_message(
          content: ["Hello! How are you?", "I'm doing great, thanks!", "That's wonderful to hear!"][i % 3],
          user: user
        )
      end
      messages
    end
  end)
end
