# API Authentication

This document describes the authentication methods available for the AllSpark API.

## Authentication Methods

### 1. API Token Authentication (Recommended)

The primary authentication method uses bearer tokens in the Authorization header.

#### Obtaining a Token

Tokens can be obtained through:
1. The web interface under Settings → API Tokens
2. The `/auth/login` endpoint

#### Using the Token

Include the token in all API requests:
```bash
curl -H "Authorization: Bearer YOUR_API_TOKEN" \
  https://api.allspark.dev/v1/projects
```

#### Token Expiration

- Access tokens expire after 24 hours
- Refresh tokens expire after 30 days
- Use the `/auth/refresh` endpoint to get a new access token

### 2. OAuth 2.0 (Coming Soon)

OAuth 2.0 support is planned for third-party integrations.

### 3. Session Authentication

For browser-based applications, session cookies can be used after login through the web interface.

## Security Best Practices

### Token Storage

- **Never** commit tokens to version control
- Store tokens in environment variables
- Use secure storage solutions for production

### Token Rotation

- Rotate API tokens regularly
- Implement automatic token refresh in your applications
- Revoke unused tokens immediately

### HTTPS Only

All API requests must use HTTPS. HTTP requests will be rejected.

## Rate Limiting

Authentication endpoints have specific rate limits:
- Login: 10 attempts per minute per IP
- Token refresh: 20 requests per minute per token
- Failed attempts count double against the limit

## Multi-Factor Authentication

When MFA is enabled for an account:
1. Initial login returns a challenge token
2. Submit the MFA code with the challenge token
3. Receive the access token upon successful verification

Example:
```json
// Step 1: Initial login
POST /auth/login
{
  "email": "user@example.com",
  "password": "password123"
}

// Response
{
  "challenge_token": "abc123...",
  "mfa_required": true
}

// Step 2: Submit MFA code
POST /auth/mfa/verify
{
  "challenge_token": "abc123...",
  "code": "123456"
}

// Response
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "user": {...}
}
```

## API Token Permissions

API tokens can be scoped to specific permissions:

- `read:projects` - Read project data
- `write:projects` - Create and update projects
- `delete:projects` - Delete projects
- `read:users` - Read user data
- `admin:all` - Full administrative access

## Troubleshooting

### Common Authentication Errors

1. **401 Unauthorized**
   - Token is missing or invalid
   - Token has expired
   - Token lacks required permissions

2. **403 Forbidden**
   - Valid token but insufficient permissions
   - Account is suspended or disabled

3. **429 Too Many Requests**
   - Rate limit exceeded
   - Wait for the time specified in `Retry-After` header

### Debug Headers

Include `X-Debug-Auth: true` to receive detailed authentication error messages (development only).