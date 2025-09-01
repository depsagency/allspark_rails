# API Documentation

This directory contains API endpoint documentation for the Allspark platform.

## API Categories

### Authentication APIs
- User authentication endpoints
- Token management
- Session handling

### Resource APIs
- Projects API
- Users API
- Chat API
- AI/LLM integration APIs

### Webhook APIs
- Event notifications
- Integration callbacks

## API Conventions

All APIs follow RESTful conventions and return JSON responses.

### Authentication
Most endpoints require authentication via Bearer token in the Authorization header.

### Response Format
```json
{
  "data": {},
  "meta": {
    "status": "success",
    "timestamp": "2024-01-01T00:00:00Z"
  }
}
```

### Error Handling
Errors follow a consistent format with appropriate HTTP status codes.

## Getting Started

See individual API documentation files for endpoint details and examples.