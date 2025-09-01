# Kamal Deployment Guide

This guide will help you deploy your AllSpark application to a production server using Kamal 2.0.

## Prerequisites

- A server with Ubuntu 22.04 or similar (minimum 2GB RAM)
- Docker Hub account for storing container images
- Domain name (optional but recommended)
- SSH access to your server as root

## Quick Start

### 1. Initial Setup

Run the interactive setup to configure your deployment:

```bash
rake kamal:setup INTERACTIVE=true
```

This will:
- Create `config/deploy.yml` with your server details
- Create `.kamal/secrets` with secure passwords
- Guide you through the configuration process

### 2. Configure Secrets

Edit `.kamal/secrets` to add your credentials:

```bash
# Docker Registry
KAMAL_REGISTRY_PASSWORD=your_docker_hub_token

# Rails Secrets
RAILS_MASTER_KEY=your_rails_master_key_from_config/master.key
SECRET_KEY_BASE=your_secret_key_base

# Database (generated password from setup)
POSTGRES_PASSWORD=keep_the_generated_password

# LLM Configuration (choose one)
# Option 1: OpenRouter (recommended)
LLM_PROVIDER=openrouter
OPENROUTER_API_KEY=your_openrouter_api_key

# Option 2: Individual providers
OPENAI_API_KEY=your_openai_key
CLAUDE_API_KEY=your_claude_key
GEMINI_API_KEY=your_gemini_key
```

### 3. Prepare Your Server

Install Docker on your server:

```bash
ssh root@your-server-ip
curl -fsSL https://get.docker.com | sh
```

### 4. Deploy

```bash
# First deployment
kamal setup

# Subsequent deployments
kamal deploy
```

## Manual Configuration

If you prefer to configure manually:

### 1. Copy Example Files

```bash
cp .kamal/secrets.example .kamal/secrets
cp config/deploy.yml.example config/deploy.yml
```

### 2. Edit config/deploy.yml

Replace placeholders with your values:
- `YOUR_APP_NAME`: Your application name (lowercase, no spaces)
- `YOUR_SERVER_IP_HERE`: Your server's IP address
- `YOUR_DOMAIN_HERE`: Your domain name
- `YOUR_DOCKER_USERNAME`: Your Docker Hub username

### 3. Edit .kamal/secrets

Add your actual credentials (see Configure Secrets section above).

## Environment Variables

### Required Variables

| Variable | Description |
|----------|-------------|
| `KAMAL_REGISTRY_PASSWORD` | Docker Hub access token |
| `RAILS_MASTER_KEY` | Rails encryption key from config/master.key |
| `POSTGRES_PASSWORD` | PostgreSQL password |
| `LLM_PROVIDER` | AI provider: openrouter, openai, claude, or gemini |
| `*_API_KEY` | API key for your chosen LLM provider |

### Optional Variables

| Variable | Description |
|----------|-------------|
| `SMTP_*` | Email configuration |
| `STRIPE_*` | Payment processing |
| `AWS_*` | File storage on S3 |
| `SENTRY_DSN` | Error tracking |

## Common Commands

```bash
# Check deployment status
kamal app details

# View logs
kamal app logs

# Rails console
kamal app exec -i --reuse "bin/rails console"

# Run migrations
kamal app exec "bin/rails db:migrate"

# Restart application
kamal app restart

# Stop all services
kamal app stop

# Remove deployment
kamal app remove
```

## SSL/HTTPS Setup

Kamal automatically configures Let's Encrypt SSL certificates when you:
1. Set a domain in `config/deploy.yml`
2. Ensure DNS points to your server
3. Deploy with `kamal deploy`

## Troubleshooting

### Connection Issues
```bash
# Test SSH connection
ssh root@your-server-ip

# Check Docker is running
ssh root@your-server-ip 'docker ps'
```

### Database Issues
```bash
# Access database console
kamal app exec -i --reuse "bin/rails dbconsole"

# Reset database (WARNING: destroys data)
kamal app exec "bin/rails db:reset"
```

### View Container Logs
```bash
# Application logs
kamal app logs -f

# Database logs
kamal accessory logs db -f

# Redis logs
kamal accessory logs redis -f
```

### Validate Configuration
```bash
# Check for configuration issues
rake kamal:validate

# Show deployment checklist
rake kamal:checklist
```

## Security Best Practices

1. **Never commit secrets**: The `.kamal/secrets` file should never be in version control
2. **Use strong passwords**: The setup script generates secure passwords automatically
3. **Limit server access**: Use SSH keys and disable password authentication
4. **Keep Docker updated**: Regularly update Docker on your server
5. **Monitor logs**: Check application logs regularly for suspicious activity

## Advanced Configuration

### Multiple Servers

To deploy across multiple servers, update `config/deploy.yml`:

```yaml
servers:
  web:
    hosts:
      - 192.168.1.1
      - 192.168.1.2
    labels:
      traefik.http.routers.app.rule: Host(`app.example.com`)
  worker:
    hosts:
      - 192.168.1.3
    cmd: bundle exec sidekiq
```

### Custom Health Checks

Add health check configuration:

```yaml
healthcheck:
  path: /up
  port: 3000
  interval: 30s
```

### Resource Limits

Set container resource limits:

```yaml
servers:
  web:
    options:
      cpus: "2"
      memory: "2g"
```

## Support

- [Kamal Documentation](https://kamal-deploy.org)
- [AllSpark Issues](https://github.com/yourusername/allspark/issues)
- [Rails Deployment Guide](https://guides.rubyonrails.org/configuring.html#deploying-to-production)