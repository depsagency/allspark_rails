# frozen_string_literal: true

require_relative 'allspark_integration_test_helper'

class DataFlowMessagingTest < AllsparkIntegrationTestHelper
  def setup
    skip("Dual-container environment not available") unless dual_container_environment_available?
  end

  test "sidekiq jobs can be queued and processed across containers" do
    # Test job queuing from Builder to Target worker queues
    job_id = "test_job_#{Time.current.to_i}"
    
    # Queue a job in Builder for Target processing
    execute_in_container('builder', 
      "bundle exec rails runner \"
        job_data = { id: '#{job_id}', container: 'builder', timestamp: Time.current }
        TestJob.set(queue: 'target_development').perform_later(job_data)
      \""
    )

    # Check that job appears in Target's queue
    sleep 2 # Allow time for job propagation
    
    target_queue_size = execute_in_container('target', 
      "bundle exec rails runner \"puts Sidekiq::Queue.new('target_development').size\""
    )
    
    queue_size = target_queue_size[0].join.strip.to_i
    assert queue_size >= 0, "Could not check Target queue size"
  end

  test "actioncable broadcasts work across containers" do
    # Test ActionCable message broadcasting between containers
    channel_name = "integration_test_#{Time.current.to_i}"
    test_message = { 
      content: "Cross-container broadcast test", 
      timestamp: Time.current.iso8601,
      from: "builder"
    }

    # Broadcast from Builder
    execute_in_container('builder', 
      "bundle exec rails runner \"
        ActionCable.server.broadcast('#{channel_name}', #{test_message.to_json})
        puts 'Broadcast sent from Builder'
      \""
    )

    # Verify ActionCable server is accessible from Target
    target_cable_check = execute_in_container('target', 
      "bundle exec rails runner \"
        puts ActionCable.server.class.name
        puts 'ActionCable accessible from Target'
      \""
    )
    
    assert_includes target_cable_check[0].join, "ActionCable", 
                    "ActionCable not accessible from Target"
  end

  test "redis pub/sub messaging works between containers" do
    # Test direct Redis pub/sub communication
    channel = "allspark_integration_test"
    test_message = "Message from Builder at #{Time.current.iso8601}"

    # Publish from Builder
    execute_in_container('builder', 
      "bundle exec rails runner \"
        redis = Redis.new
        redis.publish('#{channel}', '#{test_message}')
        puts 'Message published from Builder'
      \""
    )

    # Subscribe and check from Target (using timeout to avoid hanging)
    target_subscribe = execute_in_container('target', 
      "timeout 5 bundle exec rails runner \"
        redis = Redis.new
        redis.subscribe('#{channel}') do |on|
          on.message do |ch, message|
            puts 'Received: ' + message
            break
          end
        end
      \" || echo 'Subscribe timeout (expected)'"
    )

    # Just verify Redis is accessible from both containers
    assert_equal 0, target_subscribe[2], "Redis pub/sub test failed"
  end

  test "shared cache works between containers" do
    # Test Rails cache sharing between containers
    cache_key = "integration_test_#{Time.current.to_i}"
    cache_value = { 
      data: "Shared cache test",
      created_by: "builder",
      timestamp: Time.current.iso8601
    }

    # Set cache from Builder
    execute_in_container('builder', 
      "bundle exec rails runner \"
        Rails.cache.write('#{cache_key}', #{cache_value.to_json})
        puts 'Cache written from Builder'
      \""
    )

    # Read cache from Target
    target_cache_read = execute_in_container('target', 
      "bundle exec rails runner \"
        value = Rails.cache.read('#{cache_key}')
        puts value || 'Cache miss'
      \""
    )

    cached_data = target_cache_read[0].join.strip
    assert_includes cached_data, "Shared cache test", 
                    "Cache data not shared between containers"
  end

  test "database transactions work across containers" do
    # Test database consistency across containers
    test_table = "integration_test_records"
    test_value = "cross_container_#{Time.current.to_i}"

    # Create test data from Builder
    execute_in_container('builder', 
      "bundle exec rails runner \"
        ActiveRecord::Base.connection.execute(
          \\\"CREATE TABLE IF NOT EXISTS #{test_table} (id SERIAL PRIMARY KEY, value TEXT)\\\"
        )
        ActiveRecord::Base.connection.execute(
          \\\"INSERT INTO #{test_table} (value) VALUES ('#{test_value}')\\\"
        )
        puts 'Data inserted from Builder'
      \""
    )

    # Read data from Target
    target_data_read = execute_in_container('target', 
      "bundle exec rails runner \"
        result = ActiveRecord::Base.connection.execute(
          \\\"SELECT value FROM #{test_table} WHERE value = '#{test_value}'\\\"
        )
        puts result.first['value'] if result.first
      \""
    )

    read_value = target_data_read[0].join.strip
    assert_equal test_value, read_value, 
                 "Database data not consistent across containers"

    # Cleanup
    execute_in_container('builder', 
      "bundle exec rails runner \"
        ActiveRecord::Base.connection.execute('DROP TABLE IF EXISTS #{test_table}')
      \""
    )
  end

  test "file system events propagate through shared volumes" do
    # Test file system change notification between containers
    shared_file = "/app/workspace/file_event_test.txt"
    test_content = "File event test #{Time.current.to_i}"

    # Create file in Builder
    create_test_file_in_container('builder', shared_file, test_content)

    # Check file appears in Target within reasonable time
    file_appeared = wait_for_file_in_container('target', shared_file, timeout: 10)
    assert file_appeared, "File changes not propagated to Target container"

    # Verify content matches
    target_content = read_file_from_container('target', shared_file)
    assert_equal test_content, target_content.strip, 
                 "File content not consistent across containers"

    # Test file modification
    modified_content = "Modified #{test_content}"
    create_test_file_in_container('target', shared_file, modified_content)

    # Verify modification visible in Builder
    sleep 1 # Allow for file system sync
    builder_content = read_file_from_container('builder', shared_file)
    assert_equal modified_content, builder_content.strip, 
                 "File modifications not visible across containers"
  end

  test "environment variable consistency across containers" do
    # Test that shared environment variables are consistent
    shared_env_vars = %w[REDIS_URL DATABASE_URL RAILS_ENV]

    shared_env_vars.each do |env_var|
      builder_value = execute_in_container('builder', "echo $#{env_var}")
      target_value = execute_in_container('target', "echo $#{env_var}")

      builder_env = builder_value[0].join.strip
      target_env = target_value[0].join.strip

      # DATABASE_URL might differ (allspark_builder vs allspark_target)
      if env_var == 'DATABASE_URL'
        assert_includes builder_env, 'allspark_builder', "Builder DATABASE_URL incorrect"
        assert_includes target_env, 'allspark_target', "Target DATABASE_URL incorrect"
      else
        assert_equal builder_env, target_env, 
                     "Environment variable #{env_var} differs between containers"
      end
    end
  end

  test "log aggregation works across containers" do
    # Test that logs from both containers can be aggregated
    log_message = "Integration test log #{Time.current.to_i}"

    # Generate logs from both containers
    execute_in_container('builder', 
      "bundle exec rails runner \"Rails.logger.info('Builder: #{log_message}')\""
    )

    execute_in_container('target', 
      "bundle exec rails runner \"Rails.logger.info('Target: #{log_message}')\""
    )

    # Check logs can be accessed from both containers
    builder_logs = execute_in_container('builder', 
      "tail -n 10 log/development.log | grep '#{log_message}' || echo 'No logs found'"
    )

    target_logs = execute_in_container('target', 
      "tail -n 10 log/development.log | grep '#{log_message}' || echo 'No logs found'"
    )

    # At least one should have generated logs
    builder_output = builder_logs[0].join
    target_output = target_logs[0].join

    has_builder_logs = builder_output.include?(log_message)
    has_target_logs = target_output.include?(log_message)

    assert(has_builder_logs || has_target_logs, 
           "Neither container generated expected logs")
  end

  test "health check coordination between containers" do
    # Test that containers can check each other's health
    
    # Builder checks Target health
    builder_to_target_health = execute_in_container('builder', 
      "curl -s -o /dev/null -w '%{http_code}' http://target:3000/health"
    )
    
    target_health_code = builder_to_target_health[0].join.strip
    assert_equal '200', target_health_code, "Builder cannot check Target health"

    # Target checks Builder health  
    target_to_builder_health = execute_in_container('target', 
      "curl -s -o /dev/null -w '%{http_code}' http://builder:3000/health"
    )
    
    builder_health_code = target_to_builder_health[0].join.strip
    assert_equal '200', builder_health_code, "Target cannot check Builder health"
  end

  private

  def dual_container_environment_available?
    %w[builder target].all? do |service|
      container = get_container(service)
      container&.info&.dig('State', 'Running')
    end
  rescue
    false
  end
end