# frozen_string_literal: true

namespace :integration do
  desc "Run all Allspark integration tests"
  task all: :environment do
    puts "🚀 Running Allspark Integration Tests"
    puts "=" * 50
    
    # Setup dual-container environment
    puts "Setting up dual-container environment..."
    AllsparkIntegrationTestHelper.setup_dual_container_environment
    
    begin
      # Run integration test suites
      test_suites = [
        'test/integration/container_communication_test.rb',
        'test/integration/api_endpoint_integration_test.rb',
        'test/integration/data_flow_messaging_test.rb',
        'test/integration/claude_code_integration_test.rb',
        'test/integration/allspark_container_security_test.rb'
      ]
      
      test_suites.each do |test_suite|
        puts "\n📋 Running #{File.basename(test_suite, '.rb').humanize}..."
        system("bundle exec rails test #{test_suite}")
      end
      
      puts "\n✅ All integration tests completed"
      
    ensure
      # Cleanup dual-container environment
      puts "\n🧹 Cleaning up dual-container environment..."
      AllsparkIntegrationTestHelper.teardown_dual_container_environment
    end
  end

  desc "Run container communication tests"
  task communication: :environment do
    puts "🔗 Testing container communication..."
    AllsparkIntegrationTestHelper.setup_dual_container_environment
    
    begin
      system("bundle exec rails test test/integration/container_communication_test.rb")
    ensure
      AllsparkIntegrationTestHelper.teardown_dual_container_environment
    end
  end

  desc "Run API endpoint integration tests"
  task api: :environment do
    puts "🌐 Testing API endpoints..."
    AllsparkIntegrationTestHelper.setup_dual_container_environment
    
    begin
      system("bundle exec rails test test/integration/api_endpoint_integration_test.rb")
    ensure
      AllsparkIntegrationTestHelper.teardown_dual_container_environment
    end
  end

  desc "Run data flow and messaging tests"
  task messaging: :environment do
    puts "📨 Testing data flow and messaging..."
    AllsparkIntegrationTestHelper.setup_dual_container_environment
    
    begin
      system("bundle exec rails test test/integration/data_flow_messaging_test.rb")
    ensure
      AllsparkIntegrationTestHelper.teardown_dual_container_environment
    end
  end

  desc "Run Claude Code integration tests"
  task claude: :environment do
    puts "🤖 Testing Claude Code integration..."
    AllsparkIntegrationTestHelper.setup_dual_container_environment
    
    begin
      system("bundle exec rails test test/integration/claude_code_integration_test.rb")
    ensure
      AllsparkIntegrationTestHelper.teardown_dual_container_environment
    end
  end

  desc "Run container security tests"
  task security: :environment do
    puts "🔒 Testing container security..."
    AllsparkIntegrationTestHelper.setup_dual_container_environment
    
    begin
      system("bundle exec rails test test/integration/allspark_container_security_test.rb")
    ensure
      AllsparkIntegrationTestHelper.teardown_dual_container_environment
    end
  end

  desc "Setup dual-container environment for manual testing"
  task setup: :environment do
    puts "🏗️ Setting up dual-container environment..."
    AllsparkIntegrationTestHelper.setup_dual_container_environment
    puts "✅ Environment ready!"
    puts "   Builder: http://localhost:3001"
    puts "   Target:  http://localhost:3000"
    puts "   Run 'rake integration:teardown' when finished"
  end

  desc "Teardown dual-container environment"
  task teardown: :environment do
    puts "🧹 Tearing down dual-container environment..."
    AllsparkIntegrationTestHelper.teardown_dual_container_environment
    puts "✅ Environment cleaned up"
  end

  desc "Check integration test environment status"
  task status: :environment do
    puts "📊 Checking integration test environment status..."
    
    containers = %w[builder target builder-sidekiq target-sidekiq db redis]
    
    containers.each do |container|
      container_name = "allspark-#{container}-1"
      status = `docker ps --filter "name=#{container_name}" --format "{{.Status}}"`.strip
      
      if status.empty?
        puts "❌ #{container}: Not running"
      elsif status.include?('Up')
        uptime = status.match(/Up (.+?)(\s+\(|$)/)[1] rescue 'unknown'
        puts "✅ #{container}: Running (#{uptime})"
      else
        puts "⚠️  #{container}: #{status}"
      end
    end
    
    # Check port accessibility
    puts "\n🌐 Checking port accessibility..."
    
    begin
      require 'net/http'
      
      builder_response = Net::HTTP.get_response(URI('http://localhost:3001/health'))
      puts "✅ Builder (3001): #{builder_response.code}"
    rescue => e
      puts "❌ Builder (3001): #{e.message}"
    end
    
    begin
      target_response = Net::HTTP.get_response(URI('http://localhost:3000/health'))
      puts "✅ Target (3000): #{target_response.code}"
    rescue => e
      puts "❌ Target (3000): #{e.message}"
    end
  end

  desc "Run integration tests in CI mode (non-interactive)"
  task ci: :environment do
    puts "🤖 Running integration tests in CI mode..."
    
    # Set CI environment variables
    ENV['RAILS_ENV'] = 'test'
    ENV['CI'] = 'true'
    
    # Run tests with appropriate settings for CI
    Rake::Task['integration:all'].invoke
  end

  desc "Generate integration test report"
  task report: :environment do
    puts "📋 Generating integration test report..."
    
    require 'json'
    
    report = {
      timestamp: Time.current.iso8601,
      environment: Rails.env,
      containers: {},
      test_results: {}
    }
    
    # Check container status
    containers = %w[builder target builder-sidekiq target-sidekiq db redis]
    
    containers.each do |container|
      container_name = "allspark-#{container}-1"
      status = `docker ps --filter "name=#{container_name}" --format "{{.Status}}"`.strip
      
      report[:containers][container] = {
        status: status.empty? ? 'not_running' : (status.include?('Up') ? 'running' : 'unknown'),
        details: status
      }
    end
    
    # Save report
    report_file = "tmp/integration_test_report_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json"
    File.write(report_file, JSON.pretty_generate(report))
    
    puts "✅ Report saved to #{report_file}"
    puts JSON.pretty_generate(report)
  end
end

# Add integration tests to the main test task
task test: 'integration:all' if Rails.env.test?