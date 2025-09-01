# AllSpark Testing Strategy

## Overview

AllSpark uses a comprehensive testing strategy built on Rails' default testing framework with Minitest. The test suite covers models, services, controllers, channels, and mailers to ensure reliability and maintainability of the AI assistant platform.

## Testing Philosophy

- **Unit Tests**: Focus on individual model behavior, validations, and business logic
- **Service Tests**: Validate complex business operations and integrations
- **Integration Tests**: Ensure proper interaction between components
- **Real-world Scenarios**: Tests simulate actual user workflows and edge cases

## Test Configuration

- **Framework**: Minitest with Rails test helpers
- **Database**: PostgreSQL with UUID primary keys (test database)
- **Fixtures**: Disabled in favor of direct model creation for better reliability
- **Parallelization**: Tests run in parallel for faster execution
- **Mocking**: Uses Minitest::Mock for external service dependencies

---

## Model Tests

### Assistant Tests (`test/models/assistant_test.rb`)
**Purpose**: Validates the core AI assistant model functionality including validations, associations, and tool management.

- **test_valid_assistant**: Ensures a properly configured assistant passes all validations.
- **test_requires_name**: Verifies that assistants must have a name to be valid.
- **test_requires_valid_tool_choice**: Confirms only valid tool choice options ('auto', 'none', 'required') are accepted.
- **test_tool_choice_accepts_valid_values**: Tests that all valid tool choice values are properly accepted.
- **test_has_many_assistant_messages**: Validates the association between assistants and their conversation messages.
- **test_has_many_agent_runs**: Ensures assistants can be associated with multiple execution runs.
- **test_has_many_knowledge_documents**: Confirms assistants can have multiple knowledge documents attached.
- **test_belongs_to_user_optionally**: Tests that assistants can optionally be owned by a user.
- **test_active_scope_returns_active_assistants**: Verifies the active scope only returns assistants marked as active.
- **test_configured_tools_returns_tool_instances**: Ensures tool configurations are properly instantiated as tool objects.
- **test_configured_tools_handles_unknown_tool_types**: Validates graceful handling of unrecognized tool types.
- **test_conversation_for_run_returns_messages_for_specific_run**: Tests filtering messages by specific execution run ID.
- **test_clear_history_removes_all_messages**: Confirms the clear_history! method removes all assistant messages.

### MCP Configuration Tests (`test/models/mcp_configuration_test.rb`)
**Purpose**: Tests the Model Context Protocol (MCP) configuration system for connecting external tools and services.

- **test_should_validate_presence_of_required_fields**: Ensures required fields (owner, name, server_type, server_config) are validated.
- **test_should_validate_server_type_inclusion**: Confirms only valid server types are accepted.
- **test_should_create_valid_configuration_for_user**: Tests successful creation of MCP configurations for users.
- **test_should_support_polymorphic_owner**: Validates that configurations can belong to different owner types.
- **test_should_handle_JSON_serialization_for_server_config**: Tests proper serialization/deserialization of server configuration JSON.
- **test_active_scope_should_return_only_enabled_configurations**: Verifies the active scope filters for enabled configurations only.
- **test_for_user_scope_should_return_user_configurations**: Tests filtering configurations by specific user ownership.
- **test_to_mcp_json_should_format_configuration_for_MCP**: Validates proper formatting for MCP protocol communication.
- **test_for_claude_code_should_include_all_fields**: Tests configuration formatting specifically for Claude Code integration.
- **test_for_assistant_should_return_minimal_config_for_HTTP**: Ensures HTTP configurations are properly formatted for assistants.
- **test_for_assistant_should_indicate_bridge_needed_for_stdio**: Tests detection of when a bridge is needed for stdio connections.
- **test_bridge_available_should_return_false_for_stdio**: Validates bridge availability detection for different server types.
- **test_should_handle_metadata_properly**: Confirms proper handling of metadata fields in configurations.

### MCP Template Tests (`test/models/mcp_template_test.rb`)
**Purpose**: Validates the template system for pre-configured MCP server setups and parameter substitution.

- **test_should_validate_key_uniqueness**: Ensures template keys are unique across all templates.
- **test_should_validate_presence_of_required_fields**: Validates that templates require key, name, and config_template fields.
- **test_TEMPLATES_constant_should_contain_all_built-in_templates**: Verifies all expected built-in templates are defined in the TEMPLATES constant.
- **test_instantiate_configuration_should_create_configuration_from_template**: Tests template instantiation with parameter substitution.
- **test_should_validate_required_fields_using_helper_methods**: Validates helper methods for checking missing and valid parameters.
- **test_instantiate_configuration_should_handle_nested_replacements**: Tests parameter substitution in nested configuration structures.
- **test_template_categories_should_be_valid**: Ensures template categories are valid values.
- **test_linear_template_should_be_properly_configured**: Validates the Linear project management template configuration.
- **test_github_template_should_be_properly_configured**: Tests the GitHub integration template setup.
- **test_create_from_template_should_work_with_TEMPLATES_constant**: Verifies template instantiation works with all built-in templates.

---

## Service Tests

### App Projects Importer Service Tests (`test/services/app_projects/importer_service_test.rb`)
**Purpose**: Tests the service responsible for importing generated app projects and their metadata.

