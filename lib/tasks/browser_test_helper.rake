# frozen_string_literal: true

namespace :browser do
  namespace :debug do
    desc "Test Chrome/Chromium availability and configuration"
    task chrome_test: :environment do
      puts "=== Chrome/Chromium Debug Information ==="
      
      # Check for Chrome/Chromium binary
      chrome_paths = [
        ENV['CHROME_BIN'],
        ENV['CHROMIUM_BIN'],
        '/usr/bin/chromium',
        '/usr/bin/chromium-browser',
        '/usr/bin/google-chrome',
        '/usr/bin/google-chrome-stable'
      ].compact
      
      chrome_path = chrome_paths.find { |path| File.exist?(path) }
      
      if chrome_path
        puts "✅ Chrome/Chromium found at: #{chrome_path}"
        
        # Test Chrome version
        version_output = `#{chrome_path} --version 2>&1`
        puts "Version: #{version_output.strip}"
        
        # Test Chrome with our flags
        puts "\nTesting Chrome with Docker flags..."
        test_command = "#{chrome_path} --headless --no-sandbox --disable-dev-shm-usage --disable-gpu --dump-dom https://example.com 2>&1"
        test_output = `timeout 10 #{test_command}`
        
        if $?.success?
          puts "✅ Chrome runs successfully with our flags"
        else
          puts "❌ Chrome failed to run with our flags"
          puts "Error output: #{test_output[0..500]}..."
        end
      else
        puts "❌ Chrome/Chromium not found in expected locations"
        puts "Searched paths: #{chrome_paths.join(', ')}"
      end
      
      # Check environment variables
      puts "\n=== Environment Variables ==="
      puts "DOCKER_CONTAINER: #{ENV['DOCKER_CONTAINER'] || 'not set'}"
      puts "CHROME_BIN: #{ENV['CHROME_BIN'] || 'not set'}"
      puts "CHROMIUM_BIN: #{ENV['CHROMIUM_BIN'] || 'not set'}"
      
      # Check shared memory
      puts "\n=== Shared Memory ==="
      shm_size = `df -h /dev/shm 2>&1`.split("\n").last
      puts "Shared memory (/dev/shm): #{shm_size}"
      
      # Check system resources
      puts "\n=== System Resources ==="
      puts "Memory: #{`free -h 2>&1`.split("\n")[1]}"
      puts "Processes: #{`ps aux | wc -l`.strip} running"
    end
    
    desc "Test simple Chrome screenshot"
    task simple_screenshot: :environment do
      require 'fileutils'
      
      chrome_path = ENV['CHROME_BIN'] || ENV['CHROMIUM_BIN'] || '/usr/bin/chromium'
      output_path = Rails.root.join('tmp', 'test_screenshot.png')
      FileUtils.mkdir_p(File.dirname(output_path))
      
      puts "Taking screenshot with Chrome directly..."
      
      command = %Q{#{chrome_path} \
        --headless \
        --no-sandbox \
        --disable-dev-shm-usage \
        --disable-gpu \
        --window-size=1280,800 \
        --screenshot=#{output_path} \
        https://example.com 2>&1}
      
      output = `#{command}`
      
      if File.exist?(output_path)
        puts "✅ Screenshot saved to: #{output_path}"
        puts "File size: #{File.size(output_path)} bytes"
      else
        puts "❌ Screenshot failed"
        puts "Command output: #{output}"
      end
    end
  end
end