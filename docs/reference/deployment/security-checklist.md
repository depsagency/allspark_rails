# Security Checklist for Allspark Production Deployment

This comprehensive security checklist covers all aspects of securing the Allspark web-based development environment in production.

## Overview

Security is implemented in layers:
1. **Infrastructure Security** - Server and network hardening
2. **Container Security** - Docker isolation and resource limits
3. **Application Security** - Rails security best practices
4. **Data Security** - Encryption and access control
5. **Operational Security** - Monitoring and incident response

## Pre-Deployment Security Checklist

### Infrastructure Preparation

- [ ] **Server Hardening**
  - [ ] Use latest Ubuntu LTS (22.04 or newer)
  - [ ] Enable automatic security updates
  - [ ] Configure UFW firewall rules
  - [ ] Disable root SSH access
  - [ ] Use SSH key authentication only
  - [ ] Configure fail2ban for brute force protection

- [ ] **Network Security**
  - [ ] Configure SSL/TLS certificates (Let's Encrypt)
  - [ ] Enable HTTPS-only access
  - [ ] Set up reverse proxy (Nginx) with security headers
  - [ ] Configure CORS policies appropriately
  - [ ] Implement rate limiting

### Docker Security

- [ ] **Container Isolation**
  - [ ] Enable user namespace remapping
  - [ ] Drop unnecessary Linux capabilities
  - [ ] Use read-only root filesystems where possible
  - [ ] Implement resource limits (CPU, memory)
  - [ ] Disable inter-container communication where not needed

- [ ] **Image Security**
  - [ ] Use official base images only
  - [ ] Scan images for vulnerabilities
  - [ ] Run as non-root user in containers
  - [ ] Remove unnecessary packages and tools
  - [ ] Use multi-stage builds to minimize attack surface

### Application Security

- [ ] **Authentication & Authorization**
  - [ ] Strong password requirements enforced
  - [ ] Session timeout configured (24 hours)
  - [ ] CSRF protection enabled
  - [ ] Secure cookie flags set
  - [ ] Role-based access control implemented

- [ ] **Data Protection**
  - [ ] Database connections use SSL
  - [ ] Sensitive data encrypted at rest
  - [ ] API keys and secrets in environment variables
  - [ ] No secrets in code or version control
  - [ ] Input validation on all forms

## Production Deployment Security

### 1. Server Security Configuration

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Enable automatic security updates
sudo dpkg-reconfigure -plow unattended-upgrades

# Configure firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp     # SSH
sudo ufw allow 80/tcp     # HTTP
sudo ufw allow 443/tcp    # HTTPS
sudo ufw allow 3001/tcp   # Builder (remove after Nginx setup)
sudo ufw allow 3000/tcp   # Target (remove after Nginx setup)
sudo ufw --force enable

# Install and configure fail2ban
sudo apt install fail2ban -y
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 2. SSH Hardening

```bash
# Edit /etc/ssh/sshd_config
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM no
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 2
AllowUsers deploy

# Restart SSH
sudo systemctl restart sshd
```

### 3. Docker Security Configuration

```bash
# Create daemon.json for Docker security options
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "icc": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "userland-proxy": false,
  "userns-remap": "default",
  "no-new-privileges": true
}
EOF

# Create subuid and subgid mappings
echo "dockremap:100000:65536" | sudo tee /etc/subuid
echo "dockremap:100000:65536" | sudo tee /etc/subgid

# Restart Docker
sudo systemctl restart docker
```

### 4. Container Security Policies

```yaml
# docker-compose.production.yml security additions
services:
  builder:
    security_opt:
      - no-new-privileges:true
      - apparmor:docker-default
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - DAC_OVERRIDE
      - SETGID
      - SETUID
    read_only: false  # Required for Rails
    tmpfs:
      - /tmp
      - /app/tmp
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M

  target:
    security_opt:
      - no-new-privileges:true
      - seccomp:unconfined  # Required for development
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - DAC_OVERRIDE
      - SETGID
      - SETUID
      - SYS_PTRACE  # For debugging
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 2G
```

### 5. Application Security Configuration

```ruby
# config/environments/production.rb
Rails.application.configure do
  # Force SSL
  config.force_ssl = true
  
  # Security headers
  config.middleware.use Rack::Protection
  
  # Session security
  config.session_store :cookie_store,
    key: '_allspark_session',
    secure: true,
    httponly: true,
    same_site: :strict
  
  # CSRF protection
  config.action_controller.forgery_protection_origin_check = true
  
  # Content Security Policy
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self, :https
    policy.style_src   :self, :https
    policy.connect_src :self, :https, :wss
  end
  
  # Secure headers
  config.action_dispatch.default_headers = {
    'X-Frame-Options' => 'SAMEORIGIN',
    'X-XSS-Protection' => '1; mode=block',
    'X-Content-Type-Options' => 'nosniff',
    'X-Download-Options' => 'noopen',
    'X-Permitted-Cross-Domain-Policies' => 'none',
    'Referrer-Policy' => 'strict-origin-when-cross-origin'
  }
end
```

### 6. Nginx Security Configuration

```nginx
# /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 15;
    types_hash_max_size 2048;
    server_tokens off;
    
    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self' https:; script-src 'self' 'unsafe-inline' 'unsafe-eval' https:; style-src 'self' 'unsafe-inline' https:;" always;
    
    # SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # Rate Limiting
    limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=api:10m rate=100r/s;
    limit_conn_zone $binary_remote_addr zone=addr:10m;
    
    # Gzip
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/javascript application/json;
    
    # Logging
    access_log /var/log/nginx/access.log combined buffer=512k flush=1m;
    error_log /var/log/nginx/error.log warn;
    
    # Include site configurations
    include /etc/nginx/sites-enabled/*;
}
```

### 7. Database Security

```sql
-- Create restricted database user
CREATE USER 'allspark_app'@'localhost' IDENTIFIED BY 'strong_password_here';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON allspark_production.* TO 'allspark_app'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON allspark_target_%.* TO 'allspark_app'@'localhost';
FLUSH PRIVILEGES;

-- Enable SSL for connections
ALTER USER 'allspark_app'@'localhost' REQUIRE SSL;
```

### 8. Environment Variable Security

```bash
# Generate secure keys
rails secret > SECRET_KEY_BASE.txt
openssl rand -hex 32 > DATABASE_PASSWORD.txt
openssl rand -hex 32 > REDIS_PASSWORD.txt

# Set restrictive permissions
chmod 600 .env.production
chown deploy:deploy .env.production

# Validate no secrets in code
git secrets --install
git secrets --register-aws
git secrets --scan
```

## Container-Specific Security

### Builder Container Security

- [ ] Docker socket mounted read-only when possible
- [ ] Restricted to creating/managing only target containers
- [ ] API rate limiting implemented
- [ ] Audit logging for all container operations
- [ ] Resource quotas per user enforced

### Target Container Security

- [ ] Network isolation between projects
- [ ] No access to Docker socket
- [ ] Limited system calls (seccomp profile)
- [ ] Automatic termination on idle
- [ ] Resource limits enforced
- [ ] Read-only root filesystem (except workspace)

## Monitoring and Compliance

### Security Monitoring

```bash
# Install monitoring tools
sudo apt install -y auditd aide rkhunter

# Configure auditd
sudo auditctl -w /etc/passwd -p wa -k passwd_changes
sudo auditctl -w /etc/shadow -p wa -k shadow_changes
sudo auditctl -w /var/log/sudo.log -p wa -k sudo_commands
sudo auditctl -w /var/run/docker.sock -p wa -k docker_socket

# Initialize AIDE
sudo aideinit
sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Configure log monitoring
sudo tee /etc/rsyslog.d/50-allspark.conf > /dev/null <<EOF
:programname, isequal, "allspark" /var/log/allspark/security.log
& stop
EOF
```

### Compliance Checklist

- [ ] **GDPR Compliance**
  - [ ] Data retention policies implemented
  - [ ] User data export functionality
  - [ ] Right to deletion implemented
  - [ ] Privacy policy updated

- [ ] **Security Scanning**
  - [ ] Weekly vulnerability scans scheduled
  - [ ] Dependency updates automated
  - [ ] Container image scanning enabled
  - [ ] Code security scanning (Brakeman)

- [ ] **Access Control**
  - [ ] Principle of least privilege enforced
  - [ ] Regular access reviews scheduled
  - [ ] MFA enabled for admin accounts
  - [ ] API key rotation policy

## Incident Response Plan

### Preparation

1. **Security Team Contacts**
   - Primary: [Contact Name] - [Phone/Email]
   - Secondary: [Contact Name] - [Phone/Email]
   - External: [Security Firm] - [Contact]

2. **Escalation Path**
   - Level 1: Development Team
   - Level 2: Security Team
   - Level 3: Executive Team

### Detection and Analysis

```bash
# Quick security check script
#!/bin/bash
# /opt/allspark/security-check.sh

echo "=== Security Status Check ==="
echo "1. Failed login attempts:"
grep "Failed password" /var/log/auth.log | tail -20

echo -e "\n2. Docker security events:"
docker events --since 1h --filter event=create --filter event=destroy

echo -e "\n3. Suspicious processes:"
ps aux | grep -E "(nc|netcat|bash -i|/bin/sh)" | grep -v grep

echo -e "\n4. Network connections:"
netstat -tulpn | grep -E "(ESTABLISHED|LISTEN)"

echo -e "\n5. Recent sudo commands:"
grep sudo /var/log/auth.log | tail -20
```

### Containment and Recovery

1. **Immediate Actions**
   - Isolate affected systems
   - Preserve evidence (logs, memory dumps)
   - Notify security team
   - Begin incident log

2. **Recovery Steps**
   - Restore from clean backups
   - Patch vulnerabilities
   - Reset all credentials
   - Verify system integrity

### Post-Incident

- [ ] Document lessons learned
- [ ] Update security procedures
- [ ] Conduct security training
- [ ] Review and test incident response

## Security Maintenance Schedule

### Daily Tasks
- Monitor security logs
- Check for failed login attempts
- Verify backup completion
- Review resource usage

### Weekly Tasks
- Run security scans
- Update threat intelligence
- Review user access
- Test monitoring alerts

### Monthly Tasks
- Patch system updates
- Rotate API keys
- Security metrics review
- Incident response drill

### Quarterly Tasks
- Full security audit
- Penetration testing
- Policy review and update
- Security training

## Security Tools and Resources

### Recommended Tools

1. **Scanning Tools**
   - Trivy - Container vulnerability scanning
   - OWASP ZAP - Web application security testing
   - Lynis - System security auditing

2. **Monitoring Tools**
   - Fail2ban - Intrusion prevention
   - OSSEC - Host intrusion detection
   - Grafana + Loki - Log aggregation

3. **Compliance Tools**
   - Docker Bench - Docker security compliance
   - CIS-CAT - CIS benchmark compliance
   - OpenSCAP - Security compliance

### Security Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [Rails Security Guide](https://guides.rubyonrails.org/security.html)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)

## Emergency Contacts

- **Security Incidents**: security@yourcompany.com
- **24/7 Support**: +1-XXX-XXX-XXXX
- **Law Enforcement**: Local FBI Cyber Division
- **Legal Team**: legal@yourcompany.com

Remember: Security is not a one-time task but an ongoing process. Regular reviews and updates of this checklist are essential for maintaining a secure environment.