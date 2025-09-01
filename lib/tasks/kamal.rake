# frozen_string_literal: true

namespace :kamal do
  desc "Setup Kamal deployment configuration"
  task :setup do
    require 'fileutils'
    require 'securerandom'

    puts "\n🚀 Setting up Kamal deployment configuration...\n\n"

    # Copy example files if they don't exist
    unless File.exist?('.kamal/secrets')
      FileUtils.cp('.kamal/secrets.example', '.kamal/secrets')
      puts "✅ Created .kamal/secrets - Please edit with your credentials"
    else
      puts "ℹ️  .kamal/secrets already exists"
    end

    unless File.exist?('config/deploy.yml')
      FileUtils.cp('config/deploy.yml.example', 'config/deploy.yml')
      puts "✅ Created config/deploy.yml - Please edit with your server details"
    else
      puts "ℹ️  config/deploy.yml already exists"
    end

    # Interactive setup if requested
    if ENV['INTERACTIVE'] == 'true'
      puts "\n📝 Interactive Setup\n\n"

      # Get app name
      print "Enter your app name (lowercase, no spaces) [#{Rails.application.class.module_parent_name.underscore}]: "
      app_name = STDIN.gets.strip
      app_name = Rails.application.class.module_parent_name.underscore if app_name.empty?

      # Get server IP
      print "Enter your server IP address: "
      server_ip = STDIN.gets.strip
      if server_ip.empty?
        puts "❌ Server IP is required"
        exit 1
      end

      # Get domain
      print "Enter your domain name (or press enter to use IP): "
      domain = STDIN.gets.strip
      domain = server_ip if domain.empty?

      # Get Docker Hub username
      print "Enter your Docker Hub username: "
      docker_user = STDIN.gets.strip
      if docker_user.empty?
        puts "❌ Docker Hub username is required"
        exit 1
      end

      # Generate secure passwords
      postgres_password = SecureRandom.alphanumeric(32)
      puts "\n✅ Generated secure PostgreSQL password"

      # Update deploy.yml with provided values
      if File.exist?('config/deploy.yml')
        deploy_content = File.read('config/deploy.yml')
        deploy_content.gsub!('YOUR_APP_NAME', app_name)
        deploy_content.gsub!('YOUR_SERVER_IP_HERE', server_ip)
        deploy_content.gsub!('YOUR_DOCKER_USERNAME', docker_user)
        deploy_content.gsub!('YOUR_DOMAIN_HERE', domain)
        File.write('config/deploy.yml', deploy_content)
        puts "✅ Updated config/deploy.yml with your values"
      end

      # Update .kamal/secrets with app name and generated password
      if File.exist?('.kamal/secrets')
        secrets_content = File.read('.kamal/secrets')
        secrets_content.gsub!('${APP_NAME}', app_name)
        secrets_content.gsub!('$POSTGRES_PASSWORD', postgres_password)
        File.write('.kamal/secrets', secrets_content)
        puts "✅ Updated .kamal/secrets with app name and generated password"
      end

      puts "\n📋 Next Steps:\n\n"
      puts "1. Edit .kamal/secrets to add your:"
      puts "   - Docker registry token (DOCKER_REGISTRY_TOKEN)"
      puts "   - Rails master key (from config/master.key)"
      puts "   - LLM API keys (if using AI features)"
      puts "   - Any other service credentials"
      puts ""
      puts "2. Review config/deploy.yml and adjust if needed"
      puts ""
      puts "3. Set up your server with Docker:"
      puts "   ssh root@#{server_ip} 'curl -fsSL https://get.docker.com | sh'"
      puts ""
      puts "4. Deploy with: kamal deploy"
      puts ""
      puts "Generated PostgreSQL password: #{postgres_password}"
      puts "(Save this password - you'll need it for database access)"
    else
      puts "\n📋 Next Steps:\n\n"
      puts "1. Edit config/deploy.yml with your server details"
      puts "2. Edit .kamal/secrets with your credentials"
      puts "3. Run: kamal deploy"
      puts ""
      puts "For interactive setup, run: rake kamal:setup INTERACTIVE=true"
    end
  end

  desc "Validate Kamal configuration"
  task :validate => :environment do
    errors = []

    # Check for required files
    unless File.exist?('config/deploy.yml')
      errors << "config/deploy.yml not found. Run: rake kamal:setup"
    end

    unless File.exist?('.kamal/secrets')
      errors << ".kamal/secrets not found. Run: rake kamal:setup"
    end

    # Check for placeholder values if files exist
    if File.exist?('config/deploy.yml')
      deploy_content = File.read('config/deploy.yml')
      if deploy_content.include?('YOUR_') || deploy_content.include?('_HERE')
        errors << "config/deploy.yml contains placeholder values. Please update them."
      end
    end

    if File.exist?('.kamal/secrets')
      secrets_content = File.read('.kamal/secrets')
      if secrets_content.include?('$') && !secrets_content.include?('$(')
        errors << ".kamal/secrets may contain unset environment variables. Please check all values."
      end
    end

    if errors.any?
      puts "❌ Kamal configuration validation failed:\n\n"
      errors.each { |error| puts "  - #{error}" }
      exit 1
    else
      puts "✅ Kamal configuration looks good!"
    end
  end

  desc "Show deployment checklist"
  task :checklist do
    puts "\n📋 Kamal Deployment Checklist\n\n"
    puts "□ Server has Docker installed"
    puts "□ config/deploy.yml exists and is configured"
    puts "□ .kamal/secrets exists and has all credentials"
    puts "□ Docker Hub account created and logged in locally"
    puts "□ Rails master key is set in .kamal/secrets"
    puts "□ Domain DNS points to server IP"
    puts "□ LLM API keys configured (if using AI features)"
    puts ""
    puts "Ready? Run: kamal deploy"
  end
end