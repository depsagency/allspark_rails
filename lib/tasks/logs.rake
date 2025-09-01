# frozen_string_literal: true

namespace :logs do
  desc "Show recent logs from all containers"
  task :recent, [:minutes] => :environment do |t, args|
    minutes = (args[:minutes] || 5).to_i
    
    puts "📋 Showing logs from the last #{minutes} minutes"
    puts "=" * 50
    
    aggregator = BrowserTesting::LogAggregator.new
    logs = aggregator.collect_recent_logs(minutes)
    
    # Show Rails logs
    if logs[:rails].any?
      puts "\n📝 RAILS LOGS:"
      logs[:rails].last(30).each { |line| puts line }
    end
    
    # Show Docker logs
    if logs[:docker]
      logs[:docker].each do |service, service_logs|
        if service_logs.any?
          puts "\n🐳 #{service.upcase} LOGS:"
          service_logs.last(20).each { |line| puts line }
        end
      end
    end
    
    # Show system info
    if logs[:system]
      puts "\n💻 SYSTEM INFO:"
      puts "Memory: #{logs[:system][:memory][:used_percent]}% used" if logs[:system][:memory][:used_percent]
      puts "Disk: #{logs[:system][:disk][:used_percent]} used" if logs[:system][:disk][:used_percent]
    end
    
    puts "\n" + "=" * 50
  end

  desc "Tail logs from a specific service"
  task :tail, [:service] => :environment do |t, args|
    service = args[:service] || "web"
    
    puts "📋 Tailing logs for #{service}..."
    puts "Press Ctrl+C to stop"
    puts "=" * 50
    
    begin
      if File.exist?("/.dockerenv")
        # Inside container
        system("tail -f log/#{Rails.env}.log")
      else
        # On host
        system("docker-compose logs -f #{service}")
      end
    rescue Interrupt
      puts "\nStopped tailing logs"
    end
  end

  desc "Search logs for errors"
  task :errors, [:minutes] => :environment do |t, args|
    minutes = (args[:minutes] || 60).to_i
    
    puts "❌ Searching for errors in the last #{minutes} minutes"
    puts "=" * 50
    
    aggregator = BrowserTesting::LogAggregator.new
    logs = aggregator.collect_recent_logs(minutes)
    
    # Parse logs for errors
    if logs[:rails].any?
      parsed = BrowserTesting::LogParser.parse_rails_logs(logs[:rails])
      
      if parsed[:errors].any?
        puts "\n📝 RAILS ERRORS (#{parsed[:errors].size}):"
        parsed[:errors].each_with_index do |error, i|
          puts "\n#{i + 1}. #{error[:message]}"
          puts "   Timestamp: #{error[:timestamp]}" if error[:timestamp]
          puts "   Type: #{error[:exception_class]}" if error[:exception_class]
        end
      end
      
      if parsed[:summary][:failed_requests] > 0
        puts "\n📊 Failed Requests: #{parsed[:summary][:failed_requests]}"
      end
    end
    
    # Check Docker logs for errors
    if logs[:docker]
      docker_parsed = BrowserTesting::LogParser.parse_docker_logs(logs[:docker])
      
      docker_parsed.each do |service, results|
        if results[:errors].any?
          puts "\n🐳 #{service.upcase} ERRORS (#{results[:errors].size}):"
          results[:errors].first(5).each do |error|
            puts "  - #{error[:message]}"
          end
        end
      end
    end
    
    puts "\n" + "=" * 50
  end
end

namespace :docker do
  desc "Check health of all containers"
  task :health => :environment do
    puts "🏥 Docker Container Health Check"
    puts "=" * 50
    
    # Get container status
    output = `docker-compose ps 2>&1`
    
    if $?.success?
      puts output
      
      # Check if all expected services are running
      expected_services = %w[web sidekiq db redis]
      running_services = output.scan(/(\w+)-\d+\s+.*\s+Up/).flatten
      
      expected_services.each do |service|
        if running_services.any? { |s| s.include?(service) }
          puts "✅ #{service}: Running"
        else
          puts "❌ #{service}: Not running"
        end
      end
    else
      puts "❌ Error checking container status"
      puts output
    end
    
    puts "=" * 50
  end
end