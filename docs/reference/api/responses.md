# API Response Formats

This document describes the standard response formats used by the AllSpark API.

## Response Structure

All API responses follow a consistent JSON structure.

### Successful Responses

#### Single Resource
```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "type": "project",
    "attributes": {
      "name": "My Project",
      "description": "Project description",
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T10:30:00Z"
    },
    "relationships": {
      "owner": {
        "data": {
          "id": "123e4567-e89b-12d3-a456-426614174000",
          "type": "user"
        }
      }
    }
  }
}
```

#### Collection Response
```json
{
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "type": "project",
      "attributes": {
        "name": "Project 1"
      }
    },
    {
      "id": "550e8400-e29b-41d4-a716-446655440001",
      "type": "project",
      "attributes": {
        "name": "Project 2"
      }
    }
  ],
  "meta": {
    "total": 25,
    "page": 1,
    "per_page": 10,
    "total_pages": 3
  },
  "links": {
    "first": "/api/v1/projects?page=1",
    "last": "/api/v1/projects?page=3",
    "next": "/api/v1/projects?page=2",
    "prev": null
  }
}
```

### Error Responses

All errors follow this structure:
```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {
      // Additional error details
    }
  }
}
```

## HTTP Status Codes

### Success Codes
- `200 OK` - Request succeeded
- `201 Created` - Resource created successfully
- `204 No Content` - Request succeeded with no response body

### Client Error Codes
- `400 Bad Request` - Invalid request format
- `401 Unauthorized` - Authentication required
- `403 Forbidden` - Access denied
- `404 Not Found` - Resource not found
- `409 Conflict` - Resource conflict (e.g., duplicate)
- `422 Unprocessable Entity` - Validation errors
- `429 Too Many Requests` - Rate limit exceeded

### Server Error Codes
- `500 Internal Server Error` - Server error
- `502 Bad Gateway` - Service unavailable
- `503 Service Unavailable` - Temporary outage

## Common Error Codes

### Authentication Errors
```json
{
  "error": {
    "code": "INVALID_TOKEN",
    "message": "The provided authentication token is invalid",
    "details": {
      "token_type": "bearer",
      "expired": false
    }
  }
}
```

### Validation Errors
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": {
      "errors": [
        {
          "field": "email",
          "message": "Email is required"
        },
        {
          "field": "name",
          "message": "Name must be at least 3 characters"
        }
      ]
    }
  }
}
```

### Rate Limiting
```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded",
    "details": {
      "limit": 100,
      "remaining": 0,
      "reset_at": "2024-01-15T11:00:00Z"
    }
  }
}
```

## Pagination

List endpoints support pagination through query parameters:

- `page` - Page number (default: 1)
- `per_page` - Items per page (default: 25, max: 100)

Example:
```
GET /api/v1/projects?page=2&per_page=50
```

## Filtering and Sorting

### Filtering
Use the `filter` parameter:
```
GET /api/v1/projects?filter[status]=active&filter[owner_id]=123
```

### Sorting
Use the `sort` parameter:
```
GET /api/v1/projects?sort=created_at
GET /api/v1/projects?sort=-updated_at  # Descending order
```

## Partial Responses

Request specific fields using the `fields` parameter:
```
GET /api/v1/projects?fields[project]=name,description
```

## Includes

Include related resources using the `include` parameter:
```
GET /api/v1/projects?include=owner,tags
```

## Response Headers

Important response headers:

- `X-Request-ID` - Unique request identifier for debugging
- `X-Rate-Limit-Limit` - Rate limit maximum
- `X-Rate-Limit-Remaining` - Remaining requests
- `X-Rate-Limit-Reset` - Reset timestamp
- `ETag` - Resource version for caching
- `Last-Modified` - Last modification timestamp

## Webhooks Response Format

Webhook payloads follow the same structure as API responses:
```json
{
  "event": "project.created",
  "timestamp": "2024-01-15T10:30:00Z",
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "type": "project",
    "attributes": {
      // Resource attributes
    }
  }
}
```