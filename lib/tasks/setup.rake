# frozen_string_literal: true

namespace :setup do
  desc "Initial project setup for new developers"
  task dev: :environment do
    puts "🚀 Setting up development environment..."

    # Copy environment file if it doesn't exist
    unless File.exist?(".env")
      if File.exist?(".env.example")
        FileUtils.cp(".env.example", ".env")
        puts "✅ Created .env from .env.example"
      else
        puts "⚠️  .env.example not found"
      end
    end

    # Install dependencies
    puts "📦 Installing dependencies..."
    system("bundle install")
    system("yarn install")

    # Setup database
    puts "🗄️  Setting up database..."
    Rake::Task["db:prepare"].invoke

    # Create admin user
    puts "👤 Creating admin user..."
    Rake::Task["setup:create_admin"].invoke

    puts "🎉 Setup complete! Run 'bin/dev' to start the server"
  end

  desc "Create admin user for development"
  task create_admin: :environment do
    email = ENV.fetch("ADMIN_EMAIL", "admin@example.com")
    password = ENV.fetch("ADMIN_PASSWORD", "password123")

    if User.exists?(email: email)
      puts "👤 Admin user already exists: #{email}"
    else
      user = User.create!(
        email: email,
        password: password,
        password_confirmation: password
      )
      puts "✅ Created admin user: #{email} / #{password}"
    end
  end

  desc "Reset database and reseed"
  task reset_db: :environment do
    puts "🗄️  Resetting database..."
    Rake::Task["db:drop"].invoke
    Rake::Task["db:create"].invoke
    Rake::Task["db:migrate"].invoke
    Rake::Task["db:seed"].invoke
    puts "✅ Database reset complete"
  end

  desc "Generate new Rails secret keys"
  task :generate_secrets do
    puts "🔐 Generated new secret keys:"
    puts "RAILS_MASTER_KEY=#{SecureRandom.hex(16)}"
    puts "SECRET_KEY_BASE=#{SecureRandom.hex(64)}"
  end

  desc "Check application health and configuration"
  task health: :environment do
    puts "🏥 Application Health Check"
    puts "=" * 40

    # Database connectivity
    begin
      ActiveRecord::Base.connection.execute("SELECT 1")
      puts "✅ Database: Connected"
    rescue => e
      puts "❌ Database: #{e.message}"
    end

    # Redis connectivity (if configured)
    if defined?(Redis)
      begin
        redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
        redis.ping
        puts "✅ Redis: Connected"
      rescue => e
        puts "❌ Redis: #{e.message}"
      end
    end

    # Environment variables
    required_env_vars = %w[APP_NAME DATABASE_URL]
    required_env_vars.each do |var|
      if ENV[var].present?
        puts "✅ #{var}: Set"
      else
        puts "⚠️  #{var}: Not set"
      end
    end

    # File permissions
    writable_dirs = %w[tmp log storage]
    writable_dirs.each do |dir|
      if File.writable?(dir)
        puts "✅ #{dir}: Writable"
      else
        puts "❌ #{dir}: Not writable"
      end
    end

    puts "=" * 40
    puts "🎯 Health check complete"
  end
end

