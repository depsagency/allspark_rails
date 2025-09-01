# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Seeding database..."

# Create admin user
admin_email = ENV.fetch('ADMIN_EMAIL', 'admin@example.com')
admin_password = ENV.fetch('ADMIN_PASSWORD', 'password123')

admin_user = User.find_or_create_by!(email: admin_email) do |user|
  user.password = admin_password
  user.password_confirmation = admin_password
  user.first_name = "Admin"
  user.last_name = "User"
  user.role = :system_admin
end
puts "👤 Created admin user: #{admin_user.email}"

# Create sample pages for development/demo
if Rails.env.development?
  sample_pages = [
    {
      title: "Welcome to #{AppConfig.app_name}",
      content: <<~HTML
        <h1>Welcome!</h1>
        <p>This is a sample page created during seeding. You can edit or delete this page.</p>
        <p>This starter template includes:</p>
        <ul>
          <li>User authentication with Devise</li>
          <li>Beautiful UI with DaisyUI and Tailwind CSS</li>
          <li>Theme switching</li>
          <li>Rich text editing with TinyMCE</li>
          <li>Background jobs with Sidekiq</li>
          <li>And much more!</li>
        </ul>
      HTML
    },
    {
      title: "About",
      content: <<~HTML
        <h1>About #{AppConfig.app_name}</h1>
        <p>This application was built using the Rails Starter Template.</p>
        <p>Feel free to customize this content for your project.</p>
      HTML
    },
    {
      title: "Getting Started",
      content: <<~HTML
        <h1>Getting Started</h1>
        <h2>For Developers</h2>
        <p>Welcome to your new Rails application! Here are some next steps:</p>
        <ol>
          <li>Customize the application configuration in <code>config/initializers/app_config.rb</code></li>
          <li>Update your environment variables in <code>.env</code></li>
          <li>Modify the theme and styling to match your brand</li>
          <li>Add your business logic and models</li>
          <li>Deploy to your preferred hosting platform</li>
        </ol>

        <h2>Useful Commands</h2>
        <ul>
          <li><code>rake setup:dev</code> - Complete development setup</li>
          <li><code>rake setup:health</code> - Check application health</li>
          <li><code>rake app:rename[NewAppName]</code> - Rename the application</li>
        </ul>
      HTML
    }
  ]

  sample_pages.each do |page_data|
    page = Page.find_or_create_by!(title: page_data[:title]) do |p|
      p.content = page_data[:content]
    end
    puts "📄 Created sample page: #{page.title}"
  end

  # Create additional test users for development
  test_users = [
    { email: 'user@example.com', password: 'password123', first_name: 'Test', last_name: 'User' },
    { email: 'demo@example.com', password: 'password123', first_name: 'Demo', last_name: 'User' }
  ]

  test_users.each do |user_data|
    user = User.find_or_create_by!(email: user_data[:email]) do |u|
      u.password = user_data[:password]
      u.password_confirmation = user_data[:password]
      u.first_name = user_data[:first_name]
      u.last_name = user_data[:last_name]
    end
    puts "👤 Created test user: #{user.email}"
  end

  # Create sample assistants for development
  if defined?(Assistant)
    sample_assistants = [
      {
        name: "General Assistant",
        instructions: "You are a helpful AI assistant. Provide clear, concise, and accurate responses to user queries.",
        model_provider: "openai",
        llm_model_name: "gpt-4o-mini",
        tools: [{ "type" => "retrieval" }],
        active: true
      },
      {
        name: "Code Helper",
        instructions: "You are a programming assistant. Help users with coding questions, debugging, and best practices across various programming languages.",
        model_provider: "claude",
        llm_model_name: "claude-3-5-sonnet-20241022",
        tools: [{ "type" => "code_interpreter" }],
        active: true
      }
    ]

    sample_assistants.each do |assistant_data|
      assistant = admin_user.assistants.find_or_create_by!(name: assistant_data[:name]) do |a|
        a.instructions = assistant_data[:instructions]
        a.model_provider = assistant_data[:model_provider]
        a.llm_model_name = assistant_data[:llm_model_name]
        a.tools = assistant_data[:tools]
        a.active = assistant_data[:active]
      end
      puts "🤖 Created sample assistant: #{assistant.name}"
    end
  end
end

puts "✅ Seeding completed!"
puts ""
puts "📋 Summary:"
puts "   Admin user: #{admin_email} / #{admin_password}"
if Rails.env.development?
  puts "   Sample pages: #{Page.count} created"
  puts "   Test users: #{User.count} total"
end
puts ""
puts "🚀 You can now run 'bin/dev' to start the application!"
