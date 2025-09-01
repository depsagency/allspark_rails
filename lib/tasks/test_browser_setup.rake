# frozen_string_literal: true

namespace :test do
  desc "Test browser testing setup"
  task :browser_setup => :environment do
    puts "🧪 Testing browser testing setup..."
    
    # Test 1: Check if gems are available
    begin
      require 'capybara'
      require 'capybara/cuprite'
      puts "✅ Browser testing gems available"
    rescue LoadError => e
      puts "❌ Missing gems: #{e.message}"
      puts "Run: bundle install"
      exit 1
    end
    
    # Test 2: Check if server is running
    begin
      require 'net/http'
      require 'timeout'
      
      Timeout.timeout(3) do
        response = Net::HTTP.get_response(URI("http://localhost:3000/"))
        if response.code.to_i < 500
          puts "✅ Server is running on localhost:3000"
        else
          puts "⚠️  Server responded with #{response.code}"
        end
      end
    rescue
      puts "❌ Server not running on localhost:3000"
      puts "Start with: bin/dev or rails server"
      exit 1
    end
    
    # Test 3: Try to configure Capybara
    begin
      Capybara.register_driver :cuprite do |app|
        Capybara::Cuprite::Driver.new(
          app, 
          headless: true, 
          js_errors: false,
          timeout: 30,
          process_timeout: 30,
          browser_options: {
            'no-sandbox' => nil,
            'disable-dev-shm-usage' => nil,
            'disable-gpu' => nil
          }
        )
      end
      puts "✅ Capybara configured successfully"
    rescue => e
      puts "❌ Capybara configuration failed: #{e.message}"
      exit 1
    end
    
    # Test 4: Try to create a simple session
    begin
      session = Capybara::Session.new(:cuprite)
      session.visit("http://localhost:3000/")
      puts "✅ Browser session created and page loaded"
      session.quit
    rescue => e
      puts "❌ Browser session failed: #{e.message}"
      exit 1
    end
    
    puts "\n🎉 Browser testing setup is working!"
    puts "\nYou can now run:"
    puts "  rake \"browser:test[/]\""
    puts "  rake \"browser:journey[user_registration]\""
  end
end