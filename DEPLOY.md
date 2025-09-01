# 🚀 Deploy to DigitalOcean in 5 Minutes

This guide will help you deploy AllSpark to DigitalOcean with professional-grade infrastructure including zero-downtime deployments.

## Prerequisites

You'll need:
- **DigitalOcean account** ([Sign up for $200 free credit](https://www.digitalocean.com/))
- **Docker Hub account** ([Free at hub.docker.com](https://hub.docker.com))
- **Domain name** (optional - you can use the server IP initially)

## Step 1: Get Your Tokens

### DigitalOcean API Token
1. Go to [DigitalOcean API Tokens](https://cloud.digitalocean.com/account/api/tokens)
2. Click "Generate New Token"
3. Give it a name like "AllSpark Deploy"
4. Select "Write" scope
5. Copy the token (you won't see it again!)

### Docker Hub Access Token
1. Go to [Docker Hub Security Settings](https://hub.docker.com/settings/security)
2. Click "New Access Token"
3. Give it a name like "AllSpark"
4. Copy the token

## Step 2: Deploy!

Run the deployment script:

```bash
./deploy-to-digitalocean.sh
```

The script will ask for:
- Your domain name (e.g., `myapp.com`)
- DigitalOcean API token
- Docker Hub username
- Docker Hub access token

**That's it!** The script handles everything else.

## What You Get

- **Ubuntu 22.04 Droplet** (2 vCPU, 4GB RAM, 80GB SSD)
- **Kamal Deployment** - Zero-downtime deployments
- **PostgreSQL 16** with pgvector extension
- **Redis 7** for caching and ActionCable
- **SSL-Ready** - Just point your domain and enable
- **Automated Backups** - Database persistence
- **Swap File** - 2GB for stability

## After Deployment

### 1. Access Your App
```
http://YOUR_SERVER_IP:3000
```

### 2. Point Your Domain
Add an A record pointing to your server IP:
```
Type: A
Name: @ (or subdomain)
Value: YOUR_SERVER_IP
TTL: 3600
```

### 3. Enable SSL (After DNS Propagates)
```bash
kamal proxy reboot --ssl
```

### 4. Access Rails Console
```bash
kamal app exec -i 'bin/rails console'
```

### 5. View Logs
```bash
kamal app logs -f
```

### 6. Deploy Updates
After making changes to your code:
```bash
kamal deploy
```

## Quick Commands Reference

| Task | Command |
|------|---------|
| Deploy updates | `kamal deploy` |
| Rails console | `kamal app exec -i 'bin/rails console'` |
| View logs | `kamal app logs -f` |
| Database console | `kamal app exec -i 'bin/rails dbconsole'` |
| Run migrations | `kamal app exec 'bin/rails db:migrate'` |
| Rollback | `kamal rollback` |
| App status | `kamal app details` |
| Restart app | `kamal app restart` |
| SSH to server | `ssh root@YOUR_SERVER_IP` |

## Cost Breakdown

**Monthly costs:**
- Droplet (s-2vcpu-4gb): $24/month
- Backups (optional): $4.80/month
- **Total: ~$29/month**

**Scaling options:**
- Upgrade to 4 vCPU, 8GB RAM: $48/month
- Add managed database: $15/month
- Add load balancer: $12/month

## Troubleshooting

### Docker Hub Authentication Failed
Make sure you're using an access token, not your password.

### DigitalOcean Token Invalid
Ensure your token has "Write" permissions.

### Deployment Stuck
Check logs with:
```bash
kamal app logs --tail 100
```

### Can't Access Site
1. Check firewall: `sudo ufw status`
2. Check app status: `kamal app details`
3. Check container: `docker ps`

## Advanced Configuration

### Custom Droplet Size
Edit the rake task to change `--size s-2vcpu-4gb` to:
- `s-1vcpu-2gb` - $12/month (minimum)
- `s-4vcpu-8gb` - $48/month (recommended for production)
- `s-8vcpu-16gb` - $96/month (high traffic)

### Different Region
Change `--region nyc3` to:
- `sfo3` - San Francisco
- `lon1` - London
- `fra1` - Frankfurt
- `sgp1` - Singapore

### Multiple Servers
Edit `config/deploy.yml` after deployment:
```yaml
servers:
  web:
    - YOUR_SERVER_IP
    - SECOND_SERVER_IP
```

## Security Notes

- Firewall is automatically configured
- Only ports 22, 80, 443, and 3000 are open
- SSH key authentication only
- Secrets are stored in `.kamal/secrets` (git-ignored)
- Database has a strong generated password

## Need Help?

1. Check Kamal docs: https://kamal-deploy.org
2. DigitalOcean tutorials: https://www.digitalocean.com/community/tutorials
3. Create an issue: https://github.com/allspark/issues

---

**Pro tip:** After your first deployment, you can deploy updates in seconds with just `kamal deploy`. It's that easy! 🎉