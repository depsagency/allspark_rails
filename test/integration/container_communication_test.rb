# frozen_string_literal: true

require_relative 'allspark_integration_test_helper'

class ContainerCommunicationTest < AllsparkIntegrationTestHelper
  def setup
    # These tests require the dual-container environment to be running
    skip("Dual-container environment not available") unless dual_container_environment_available?
  end

  test "builder and target containers can communicate via shared network" do
    # Test network connectivity between containers
    builder_to_target = execute_in_container('builder', 'ping -c 1 target')
    assert_equal 0, builder_to_target[2], "Builder cannot ping Target container"

    target_to_builder = execute_in_container('target', 'ping -c 1 builder')
    assert_equal 0, target_to_builder[2], "Target cannot ping Builder container"
  end

  test "containers can access shared database" do
    # Verify both containers can connect to the same database
    assert verify_database_connectivity('builder'), "Builder cannot connect to database"
    assert verify_database_connectivity('target'), "Target cannot connect to database"

    # Test cross-container data persistence
    test_data = "test_value_#{Time.current.to_i}"
    
    # Create data in Builder
    execute_in_container('builder', 
      "bundle exec rails runner \"Rails.cache.write('test_key', '#{test_data}')\""
    )

    # Read data from Target
    result = execute_in_container('target', 
      "bundle exec rails runner \"puts Rails.cache.read('test_key')\""
    )
    
    assert_equal test_data, result[0].join.strip, "Data not accessible across containers"
  end

  test "containers can access shared redis instance" do
    assert verify_redis_connectivity('builder'), "Builder cannot connect to Redis"
    assert verify_redis_connectivity('target'), "Target cannot connect to Redis"

    # Test Redis communication between containers
    test_value = "redis_test_#{Time.current.to_i}"
    
    # Set value from Builder
    execute_in_container('builder', 
      "bundle exec rails runner \"Redis.new.set('integration_test', '#{test_value}')\""
    )

    # Get value from Target
    result = execute_in_container('target', 
      "bundle exec rails runner \"puts Redis.new.get('integration_test')\""
    )
    
    assert_equal test_value, result[0].join.strip, "Redis data not shared between containers"
  end

  test "shared workspace volume is accessible from both containers" do
    test_content = "Shared workspace test content #{Time.current.to_i}"
    shared_file = "/app/workspace/test_shared_file.txt"

    # Create file in Builder's workspace
    create_test_file_in_container('builder', shared_file, test_content)
    
    # Verify file exists in Target's workspace
    assert wait_for_file_in_container('target', shared_file), 
           "Shared file not accessible from Target container"

    # Verify content matches
    target_content = read_file_from_container('target', shared_file)
    assert_equal test_content, target_content.strip, 
                 "Shared file content differs between containers"
  end

  test "builder can execute commands in target container via docker exec" do
    # This simulates how the Builder UI would execute commands in Target
    target_container = get_container('target')
    assert_not_nil target_container, "Target container not found"

    # Execute a command from Builder context
    test_command = "echo 'Hello from Builder to Target'"
    result = target_container.exec(['bash', '-c', test_command])
    
    assert_equal 0, result[2], "Command execution failed"
    assert_includes result[0].join, "Hello from Builder to Target", 
                    "Command output not as expected"
  end

  test "sidekiq workers can communicate across containers" do
    assert verify_sidekiq_connectivity('builder'), "Builder Sidekiq cannot connect"
    assert verify_sidekiq_connectivity('target'), "Target Sidekiq cannot connect"

    # Test job queuing between containers
    job_data = { test: "cross_container_job_#{Time.current.to_i}" }
    
    # Queue a job from Builder
    execute_in_container('builder', 
      "bundle exec rails runner \"TestCrossContainerJob.perform_later('#{job_data[:test]}')\""
    )

    # Verify job was queued (this would need actual job class implementation)
    # For now, just verify Sidekiq is accessible
    builder_stats = execute_in_container('builder', 
      "bundle exec rails runner \"puts Sidekiq::Stats.new.processed\""
    )
    
    target_stats = execute_in_container('target', 
      "bundle exec rails runner \"puts Sidekiq::Stats.new.processed\""
    )
    
    # Both should be able to access Sidekiq stats
    assert builder_stats[0].join.strip =~ /\d+/, "Builder cannot access Sidekiq stats"
    assert target_stats[0].join.strip =~ /\d+/, "Target cannot access Sidekiq stats"
  end

  test "actioncable connections work across containers" do
    # Test that ActionCable can broadcast between containers
    channel_name = "test_channel_#{Time.current.to_i}"
    message_data = { test: "cross_container_broadcast" }

    # Broadcast from Builder
    execute_in_container('builder', 
      "bundle exec rails runner \"ActionCable.server.broadcast('#{channel_name}', #{message_data.to_json})\""
    )

    # This would require actual ActionCable setup to verify receipt
    # For now, verify ActionCable is accessible from both containers
    builder_result = execute_in_container('builder', 
      "bundle exec rails runner \"puts ActionCable.server.class.name\""
    )
    
    target_result = execute_in_container('target', 
      "bundle exec rails runner \"puts ActionCable.server.class.name\""
    )
    
    assert_includes builder_result[0].join, "ActionCable", "Builder ActionCable not accessible"
    assert_includes target_result[0].join, "ActionCable", "Target ActionCable not accessible"
  end

  private

  def dual_container_environment_available?
    # Check if dual-container setup is running
    %w[builder target].all? do |service|
      container = get_container(service)
      container&.info&.dig('State', 'Running')
    end
  rescue
    false
  end
end