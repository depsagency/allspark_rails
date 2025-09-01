# Security Policy

## Supported Versions

We release patches for security vulnerabilities. Which versions are eligible for receiving such patches depends on the CVSS v3.0 Rating:

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

Please report (suspected) security vulnerabilities to **security@example.com**. You will receive a response from us within 48 hours. If the issue is confirmed, we will release a patch as soon as possible depending on complexity but historically within a few days.

Please do **NOT** create a public GitHub issue for security vulnerabilities.

### What to Include

Please include the following in your report:

1. Type of issue (e.g., buffer overflow, SQL injection, cross-site scripting, etc.)
2. Full paths of source file(s) related to the manifestation of the issue
3. The location of the affected source code (tag/branch/commit or direct URL)
4. Any special configuration required to reproduce the issue
5. Step-by-step instructions to reproduce the issue
6. Proof-of-concept or exploit code (if possible)
7. Impact of the issue, including how an attacker might exploit it

## Security Best Practices

When using this template, please follow these security best practices:

### Environment Variables
- Never commit `.env` files to version control
- Use strong, unique values for all secrets
- Rotate credentials regularly
- Use different credentials for each environment

### Authentication
- Enforce strong password policies
- Consider implementing 2FA
- Regular security audits of user permissions
- Monitor for suspicious authentication attempts

### Dependencies
- Keep all dependencies up to date
- Run `bundle audit` regularly
- Review dependency changes carefully
- Use Dependabot or similar tools

### Database
- Use parameterized queries (Rails does this by default)
- Encrypt sensitive data at rest
- Regular database backups
- Principle of least privilege for database users

### API Security
- Use HTTPS in production
- Implement rate limiting
- Validate all input data
- Use authentication tokens with expiration

### Monitoring
- Log security events
- Set up alerts for suspicious activity
- Regular security scans
- Penetration testing for production apps

## Security Tools

This template includes several security tools:

### Brakeman
Static analysis security scanner for Ruby on Rails:
```bash
bundle exec brakeman
```

### Bundle Audit
Checks for vulnerable gem versions:
```bash
bundle audit check
```

### RuboCop Security
Security-focused cops for RuboCop:
```bash
rubocop --only Security
```

## Common Vulnerabilities to Check

1. **SQL Injection**
   - Always use parameterized queries
   - Avoid raw SQL when possible

2. **Cross-Site Scripting (XSS)**
   - Sanitize user input
   - Use Rails' built-in protection

3. **Cross-Site Request Forgery (CSRF)**
   - Enable CSRF protection (default in Rails)
   - Use authenticity tokens

4. **Session Management**
   - Secure session cookies
   - Session timeout implementation
   - Secure session storage

5. **File Upload Security**
   - Validate file types
   - Scan for malware
   - Store outside web root

## Responsible Disclosure

We believe in responsible disclosure. If you discover a security vulnerability:

1. Give us reasonable time to fix the issue before public disclosure
2. Make a good faith effort to avoid privacy violations
3. Avoid destruction of data
4. Do not modify or access data beyond what is necessary

## Security Updates

Security updates will be released as:
- Patch versions for non-breaking fixes
- Minor versions if breaking changes are required
- Security advisories on GitHub

Subscribe to our security mailing list for updates: security-announce@example.com

## Acknowledgments

We appreciate the security research community and will acknowledge researchers who responsibly disclose vulnerabilities.

Thank you for helping keep AllSpark and its users safe!