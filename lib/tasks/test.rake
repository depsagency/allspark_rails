# frozen_string_literal: true

namespace :test do
  desc "Run all tests with coverage report"
  task all: :environment do
    puts "Running comprehensive test suite..."

    # Run RSpec tests
    puts "\n=== Running RSpec Tests ==="
    system("bundle exec rspec")

    # Run system tests if they exist
    if Dir.glob("spec/system/**/*_spec.rb").any?
      puts "\n=== Running System Tests ==="
      system("bundle exec rspec spec/system")
    end

    # Display coverage report
    puts "\n=== Test Coverage Report ==="
    if File.exist?("coverage/index.html")
      puts "Coverage report generated at: coverage/index.html"
      puts "Open in browser: open coverage/index.html"
    end
  end

  desc "Run tests with coverage and quality checks"
  task quality: :environment do
    puts "Running tests with quality checks..."

    # Run tests first
    Rake::Task["test:all"].invoke

    # Run quality checks
    puts "\n=== Running Quality Checks ==="
    system("bundle exec rake quality:all")

    puts "\n=== All tests and quality checks completed ==="
  end

  desc "Run specific test types"
  task :models do
    puts "Running model tests..."
    system("bundle exec rspec spec/models")
  end

  task :controllers do
    puts "Running controller tests..."
    system("bundle exec rspec spec/controllers")
  end

  task :requests do
    puts "Running request tests..."
    system("bundle exec rspec spec/requests")
  end

  task :components do
    puts "Running component tests..."
    system("bundle exec rspec spec/components")
  end

  task :channels do
    puts "Running channel tests..."
    system("bundle exec rspec spec/channels")
  end

  task :services do
    puts "Running service tests..."
    system("bundle exec rspec spec/services")
  end

  task :jobs do
    puts "Running job tests..."
    system("bundle exec rspec spec/jobs")
  end

  task :policies do
    puts "Running policy tests..."
    system("bundle exec rspec spec/policies")
  end

  task :system do
    puts "Running system tests..."
    system("bundle exec rspec spec/system")
  end

  desc "Run tests that match a pattern"
  task :grep, [ :pattern ] do |task, args|
    pattern = args[:pattern]
    if pattern.blank?
      puts "Usage: rake test:grep[pattern]"
      exit 1
    end

    puts "Running tests matching pattern: #{pattern}"
    system("bundle exec rspec --grep '#{pattern}'")
  end

  desc "Run tests for a specific file"
  task :file, [ :file_path ] do |task, args|
    file_path = args[:file_path]
    if file_path.blank?
      puts "Usage: rake test:file[spec/models/user_spec.rb]"
      exit 1
    end

    unless File.exist?(file_path)
      puts "File not found: #{file_path}"
      exit 1
    end

    puts "Running tests in: #{file_path}"
    system("bundle exec rspec #{file_path}")
  end

  desc "Run tests in parallel"
  task :parallel do
    puts "Running tests in parallel..."
    system("bundle exec parallel_rspec spec/")
  end

  desc "Run tests with profiling"
  task :profile do
    puts "Running tests with profiling..."
    system("bundle exec rspec --profile 10")
  end

  desc "Run failing tests only"
  task :failures do
    puts "Running only failing tests..."
    system("bundle exec rspec --only-failures")
  end

  desc "Generate test data for development"
  task seed_data: :environment do
    puts "Generating test data for development..."

    # Create admin user
    admin = User.find_or_create_by(email: "admin@example.com") do |user|
      user.first_name = "Admin"
      user.last_name = "User"
      user.password = "password123"
      user.password_confirmation = "password123"
      user.role = "system_admin"
    end
    puts "Created admin user: #{admin.email}"

    # Create regular users
    5.times do |i|
      user = User.find_or_create_by(email: "user#{i+1}@example.com") do |u|
        u.first_name = Faker::Name.first_name
        u.last_name = Faker::Name.last_name
        u.password = "password123"
        u.password_confirmation = "password123"
      end
      puts "Created user: #{user.email}"

      # Create notifications for each user
      3.times do
        user.notifications.create!(
          title: Faker::Lorem.sentence(word_count: 3),
          message: Faker::Lorem.paragraph(sentence_count: 2),
          notification_type: [ "info", "success", "warning" ].sample,
          sender: admin
        )
      end
    end

    puts "Test data generation completed!"
  end

  desc "Clean up test artifacts"
  task :clean do
    puts "Cleaning up test artifacts..."

    # Remove coverage files
    FileUtils.rm_rf("coverage") if Dir.exist?("coverage")

    # Remove test screenshots
    FileUtils.rm_rf("tmp/screenshots") if Dir.exist?("tmp/screenshots")
    FileUtils.mkdir_p("tmp/screenshots")

    # Remove VCR cassettes (optional - uncomment if needed)
    # FileUtils.rm_rf("spec/cassettes") if Dir.exist?("spec/cassettes")

    # Remove example status file
    FileUtils.rm("spec/examples.txt") if File.exist?("spec/examples.txt")

    puts "Test cleanup completed!"
  end

  desc "Setup test environment"
  task setup: :environment do
    puts "Setting up test environment..."

    # Create test database
    system("bundle exec rails db:test:prepare")

    # Create necessary directories
    FileUtils.mkdir_p("tmp/screenshots")
    FileUtils.mkdir_p("spec/cassettes")

    # Generate SimpleCov directories
    FileUtils.mkdir_p("coverage")

    puts "Test environment setup completed!"
  end

  desc "Show test statistics"
  task :stats do
    puts "Test Statistics:"
    puts "==============="

    # Count spec files
    spec_files = Dir.glob("spec/**/*_spec.rb")
    puts "Total spec files: #{spec_files.count}"

    # Count by type
    %w[models controllers requests components channels services jobs policies system].each do |type|
      count = Dir.glob("spec/#{type}/**/*_spec.rb").count
      puts "#{type.capitalize} specs: #{count}" if count > 0
    end

    # Show factory count
    factory_files = Dir.glob("spec/factories/**/*.rb")
    puts "Factory files: #{factory_files.count}"

    # Show support files
    support_files = Dir.glob("spec/support/**/*.rb")
    puts "Support files: #{support_files.count}"

    # Show coverage if available
    if File.exist?("coverage/.last_run.json")
      require "json"
      coverage_data = JSON.parse(File.read("coverage/.last_run.json"))
      puts "Last coverage: #{coverage_data['result']['line']}%"
    end
  end

  desc "Validate test setup"
  task validate: :environment do
    puts "Validating test setup..."

    errors = []

    # Check for required files
    required_files = [
      "spec/rails_helper.rb",
      "spec/spec_helper.rb",
      "spec/support/factory_bot.rb"
    ]

    required_files.each do |file|
      unless File.exist?(file)
        errors << "Missing required file: #{file}"
      end
    end

    # Check for factories
    if Dir.glob("spec/factories/**/*.rb").empty?
      errors << "No factory files found in spec/factories/"
    end

    # Check database connection
    begin
      ActiveRecord::Base.connection.execute("SELECT 1")
    rescue => e
      errors << "Database connection failed: #{e.message}"
    end

    # Check for essential gems
    essential_gems = %w[rspec-rails factory_bot_rails faker]
    essential_gems.each do |gem_name|
      begin
        require gem_name.tr("-", "/")
      rescue LoadError
        errors << "Missing essential gem: #{gem_name}"
      end
    end

    if errors.any?
      puts "❌ Test setup validation failed:"
      errors.each { |error| puts "  - #{error}" }
      exit 1
    else
      puts "✅ Test setup validation passed!"
    end
  end
end

# Alias for convenience
task spec: "test:all"
