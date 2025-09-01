# frozen_string_literal: true

require 'test_helper'
require 'docker'
require 'net/http'
require 'uri'

class AllsparkIntegrationTestHelper < ActiveSupport::TestCase
  include ActionCable::TestHelper

  # Test configuration constants
  BUILDER_PORT = 3001
  TARGET_PORT = 3000
  DB_PORT = 5432
  REDIS_PORT = 6379
  
  COMPOSE_FILE = 'docker-compose.dual.yml'
  CONTAINER_TIMEOUT = 30
  HEALTH_CHECK_RETRIES = 5
  HEALTH_CHECK_DELAY = 2

  class << self
    def setup_dual_container_environment
      puts "Setting up dual-container environment for integration tests..."
      
      # Stop any existing containers
      system("docker-compose -f #{COMPOSE_FILE} down -v --remove-orphans")
      
      # Start dual-container setup
      unless system("docker-compose -f #{COMPOSE_FILE} up -d")
        raise "Failed to start dual-container environment"
      end
      
      # Wait for containers to be healthy
      wait_for_containers_health
      
      puts "Dual-container environment ready"
    end

    def teardown_dual_container_environment
      puts "Tearing down dual-container environment..."
      system("docker-compose -f #{COMPOSE_FILE} down -v --remove-orphans")
    end

    def wait_for_containers_health
      containers = %w[builder target builder-sidekiq target-sidekiq db redis]
      
      containers.each do |container|
        wait_for_container_health(container)
      end
      
      # Wait for Rails apps to be ready
      wait_for_rails_app(BUILDER_PORT, "Builder")
      wait_for_rails_app(TARGET_PORT, "Target")
    end

    private

    def wait_for_container_health(container_name)
      HEALTH_CHECK_RETRIES.times do |attempt|
        if container_healthy?(container_name)
          puts "Container #{container_name} is healthy"
          return
        end
        
        puts "Waiting for container #{container_name} (attempt #{attempt + 1}/#{HEALTH_CHECK_RETRIES})"
        sleep HEALTH_CHECK_DELAY
      end
      
      raise "Container #{container_name} failed to become healthy"
    end

    def container_healthy?(container_name)
      full_name = "allspark-#{container_name}-1"
      result = `docker ps --filter "name=#{full_name}" --format "{{.Status}}"`.strip
      result.include?('Up')
    end

    def wait_for_rails_app(port, name)
      HEALTH_CHECK_RETRIES.times do |attempt|
        begin
          response = Net::HTTP.get_response(URI("http://localhost:#{port}/health"))
          if response.code == '200'
            puts "#{name} Rails app is ready on port #{port}"
            return
          end
        rescue => e
          # Continue retrying
        end
        
        puts "Waiting for #{name} Rails app on port #{port} (attempt #{attempt + 1}/#{HEALTH_CHECK_RETRIES})"
        sleep HEALTH_CHECK_DELAY
      end
      
      raise "#{name} Rails app failed to become ready on port #{port}"
    end
  end

  # Helper methods for tests
  def builder_url(path = '/')
    "http://localhost:#{BUILDER_PORT}#{path}"
  end

  def target_url(path = '/')
    "http://localhost:#{TARGET_PORT}#{path}"
  end

  def get_container(service)
    container_name = "allspark-#{service}-1"
    Docker::Container.all.find { |c| c.info['Names'].any? { |name| name.include?(container_name) } }
  end

  def execute_in_container(service, command)
    container = get_container(service)
    raise "Container #{service} not found" unless container
    
    container.exec(['bash', '-c', command])
  end

  def make_http_request(url, method: :get, params: {}, headers: {})
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    
    case method
    when :get
      request = Net::HTTP::Get.new(uri)
    when :post
      request = Net::HTTP::Post.new(uri)
      request.body = params.to_json if params.any?
      request['Content-Type'] = 'application/json'
    when :put
      request = Net::HTTP::Put.new(uri)
      request.body = params.to_json if params.any?
      request['Content-Type'] = 'application/json'
    when :delete
      request = Net::HTTP::Delete.new(uri)
    end
    
    headers.each { |key, value| request[key] = value }
    
    http.request(request)
  end

  def verify_database_connectivity(container)
    result = execute_in_container(container, 'bundle exec rails runner "puts ActiveRecord::Base.connection.execute(\'SELECT 1\').first"')
    result[0].join.strip == '1'
  end

  def verify_redis_connectivity(container)
    result = execute_in_container(container, 'bundle exec rails runner "puts Redis.new.ping"')
    result[0].join.strip == 'PONG'
  end

  def verify_sidekiq_connectivity(container)
    result = execute_in_container(container, 'bundle exec rails runner "puts Sidekiq.redis { |r| r.ping }"')
    result[0].join.strip == 'PONG'
  end

  def wait_for_file_in_container(container, file_path, timeout: 10)
    timeout.times do
      result = execute_in_container(container, "test -f #{file_path}")
      return true if result[2] == 0
      sleep 1
    end
    false
  end

  def create_test_file_in_container(container, file_path, content)
    escaped_content = content.gsub("'", "'\"'\"'")
    execute_in_container(container, "echo '#{escaped_content}' > #{file_path}")
  end

  def read_file_from_container(container, file_path)
    result = execute_in_container(container, "cat #{file_path}")
    result[0].join
  end
end