namespace :app do
  desc "Rename application throughout codebase"
  task :rename, [ :new_name ] => :environment do |t, args|
    new_name = args[:new_name]

    if new_name.blank?
      puts "❌ Please provide a new app name: rake app:rename[MyNewApp]"
      exit 1
    end

    # Validate app name format
    unless new_name.match?(/\A[A-Za-z][A-Za-z0-9_]*\z/)
      puts "❌ App name must start with a letter and contain only letters, numbers, and underscores"
      exit 1
    end

    puts "🏷️  Renaming application to: #{new_name}"

    snake_name = new_name.underscore
    kebab_name = new_name.underscore.gsub("_", "-")
    camel_name = new_name.camelize

    # Get current app name from application.rb for database migration
    current_app_name = nil
    app_file = "config/application.rb"
    if File.exist?(app_file)
      content = File.read(app_file)
      match = content.match(/module (\w+)/)
      current_app_name = match[1].underscore if match
    end

    # Update application.rb
    if File.exist?(app_file)
      content = File.read(app_file)
      updated_content = content.gsub(/module \w+/, "module #{camel_name}")
      File.write(app_file, updated_content)
      puts "✅ Updated #{app_file}"
    end

    # Update database.yml
    db_file = "config/database.yml"
    if File.exist?(db_file)
      content = File.read(db_file)
      # Replace any existing app name patterns with the new one
      updated_content = content.gsub(/rails_template/, snake_name)
      updated_content = updated_content.gsub(/#{current_app_name}/, snake_name) if current_app_name
      File.write(db_file, updated_content)
      puts "✅ Updated #{db_file}"
    end

    # Update docker-compose.yml
    docker_compose_file = "docker-compose.yml"
    if File.exist?(docker_compose_file)
      content = File.read(docker_compose_file)
      # Update database names in environment variables
      updated_content = content.gsub(/rails_template_development/, "#{snake_name}_development")
      updated_content = updated_content.gsub(/rails_template_test/, "#{snake_name}_test")
      updated_content = updated_content.gsub(/POSTGRES_DB: rails_template_development/, "POSTGRES_DB: #{snake_name}_development")
      # Update any current app database names
      if current_app_name
        updated_content = updated_content.gsub(/#{current_app_name}_development/, "#{snake_name}_development")
        updated_content = updated_content.gsub(/#{current_app_name}_test/, "#{snake_name}_test")
        updated_content = updated_content.gsub(/POSTGRES_DB: #{current_app_name}_development/, "POSTGRES_DB: #{snake_name}_development")
      end
      File.write(docker_compose_file, updated_content)
      puts "✅ Updated #{docker_compose_file}"
    end

    # Update package.json
    package_file = "package.json"
    if File.exist?(package_file)
      content = File.read(package_file)
      data = JSON.parse(content)
      data["name"] = kebab_name
      File.write(package_file, JSON.pretty_generate(data))
      puts "✅ Updated #{package_file}"
    end

    # Update README.md if it exists
    readme_file = "README.md"
    if File.exist?(readme_file)
      content = File.read(readme_file)
      # Update title and references
      updated_content = content.gsub(/# Rails Template/, "# #{new_name}")
      updated_content = updated_content.gsub(/rails_template/, snake_name)
      updated_content = updated_content.gsub(/rails-template/, kebab_name)
      if current_app_name
        updated_content = updated_content.gsub(/# #{current_app_name.humanize}/, "# #{new_name}")
        updated_content = updated_content.gsub(/#{current_app_name}/, snake_name)
      end
      File.write(readme_file, updated_content)
      puts "✅ Updated #{readme_file}"
    end

    # Update .env.example if it exists
    env_example_file = ".env.example"
    if File.exist?(env_example_file)
      content = File.read(env_example_file)
      updated_content = content.gsub(/APP_NAME=.*/, "APP_NAME=#{new_name}")
      updated_content = updated_content.gsub(/rails_template/, snake_name)
      if current_app_name
        updated_content = updated_content.gsub(/#{current_app_name}/, snake_name)
      end
      File.write(env_example_file, updated_content)
      puts "✅ Updated #{env_example_file}"
    end

    # Update app/views/layouts/_head.html.erb
    head_file = "app/views/layouts/_head.html.erb"
    if File.exist?(head_file)
      content = File.read(head_file)
      # Update title and description to reflect the new app name
      updated_content = content.gsub(/content_for\(:title\) \|\| "[^"]*"/, "content_for(:title) || \"#{new_name}\"")
      updated_content = updated_content.gsub(/content="[^"]*Rails starter template[^"]*"/, "content=\"#{new_name} - A modern Rails 8.0 application\"")
      updated_content = updated_content.gsub(/content="AllSpark[^"]*"/, "content=\"#{new_name} - A modern Rails 8.0 application\"")
      File.write(head_file, updated_content)
      puts "✅ Updated #{head_file}"
    end

    puts ""
    puts "🎉 Application renamed to #{new_name}!"
    puts ""
    puts "📋 Next steps:"
    puts "   1. Update your .env file with APP_NAME=#{new_name}"
    puts "   2. If using Docker, restart containers:"
    puts "      docker-compose down"
    puts "      docker volume rm #{kebab_name}_postgres_data #{kebab_name}_redis_data  # Optional: for fresh database"
    puts "      docker-compose up -d"
    puts "   3. Run database setup: rake db:setup (or rake setup:dev for full setup)"
    puts "   4. Review and update any custom configuration files"
    puts ""
    puts "💡 The database names have been updated to use '#{snake_name}' prefix."
  end
end