- **test_should_list_available_projects**: Verifies the service can list all projects available for import.
- **test_should_preview_project_successfully**: Tests project preview functionality before actual import.
- **test_should_import_project_successfully**: Validates successful import of a complete project with metadata.
- **test_should_handle_missing_metadata_gracefully**: Ensures graceful handling when project metadata is missing.
- **test_should_validate_project_structure**: Tests validation of required project directory structure.
- **test_should_handle_overwrite_existing_project**: Verifies proper handling when importing over existing projects.

### Agents Health Check Tests (`test/services/agents/health_check_test.rb`)
**Purpose**: Validates the health checking system for AI agents and their dependencies.

- **test_should_check_basic_system_health**: Tests basic system health indicators (database, Redis, etc.).
- **test_should_validate_agent_connectivity**: Ensures agents can connect to required services.

### MCP SSE Connection Tests (`test/services/mcp_sse_connection_test.rb`)
**Purpose**: Tests Server-Sent Events (SSE) connections for MCP servers with real-time capabilities.

- **test_should_handle_connect_method**: Validates proper connection establishment to SSE endpoints.
- **test_should_build_SSE_request_with_correct_headers**: Tests HTTP request formatting with proper headers.
- **test_should_add_auth_headers_for_api_key_auth_type**: Ensures authentication headers are added for API key auth.
- **test_should_support_tools/list_method**: Tests listing available tools through SSE connection.
- **test_should_support_tools/call_method**: Validates tool execution through SSE connection.

---

## Integration Tests

### AllSpark Container Security Tests (`test/integration/allspark_container_security_test.rb`)
**Purpose**: Validates security measures and container isolation in the AllSpark deployment environment.

- **test_container_isolation**: Ensures proper isolation between different application containers.
- **test_network_security_policies**: Validates network access controls and security policies.

### Container Communication Tests (`test/integration/container_communication_test.rb`)
**Purpose**: Tests inter-container communication and service discovery mechanisms.

- **test_service_discovery**: Validates that services can discover and communicate with each other.
- **test_data_flow_between_containers**: Ensures data properly flows between application components.

### API Endpoint Integration Tests (`test/integration/api_endpoint_integration_test.rb`)
**Purpose**: Tests end-to-end API functionality and external integrations.

- **test_api_authentication**: Validates API authentication and authorization mechanisms.
- **test_external_service_integration**: Tests integration with external services and APIs.

---

## Browser/System Tests

### Browser Journey Tests (`test/browser/journeys/`)
**Purpose**: End-to-end testing of complete user workflows using browser automation.

- **User Registration Journey**: Tests complete user signup and onboarding process.
- **User Login Journey**: Validates authentication and session management workflows.
- **Create Project Journey**: Tests project creation from start to finish.
- **Feature Walkthrough Journey**: Comprehensive test of main application features.
- **Chat Test Journey**: Validates real-time chat functionality and WebSocket connections.
- **MCP Configuration Journeys**: Tests MCP server setup and configuration workflows.

### Browser Test Infrastructure (`test/browser/`)
**Purpose**: Provides infrastructure for browser-based testing with Selenium and Chrome.

- **Self-Healing Tests**: Automatically detect and report common issues (JavaScript errors, 404s, 500s).
- **Screenshot Capture**: Captures visual evidence of test failures for debugging.
- **Journey Framework**: Structured approach to testing multi-step user workflows.

---

## Channel Tests

### ApplicationCable Connection Tests (`test/channels/application_cable/connection_test.rb`)
**Purpose**: Tests WebSocket connection authentication and setup for real-time features.

- **test_connects_with_valid_session**: Validates WebSocket connections with proper authentication.
- **test_rejects_invalid_connections**: Ensures unauthorized connections are properly rejected.

---

## Test Support Infrastructure

### Test Helpers and Utilities
- **Custom Test Helper**: Provides common utilities and setup for all tests
- **Journey Test Framework**: Structured system for multi-step user workflow testing
- **Mock Services**: Simulated external services for reliable testing
- **Database Fixtures**: Test data setup (currently disabled in favor of direct creation)

### Test Coverage Areas
- **Model Validations**: All model constraints and business rules
- **Service Layer Logic**: Complex business operations and integrations  
- **API Endpoints**: RESTful API functionality and responses
- **Real-time Features**: WebSocket connections and live updates
- **Security**: Authentication, authorization, and data protection
- **Integration Points**: External service connections and MCP protocol

---

## Running Tests

### Core Test Suite
```bash
# Run all core tests
docker exec target-web-1 bin/rails test test/models test/controllers test/services test/channels test/mailers

# Run specific test file
docker exec target-web-1 bin/rails test test/models/assistant_test.rb

# Run with coverage
docker exec target-web-1 bin/rails test --verbose
```

### Browser Tests
```bash
# Run browser journey tests
docker exec target-web-1 rake browser:journey[user_login]

# Test specific page with diagnostics
docker exec target-web-1 rake browser:test_for_fix[/dashboard]
```

### Test Maintenance
- Tests use direct model creation instead of fixtures for reliability
- Parallel execution enabled for faster test runs
- Self-healing browser tests provide diagnostic information
- Regular cleanup of test data and temporary files

This comprehensive test suite ensures AllSpark maintains high quality and reliability across all its AI assistant platform features, from basic model validations to complex multi-service integrations.