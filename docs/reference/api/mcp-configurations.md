# MCP Configurations API

This document describes the REST API endpoints for managing MCP (Model Context Protocol) configurations.

## Authentication

All API endpoints require authentication via API key:

```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
  https://allspark.app/api/v1/mcp_configurations
```

## Endpoints

### List Configurations

Get all MCP configurations for the authenticated user.

```http
GET /api/v1/mcp_configurations
```

#### Response

```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Linear Integration",
    "server_type": "stdio",
    "enabled": true,
    "server_config": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-linear"],
      "env": {
        "LINEAR_API_KEY": "[REDACTED]"
      }
    },
    "metadata": {
      "template_key": "linear"
    },
    "created_at": "2024-01-15T10:30:00Z",
    "updated_at": "2024-01-15T10:30:00Z"
  }
]
```

**Notes:**
- Sensitive values in `server_config` are redacted in responses
- Only returns configurations owned by the authenticated user

### Get Configuration

Get a specific MCP configuration by ID.

```http
GET /api/v1/mcp_configurations/:id
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| id | UUID | Configuration ID |

#### Response

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "GitHub Integration",
  "server_type": "http",
  "enabled": true,
  "server_config": {
    "endpoint": "https://api.github.com/mcp",
    "headers": {
      "Authorization": "[REDACTED]"
    }
  },
  "metadata": {
    "template_key": "github",
    "last_test": "2024-01-15T11:00:00Z"
  },
  "created_at": "2024-01-15T10:00:00Z",
  "updated_at": "2024-01-15T11:00:00Z"
}
```

#### Errors

- `404 Not Found` - Configuration not found or not owned by user

### Create Configuration

Create a new MCP configuration.

```http
POST /api/v1/mcp_configurations
```

#### Request Body

```json
{
  "mcp_configuration": {
    "name": "My API Integration",
    "server_type": "http",
    "server_config": {
      "endpoint": "https://api.example.com/mcp",
      "headers": {
        "Authorization": "Bearer your-token",
        "X-API-Version": "2.0"
      }
    },
    "enabled": true,
    "metadata": {
      "environment": "production"
    }
  }
}
```

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| name | string | Yes | Configuration name |
| server_type | string | Yes | One of: `stdio`, `http`, `sse`, `websocket` |
| server_config | object | Yes | Server-specific configuration |
| enabled | boolean | No | Default: `true` |
| metadata | object | No | Additional metadata |

#### Server Config by Type

**stdio:**
```json
{
  "command": "/path/to/command",
  "args": ["arg1", "arg2"],
  "env": {
    "KEY": "value"
  }
}
```

**http/sse:**
```json
{
  "endpoint": "https://api.example.com/mcp",  // "url" for sse
  "headers": {
    "Authorization": "Bearer token"
  }
}
```

**websocket:**
```json
{
  "endpoint": "wss://api.example.com/socket",
  "headers": {
    "Authorization": "Bearer token"
  }
}
```

#### Response

```json
{
  "id": "650e8400-e29b-41d4-a716-446655440001",
  "name": "My API Integration",
  "server_type": "http",
  "enabled": true,
  "server_config": {
    "endpoint": "https://api.example.com/mcp",
    "headers": {
      "Authorization": "[REDACTED]",
      "X-API-Version": "2.0"
    }
  },
  "metadata": {
    "environment": "production"
  },
  "created_at": "2024-01-15T12:00:00Z",
  "updated_at": "2024-01-15T12:00:00Z"
}
```

#### Errors

- `422 Unprocessable Entity` - Validation errors
  ```json
  {
    "errors": {
      "name": ["can't be blank"],
      "server_type": ["is not included in the list"]
    }
  }
  ```

### Create from Template

Create a configuration from a template.

```http
POST /api/v1/mcp_configurations/from_template
```

#### Request Body

```json
{
  "mcp_configuration": {
    "name": "My Linear Workspace",
    "template_key": "linear",
    "template_params": {
      "LINEAR_API_KEY": "lin_api_xxxxxxxxxxxx"
    }
  }
}
```

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| name | string | Yes | Configuration name |
| template_key | string | Yes | Template identifier |
| template_params | object | Yes | Template-specific parameters |

#### Available Templates

- `linear` - Requires: `LINEAR_API_KEY`
- `github` - Requires: `GITHUB_TOKEN`
- `slack` - Requires: `SLACK_BOT_TOKEN`, `SLACK_APP_TOKEN`
- `filesystem` - Requires: `ALLOWED_DIRECTORIES`
- `docker` - No required parameters
- `postgres` - Requires: `DATABASE_URL`
- `redis` - Requires: `REDIS_URL`
- `custom_http` - Requires: `ENDPOINT`, `API_KEY`

### Update Configuration

Update an existing MCP configuration.

```http
PATCH /api/v1/mcp_configurations/:id
PUT /api/v1/mcp_configurations/:id
```

#### Request Body

```json
{
  "mcp_configuration": {
    "name": "Updated Name",
    "enabled": false,
    "server_config": {
      "headers": {
        "Authorization": "Bearer new-token"
      }
    }
  }
}
```

**Notes:**
- Only provided fields are updated
- `server_type` cannot be changed after creation
- Server config is merged with existing config

### Delete Configuration

Delete an MCP configuration.

```http
DELETE /api/v1/mcp_configurations/:id
```

#### Response

```http
204 No Content
```

### Toggle Configuration

Enable or disable a configuration.

```http
PATCH /api/v1/mcp_configurations/:id/toggle
```

#### Response

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "enabled": false,
  "toggled_at": "2024-01-15T13:00:00Z"
}
```

### Test Configuration

Test a configuration (existing or new).

```http
POST /api/v1/mcp_configurations/test
```

#### Request Body

For existing configuration:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000"
}
```

