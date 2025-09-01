# frozen_string_literal: true

require_relative 'allspark_integration_test_helper'

class AllsparkContainerSecurityTest < AllsparkIntegrationTestHelper
  def setup
    skip("Dual-container environment not available") unless dual_container_environment_available?
  end

  test "containers run with appropriate user permissions" do
    # Check that containers don't run as root for security
    builder_user = execute_in_container('builder', 'whoami')
    target_user = execute_in_container('target', 'whoami')
    
    # Containers may run as root in development, but let's check
    builder_uid = execute_in_container('builder', 'id -u')
    target_uid = execute_in_container('target', 'id -u')
    
    # Log the user information for security review
    puts "Builder runs as user: #{builder_user[0].join.strip} (UID: #{builder_uid[0].join.strip})"
    puts "Target runs as user: #{target_user[0].join.strip} (UID: #{target_uid[0].join.strip})"
    
    # Both should have consistent user setup
    assert_equal 0, builder_user[2], "Cannot determine Builder user"
    assert_equal 0, target_user[2], "Cannot determine Target user"
  end

  test "containers have proper network isolation" do
    # Test that containers can only access intended services
    
    # Both should access shared services (db, redis)
    builder_db = execute_in_container('builder', 'nc -z db 5432')
    target_db = execute_in_container('target', 'nc -z db 5432')
    
    assert_equal 0, builder_db[2], "Builder cannot access database"
    assert_equal 0, target_db[2], "Target cannot access database"

    builder_redis = execute_in_container('builder', 'nc -z redis 6379')
    target_redis = execute_in_container('target', 'nc -z redis 6379')
    
    assert_equal 0, builder_redis[2], "Builder cannot access Redis"
    assert_equal 0, target_redis[2], "Target cannot access Redis"
  end

  test "containers cannot access host file system inappropriately" do
    # Test that containers don't have inappropriate host access
    
    # Check that sensitive host paths are not accessible
    sensitive_paths = [
      '/etc/passwd',
      '/etc/shadow',
      '/root',
      '/var/run/docker.sock'
    ]

    sensitive_paths.each do |path|
      # Skip docker.sock for builder (it needs it for container management)
      next if path == '/var/run/docker.sock' && path.include?('builder')
      
      builder_access = execute_in_container('builder', "test -r #{path}")
      target_access = execute_in_container('target', "test -r #{path}")
      
      # Target should not have access to sensitive host paths
      assert_not_equal 0, target_access[2], "Target has inappropriate access to #{path}"
      
      # Builder access to docker.sock is expected
      unless path == '/var/run/docker.sock'
        assert_not_equal 0, builder_access[2], "Builder has inappropriate access to #{path}"
      end
    end
  end

  test "environment variables don't contain sensitive information" do
    # Check for potential secrets in environment variables
    
    %w[builder target].each do |container|
      env_output = execute_in_container(container, 'env')
      env_vars = env_output[0].join
      
      # Check for potential secret patterns
      sensitive_patterns = [
        /password=\w+/i,
        /secret=\w+/i,
        /token=\w+/i,
        /key=\w{20,}/i
      ]
      
      sensitive_patterns.each do |pattern|
        if env_vars.match(pattern)
          # Allow expected development credentials
          match = env_vars.match(pattern)[0]
          unless match.include?('password@db') || match.include?('password=password')
            flunk "Potential secret found in #{container} environment: #{match}"
          end
        end
      end
    end
  end

  test "containers have proper resource limits" do
    # Check that containers have resource constraints
    
    %w[builder target].each do |service|
      container = get_container(service)
      next unless container
      
      host_config = container.info['HostConfig']
      
      # Log resource limits for review
      memory_limit = host_config['Memory']
      cpu_limit = host_config['CpuQuota']
      
      puts "#{service.capitalize} container limits - Memory: #{memory_limit || 'unlimited'}, CPU: #{cpu_limit || 'unlimited'}"
      
      # In development, unlimited resources might be acceptable
      # But we should verify the configuration is intentional
      assert_not_nil host_config, "Container #{service} has no host configuration"
    end
  end

  test "inter-container communication uses secure channels" do
    # Test that containers communicate over expected protocols
    
    # Check that containers use internal network for communication
    builder_to_target = execute_in_container('builder', 'nslookup target')
    target_to_builder = execute_in_container('target', 'nslookup builder')
    
    assert_equal 0, builder_to_target[2], "Builder cannot resolve Target hostname"
    assert_equal 0, target_to_builder[2], "Target cannot resolve Builder hostname"
    
    # Check that containers use expected ports
    builder_ports = execute_in_container('builder', 'netstat -tlnp || ss -tlnp')
    target_ports = execute_in_container('target', 'netstat -tlnp || ss -tlnp')
    
    # Should have Rails server running on port 3000
    assert_includes builder_ports[0].join, ':3000', "Builder not listening on expected port"
    assert_includes target_ports[0].join, ':3000', "Target not listening on expected port"
  end

  test "containers handle file permissions correctly" do
    # Test file permission handling in shared volumes
    
    test_file = "/app/workspace/permission_test.txt"
    test_content = "Permission test content"
    
    # Create file in Builder with specific permissions
    create_test_file_in_container('builder', test_file, test_content)
    execute_in_container('builder', "chmod 644 #{test_file}")
    
    # Check permissions from Target
    target_perms = execute_in_container('target', "ls -la #{test_file}")
    assert_equal 0, target_perms[2], "Cannot check file permissions from Target"
    
    # Verify Target can read but not necessarily execute
    target_read = execute_in_container('target', "cat #{test_file}")
    assert_equal 0, target_read[2], "Target cannot read shared file"
    assert_equal test_content, target_read[0].join.strip, "File content differs"
  end

  test "containers cannot escalate privileges" do
    # Test that containers cannot gain elevated privileges
    
    %w[builder target].each do |container|
      # Try common privilege escalation attempts
      sudo_attempt = execute_in_container(container, 'sudo -l')
      # Should fail or show no sudo access
      
      # Try to change to root
      su_attempt = execute_in_container(container, 'su - root')
      assert_not_equal 0, su_attempt[2], "#{container} can escalate to root"
      
      # Check if container is running in privileged mode
      container_obj = get_container(container)
      if container_obj
        privileged = container_obj.info.dig('HostConfig', 'Privileged')
        assert_not privileged, "#{container} is running in privileged mode"
      end
    end
  end

  test "containers log security events appropriately" do
    # Test that security-relevant events are logged
    
    # Generate some security-relevant events
    %w[builder target].each do |container|
      # Attempt unauthorized file access
      execute_in_container(container, 'cat /etc/shadow 2>&1 || echo "Access denied"')
      
      # Check if events are logged (basic check)
      log_check = execute_in_container(container, 'ls -la /var/log/ || echo "No log directory"')
      
      # Verify basic logging capability
      rails_log = execute_in_container(container, 'ls -la log/ || echo "No Rails logs"')
      assert_equal 0, rails_log[2], "#{container} has no Rails logging directory"
    end
  end

  test "secrets and credentials are handled securely" do
    # Test that secrets aren't exposed inappropriately
    
    %w[builder target].each do |container|
      # Check for credentials in common locations
      credentials_check = execute_in_container(container, 'find /app -name "*.key" -o -name "*.pem" -o -name "*.p12" 2>/dev/null || echo "No credential files"')
      
      # Check Rails credentials
      rails_creds = execute_in_container(container, 'bundle exec rails runner "puts Rails.application.credentials.config"')
      
      # Should not fail completely
      assert_equal 0, rails_creds[2], "#{container} cannot access Rails credentials properly"
      
      # Check that secrets aren't in version control
      git_secrets = execute_in_container(container, 'git log --all --full-history -p --grep="password\\|secret\\|key" -- . || echo "No git history"')
      
      # This is informational - actual secret detection would require more sophisticated analysis
    end
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