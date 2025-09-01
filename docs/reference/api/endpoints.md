# API Endpoints

This document lists all available API endpoints in the AllSpark platform.

## Authentication Endpoints

### POST /auth/login
Authenticate a user and receive an access token.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "role": "user"
  }
}
```

### POST /auth/logout
Invalidate the current access token.

### POST /auth/refresh
Refresh an expired access token.

## User Management

### GET /users
List all users (admin only).

### GET /users/:id
Get a specific user's details.

### PUT /users/:id
Update user information.

### DELETE /users/:id
Delete a user account (admin only).

## Project Management

### GET /projects
List all projects for the authenticated user.

### POST /projects
Create a new project.

### GET /projects/:id
Get project details.

### PUT /projects/:id
Update project information.

### DELETE /projects/:id
Delete a project.

## AI Services

### POST /ai/generate
Generate content using AI.

**Request:**
```json
{
  "prompt": "Generate a PRD for a task management app",
  "type": "prd",
  "max_tokens": 2000
}
```

### POST /ai/analyze
Analyze text or code.

### GET /ai/models
List available AI models.

## Webhooks

### POST /webhooks
Create a new webhook subscription.

### GET /webhooks
List all webhook subscriptions.

### DELETE /webhooks/:id
Delete a webhook subscription.

## Rate Limiting

All API endpoints are rate limited:
- **Authentication endpoints**: 10 requests per minute
- **Read endpoints**: 100 requests per minute
- **Write endpoints**: 50 requests per minute
- **AI endpoints**: 20 requests per minute

## Error Responses

All errors follow a consistent format:
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Email is required",
    "details": {
      "field": "email"
    }
  }
}
```

Common error codes:
- `AUTHENTICATION_ERROR` - Invalid or missing authentication
- `AUTHORIZATION_ERROR` - Insufficient permissions
- `VALIDATION_ERROR` - Invalid request data
- `NOT_FOUND` - Resource not found
- `RATE_LIMIT_EXCEEDED` - Too many requests
- `SERVER_ERROR` - Internal server error