For new configuration:
```json
{
  "mcp_configuration": {
    "name": "Test Config",
    "server_type": "http",
    "server_config": {
      "endpoint": "https://api.example.com/mcp"
    }
  }
}
```

#### Response

Success:
```json
{
  "success": true,
  "message": "Connection successful",
  "response_time": 150,
  "details": {
    "server_type": "http",
    "endpoint": "https://api.example.com/mcp"
  }
}
```

Failure:
```json
{
  "success": false,
  "message": "Connection failed: timeout",
  "error": "Net::ReadTimeout",
  "details": {
    "server_type": "http",
    "endpoint": "https://api.example.com/mcp"
  }
}
```

### Get Session Configuration

Get aggregated MCP configuration for a Claude Code session.

```http
GET /api/v1/mcp_configurations/for_session
```

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| session_id | string | Yes | Claude Code session ID |
| instance_id | UUID | No | Instance ID (for multi-tenant) |

#### Response

```json
{
  "servers": [
    {
      "name": "linear",
      "transport": {
        "type": "stdio",
        "command": "npx",
        "args": ["@modelcontextprotocol/server-linear"],
        "env": {
          "LINEAR_API_KEY": "lin_api_xxxxxxxxxxxx"
        }
      }
    },
    {
      "name": "github",
      "transport": {
        "type": "http",
        "endpoint": "https://api.github.com/mcp",
        "headers": {
          "Authorization": "Bearer ghp_xxxxxxxxxxxx"
        }
      }
    }
  ]
}
```

**Notes:**
- Returns full configuration with unredacted credentials
- Includes user and instance configurations
- Only enabled configurations are included
- Instance configs take precedence over user configs for same name

## Batch Operations

### Bulk Create

Create multiple configurations at once.

```http
POST /api/v1/mcp_configurations/bulk_create
```

#### Request Body

```json
{
  "configurations": [
    {
      "name": "Config 1",
      "server_type": "http",
      "server_config": { ... }
    },
    {
      "name": "Config 2",
      "server_type": "stdio",
      "server_config": { ... }
    }
  ]
}
```

#### Response

```json
{
  "created": 2,
  "errors": [],
  "configurations": [ ... ]
}
```

### Bulk Delete

Delete multiple configurations.

```http
DELETE /api/v1/mcp_configurations/bulk_delete
```

#### Request Body

```json
{
  "ids": [
    "550e8400-e29b-41d4-a716-446655440000",
    "550e8400-e29b-41d4-a716-446655440001"
  ]
}
```

## Error Responses

All errors follow a consistent format:

```json
{
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": {
    "field": "Additional context"
  }
}
```

Common error codes:
- `VALIDATION_ERROR` - Invalid input data
- `NOT_FOUND` - Resource not found
- `UNAUTHORIZED` - Invalid or missing API key
- `FORBIDDEN` - Access denied
- `SERVER_ERROR` - Internal server error

## Rate Limiting

API requests are rate limited:
- 1000 requests per hour per API key
- 100 requests per minute per API key

Rate limit headers:
```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1642252800
```

## Webhooks

Configure webhooks to receive events:

### Events

- `mcp_configuration.created`
- `mcp_configuration.updated`
- `mcp_configuration.deleted`
- `mcp_configuration.test_completed`

### Webhook Payload

```json
{
  "event": "mcp_configuration.created",
  "timestamp": "2024-01-15T12:00:00Z",
  "data": {
    "configuration": { ... }
  }
}
```

## Code Examples

### Ruby

```ruby
require 'httparty'

class McpConfigurationClient
  include HTTParty
  base_uri 'https://allspark.app/api/v1'
  
  def initialize(api_key)
    @options = {
      headers: {
        'Authorization' => "Bearer #{api_key}",
        'Content-Type' => 'application/json'
      }
    }
  end
  
  def list_configurations
    self.class.get('/mcp_configurations', @options)
  end
  
  def create_configuration(name:, server_type:, server_config:)
    body = {
      mcp_configuration: {
        name: name,
        server_type: server_type,
        server_config: server_config
      }
    }
    
    self.class.post('/mcp_configurations', 
      @options.merge(body: body.to_json))
  end
end

client = McpConfigurationClient.new('your-api-key')
configs = client.list_configurations
```

### Python

```python
import requests

class McpConfigurationClient:
    def __init__(self, api_key):
        self.base_url = 'https://allspark.app/api/v1'
        self.headers = {
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json'
        }
    
    def list_configurations(self):
        response = requests.get(
            f'{self.base_url}/mcp_configurations',
            headers=self.headers
        )
        return response.json()
    
    def create_configuration(self, name, server_type, server_config):
        data = {
            'mcp_configuration': {
                'name': name,
                'server_type': server_type,
                'server_config': server_config
            }
        }
        
        response = requests.post(
            f'{self.base_url}/mcp_configurations',
            headers=self.headers,
            json=data
        )
        return response.json()

client = McpConfigurationClient('your-api-key')
configs = client.list_configurations()
```

### JavaScript/Node.js

```javascript
const axios = require('axios');

class McpConfigurationClient {
  constructor(apiKey) {
    this.client = axios.create({
      baseURL: 'https://allspark.app/api/v1',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      }
    });
  }
  
  async listConfigurations() {
    const response = await this.client.get('/mcp_configurations');
    return response.data;
  }
  
  async createConfiguration(name, serverType, serverConfig) {
    const response = await this.client.post('/mcp_configurations', {
      mcp_configuration: {
        name,
        server_type: serverType,
        server_config: serverConfig
      }
    });
    return response.data;
  }
}

const client = new McpConfigurationClient('your-api-key');
const configs = await client.listConfigurations();
```