# Allspark Integration Tests

This directory contains comprehensive integration tests for the Allspark dual-container architecture, covering all interaction points between the Builder and Target containers.

## Overview

The Allspark platform uses a dual-container architecture:
- **Builder Container** (port 3001): Allspark UI and management interface
- **Target Container** (port 3000): Development environment for user applications

These integration tests ensure that all interactions between these containers work correctly.

## Test Suites

### 1. Container Communication Test (`container_communication_test.rb`)
Tests basic communication capabilities between containers:
- Network connectivity between Builder and Target
- Shared database access and data persistence
- Redis connectivity and cross-container data sharing
- Shared workspace volume accessibility
- Docker exec functionality from Builder to Target
- Sidekiq worker communication
- ActionCable cross-container functionality

### 2. API Endpoint Integration Test (`api_endpoint_integration_test.rb`)
Tests API interactions between containers:
- Different applications served on different ports
- Container management API endpoints
- Cross-container API communication
- File operations via API
- Terminal session management
- Real-time communication channels
- Claude Code integration endpoints
- MCP server integration
- Workflow Builder API endpoints
- Independent authentication systems
- Database migration coordination

### 3. Data Flow and Messaging Test (`data_flow_messaging_test.rb`)
Tests data flow and messaging between containers:
- Sidekiq job queuing and processing across containers
- ActionCable broadcasting between containers
- Redis pub/sub messaging
- Shared Rails cache functionality
- Database transaction consistency
- File system event propagation
- Environment variable consistency
- Log aggregation across containers
- Health check coordination

### 4. Claude Code Integration Test (`claude_code_integration_test.rb`)
Tests Claude Code functionality in the Target environment:
- Container service functionality
- Workspace file access and management
- Application dependency management
- Rails command execution
- Database operations
- Code modification and validation
- Git operations
- Node.js/JavaScript operations
- Test execution capabilities
- Terminal session functionality
- Builder-Target communication
- Error handling and recovery

### 5. Container Security Test (`allspark_container_security_test.rb`)
Tests security aspects of the container setup:
- User permission validation
- Network isolation verification
- Host file system access restrictions
- Environment variable security
- Resource limit enforcement
- Secure inter-container communication
- File permission handling
- Privilege escalation prevention
- Security event logging
- Secrets and credentials management

## Running the Tests

### Prerequisites
- Docker and Docker Compose installed
- Allspark project set up
- Required gems installed (`bundle install`)

### Running All Tests
```bash
# Run all integration tests with automatic environment setup/teardown
rake integration:all
```

### Running Individual Test Suites
```bash
# Container communication tests
rake integration:communication

# API endpoint tests
rake integration:api

# Data flow and messaging tests
rake integration:messaging

# Claude Code integration tests
rake integration:claude

# Security tests
rake integration:security
```

### Manual Environment Management
```bash
# Setup dual-container environment for manual testing
rake integration:setup

# Check environment status
rake integration:status

# Teardown environment when finished
rake integration:teardown
```

### CI/CD Integration
```bash
# Run tests in CI mode (non-interactive)
rake integration:ci

# Generate test report
rake integration:report
```

## Test Environment

The integration tests automatically:
1. Stop any existing containers
2. Start the dual-container environment using `docker-compose.dual.yml`
3. Wait for all containers to become healthy
4. Run the specified tests
5. Clean up the environment

### Container Health Checks
Tests wait for the following containers to be healthy:
- `builder` (Allspark UI)
- `target` (Development environment)
- `builder-sidekiq` (Builder background jobs)
- `target-sidekiq` (Target background jobs)
- `db` (PostgreSQL database)
- `redis` (Redis cache/pubsub)

### Network Configuration
Tests verify:
- Builder accessible at `http://localhost:3001`
- Target accessible at `http://localhost:3000`
- Inter-container communication via Docker network
- Database accessible to both containers
- Redis accessible to both containers

## Writing New Integration Tests

### Test Structure
```ruby
require_relative 'allspark_integration_test_helper'

class MyIntegrationTest < AllsparkIntegrationTestHelper
  def setup
    skip("Dual-container environment not available") unless dual_container_environment_available?
  end

  test "my integration scenario" do
    # Test implementation
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
```

### Helper Methods Available
- `builder_url(path)` - Generate Builder URL
- `target_url(path)` - Generate Target URL
- `get_container(service)` - Get Docker container object
- `execute_in_container(service, command)` - Execute command in container
- `make_http_request(url, options)` - Make HTTP requests
- `verify_database_connectivity(container)` - Test database connection
- `verify_redis_connectivity(container)` - Test Redis connection
- `create_test_file_in_container(container, path, content)` - Create test files
- `read_file_from_container(container, path)` - Read files from containers
- `wait_for_file_in_container(container, path, timeout)` - Wait for file creation

## Troubleshooting

### Common Issues

1. **Port conflicts**: Make sure ports 3000 and 3001 are available
2. **Docker permissions**: Ensure your user can run Docker commands
3. **Resource limits**: Tests require sufficient memory and CPU
4. **Network issues**: Check Docker network configuration

### Debug Commands
```bash
# Check container status
docker ps -a

# View container logs
docker logs allspark-builder-1
docker logs allspark-target-1

# Check Docker Compose status
docker-compose -f docker-compose.dual.yml ps

# View test logs
tail -f log/test.log
```

### Performance Considerations
- Tests involve container startup/teardown, which can be slow
- Use `rake integration:setup` for manual testing to avoid repeated setup
- Consider running individual test suites during development
- CI runs may require increased timeouts

## Integration with Existing Tests

These integration tests complement the existing test suite:
- **Unit tests**: Test individual components in isolation
- **Browser tests**: Test UI functionality end-to-end
- **Integration tests**: Test container interactions and data flow
- **System tests**: Test complete user workflows

Run all tests together:
```bash
rake test  # Includes integration tests in test environment
```

## Continuous Integration

The integration tests are designed to work in CI environments:
- Automatic environment setup and teardown
- Non-interactive mode for CI runners
- JSON report generation for test analysis
- Proper exit codes for CI pipeline integration

Add to your CI pipeline:
```yaml
- name: Run Integration Tests
  run: bundle exec rake integration:ci
```