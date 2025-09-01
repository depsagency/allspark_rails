#!/bin/bash

# Allspark Server Setup Automation Script
# This script automates the initial server setup for deploying Allspark applications
# Usage: ./server-setup.sh [OPTIONS]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SERVER_IP=""
SERVER_USER="root"
SSH_KEY=""
DOMAIN=""
EMAIL=""
SETUP_FIREWALL=true
SETUP_MONITORING=true
SETUP_BACKUPS=true
VERBOSE=false
DRY_RUN=false

# Function to print colored output
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 -s SERVER_IP [OPTIONS]

Automate server setup for Allspark deployment

Required Arguments:
  -s, --server IP         Server IP address or hostname

Optional Arguments:
  -u, --user USER         SSH user (default: root)
  -k, --key PATH          Path to SSH private key
  -d, --domain DOMAIN     Domain name for SSL certificates
  -e, --email EMAIL       Email for Let's Encrypt certificates
  --no-firewall           Skip firewall configuration
  --no-monitoring         Skip monitoring setup
  --no-backups            Skip backup configuration
  -v, --verbose           Enable verbose output
  --dry-run               Show what would be done without executing
  -h, --help              Show this help message

Examples:
  $0 -s 192.168.1.100 -d example.com -e admin@example.com
  $0 -s myserver.com -u ubuntu -k ~/.ssh/id_rsa
  $0 -s 10.0.0.10 --no-monitoring --dry-run

EOF
}

# Function to validate prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if SSH is available
    if ! command -v ssh &> /dev/null; then
        log_error "SSH client is not installed"
        return 1
    fi
    
    # Check if rsync is available
    if ! command -v rsync &> /dev/null; then
        log_error "rsync is not installed"
        return 1
    fi
    
    # Check server connectivity
    log_info "Testing SSH connectivity to $SERVER_IP..."
    ssh_opts="-o ConnectTimeout=10 -o BatchMode=yes"
    
    if [ -n "$SSH_KEY" ]; then
        ssh_opts="$ssh_opts -i $SSH_KEY"
    fi
    
    if ! ssh $ssh_opts "$SERVER_USER@$SERVER_IP" "echo 'SSH connection successful'" &>/dev/null; then
        log_error "Cannot connect to server $SERVER_IP as user $SERVER_USER"
        log_info "Please check your SSH key and server access"
        return 1
    fi
    
    log_success "Prerequisites check passed"
    return 0
}

# Function to execute commands on remote server
remote_exec() {
    local command="$1"
    local description="$2"
    
    if [ -n "$description" ]; then
        log_info "$description"
    fi
    
    log_debug "Executing: $command"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would execute: $command"
        return 0
    fi
    
    ssh_opts="-o ConnectTimeout=30"
    if [ -n "$SSH_KEY" ]; then
        ssh_opts="$ssh_opts -i $SSH_KEY"
    fi
    
    if ssh $ssh_opts "$SERVER_USER@$SERVER_IP" "$command"; then
        return 0
    else
        log_error "Failed to execute: $command"
        return 1
    fi
}

# Function to transfer file to remote server
remote_copy() {
    local local_file="$1"
    local remote_path="$2"
    local description="$3"
    
    if [ -n "$description" ]; then
        log_info "$description"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would copy $local_file to $remote_path"
        return 0
    fi
    
    rsync_opts="-avz"
    if [ -n "$SSH_KEY" ]; then
        rsync_opts="$rsync_opts -e 'ssh -i $SSH_KEY'"
    fi
    
    if rsync $rsync_opts "$local_file" "$SERVER_USER@$SERVER_IP:$remote_path"; then
        return 0
    else
        log_error "Failed to copy $local_file to $remote_path"
        return 1
    fi
}

# Function to update system packages
update_system() {
    log_info "Updating system packages..."
    
    remote_exec "apt-get update && apt-get upgrade -y" "Updating package lists and upgrading packages"
    remote_exec "apt-get install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates" "Installing essential packages"
}

# Function to install Docker
install_docker() {
    log_info "Installing Docker..."
    
    remote_exec "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -" "Adding Docker GPG key"
    remote_exec 'add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"' "Adding Docker repository"
    remote_exec "apt-get update" "Updating package lists"
    remote_exec "apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin" "Installing Docker"
    remote_exec "systemctl enable docker && systemctl start docker" "Enabling and starting Docker service"
    remote_exec "usermod -aG docker $SERVER_USER" "Adding user to docker group"
}

# Function to install Docker Compose
install_docker_compose() {
    log_info "Installing Docker Compose..."
    
    remote_exec 'curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose' "Downloading Docker Compose"
    remote_exec "chmod +x /usr/local/bin/docker-compose" "Making Docker Compose executable"
    remote_exec "ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose" "Creating symlink"
}

# Function to install Kamal
install_kamal() {
    log_info "Installing Kamal deployment tool..."
    
    remote_exec "apt-get install -y ruby ruby-dev build-essential" "Installing Ruby and build tools"
    remote_exec "gem install kamal" "Installing Kamal gem"
}

# Function to setup firewall
setup_firewall() {
    if [ "$SETUP_FIREWALL" != true ]; then
        return 0
    fi
    
    log_info "Configuring UFW firewall..."
    
    remote_exec "ufw --force reset" "Resetting firewall rules"
    remote_exec "ufw default deny incoming" "Setting default deny for incoming"
    remote_exec "ufw default allow outgoing" "Setting default allow for outgoing"
    remote_exec "ufw allow ssh" "Allowing SSH"
    remote_exec "ufw allow 80/tcp" "Allowing HTTP"
    remote_exec "ufw allow 443/tcp" "Allowing HTTPS"
    remote_exec "ufw allow 2376/tcp" "Allowing Docker daemon (if needed)"
    remote_exec "ufw --force enable" "Enabling firewall"
}

# Function to setup SSL certificates
setup_ssl() {
    if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
        log_warning "Domain or email not provided, skipping SSL setup"
        return 0
    fi
    
    log_info "Setting up SSL certificates with Certbot..."
    
    remote_exec "snap install core; snap refresh core" "Installing snapd core"
    remote_exec "snap install --classic certbot" "Installing Certbot"
    remote_exec "ln -sf /snap/bin/certbot /usr/bin/certbot" "Creating Certbot symlink"
    
    # Setup nginx for certificate challenge
    remote_exec "apt-get install -y nginx" "Installing Nginx"
    remote_exec "systemctl enable nginx && systemctl start nginx" "Starting Nginx"
    
    # Get certificate
    remote_exec "certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --non-interactive" "Obtaining SSL certificate"
    
    # Setup auto-renewal
    remote_exec "systemctl enable certbot.timer" "Enabling certificate auto-renewal"
}

# Function to setup monitoring
setup_monitoring() {
    if [ "$SETUP_MONITORING" != true ]; then
        return 0
    fi
    
    log_info "Setting up basic monitoring..."
    
    # Install system monitoring tools
    remote_exec "apt-get install -y htop iotop nethogs ncdu fail2ban" "Installing monitoring tools"
    
    # Configure fail2ban
    cat << 'EOF' > /tmp/jail.local
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
EOF
    
    remote_copy "/tmp/jail.local" "/etc/fail2ban/jail.local" "Copying fail2ban configuration"
    remote_exec "systemctl enable fail2ban && systemctl start fail2ban" "Starting fail2ban"
    rm -f /tmp/jail.local
    
    # Setup log rotation
    cat << 'EOF' > /tmp/docker-logs
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    size 50M
    missingok
    delaycompress
    copytruncate
}
EOF
    
    remote_copy "/tmp/docker-logs" "/etc/logrotate.d/docker-logs" "Setting up Docker log rotation"
    rm -f /tmp/docker-logs
}

# Function to setup backup directories and scripts
setup_backups() {
    if [ "$SETUP_BACKUPS" != true ]; then
        return 0
    fi
    
    log_info "Setting up backup infrastructure..."
    
    # Create backup directories
    remote_exec "mkdir -p /opt/backups/databases /opt/backups/files /opt/backups/scripts" "Creating backup directories"
    
    # Create database backup script
    cat << 'EOF' > /tmp/backup-database.sh
#!/bin/bash
# Database backup script for Allspark deployments

BACKUP_DIR="/opt/backups/databases"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# Function to backup PostgreSQL database
backup_postgres() {
    local container_name="$1"
    local db_name="$2"
    local backup_file="$BACKUP_DIR/${db_name}_${DATE}.sql"
    
    echo "Backing up PostgreSQL database: $db_name"
    docker exec "$container_name" pg_dump -U postgres "$db_name" > "$backup_file"
    
    if [ $? -eq 0 ]; then
        gzip "$backup_file"
        echo "Database backup completed: ${backup_file}.gz"
    else
        echo "Database backup failed for: $db_name"
        return 1
    fi
}

# Function to cleanup old backups
cleanup_old_backups() {
    echo "Cleaning up backups older than $RETENTION_DAYS days"
    find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete
}

# Main backup logic
for container in $(docker ps --format "table {{.Names}}" | grep -E ".*_(db|postgres)_.*"); do
    if docker exec "$container" psql -U postgres -l &>/dev/null; then
        # Get database names
        databases=$(docker exec "$container" psql -U postgres -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('template0', 'template1', 'postgres');")
        
        for db in $databases; do
            db=$(echo $db | xargs)  # trim whitespace
            if [ -n "$db" ]; then
                backup_postgres "$container" "$db"
            fi
        done
    fi
done

cleanup_old_backups
echo "Backup process completed at $(date)"
EOF
    
    remote_copy "/tmp/backup-database.sh" "/opt/backups/scripts/backup-database.sh" "Installing database backup script"
    remote_exec "chmod +x /opt/backups/scripts/backup-database.sh" "Making backup script executable"
    rm -f /tmp/backup-database.sh
    
    # Setup cron job for daily backups
    remote_exec "(crontab -l 2>/dev/null; echo '0 2 * * * /opt/backups/scripts/backup-database.sh >> /var/log/backup.log 2>&1') | crontab -" "Setting up daily backup cron job"
}

# Function to optimize system settings
optimize_system() {
    log_info "Optimizing system settings..."
    
    # Increase file descriptor limits
    cat << 'EOF' > /tmp/limits.conf
* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536
EOF
    
    remote_copy "/tmp/limits.conf" "/etc/security/limits.d/99-allspark.conf" "Setting file descriptor limits"
    rm -f /tmp/limits.conf
    
    # Configure kernel parameters for better performance
    cat << 'EOF' > /tmp/sysctl.conf
# Network optimizations
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 12582912 16777216
net.ipv4.tcp_wmem = 4096 12582912 16777216
net.core.netdev_max_backlog = 5000

# File system optimizations
fs.file-max = 2097152
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
EOF
    
    remote_copy "/tmp/sysctl.conf" "/etc/sysctl.d/99-allspark.conf" "Configuring kernel parameters"
    remote_exec "sysctl -p /etc/sysctl.d/99-allspark.conf" "Applying kernel parameters"
    rm -f /tmp/sysctl.conf
}

# Function to create deployment user
create_deployment_user() {
    log_info "Creating deployment user..."
    
    remote_exec "useradd -m -s /bin/bash -G docker deploy" "Creating deploy user"
    remote_exec "mkdir -p /home/deploy/.ssh" "Creating SSH directory"
    remote_exec "chmod 700 /home/deploy/.ssh" "Setting SSH directory permissions"
    
    # Copy SSH keys if available
    if [ -n "$SSH_KEY" ] && [ -f "${SSH_KEY}.pub" ]; then
        remote_copy "${SSH_KEY}.pub" "/home/deploy/.ssh/authorized_keys" "Copying SSH public key"
        remote_exec "chown -R deploy:deploy /home/deploy/.ssh" "Setting SSH key ownership"
        remote_exec "chmod 600 /home/deploy/.ssh/authorized_keys" "Setting SSH key permissions"
    fi
    
    # Grant sudo access for deployments
    remote_exec "echo 'deploy ALL=(ALL) NOPASSWD: /usr/bin/docker, /usr/local/bin/docker-compose, /usr/bin/systemctl' > /etc/sudoers.d/deploy" "Granting deployment permissions"
}

# Function to verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    # Check Docker
    if ! remote_exec "docker --version" "Checking Docker version"; then
        log_error "Docker verification failed"
        return 1
    fi
    
    # Check Docker Compose
    if ! remote_exec "docker-compose --version" "Checking Docker Compose version"; then
        log_error "Docker Compose verification failed"
        return 1
    fi
    
    # Check Kamal
    if ! remote_exec "kamal version" "Checking Kamal version"; then
        log_error "Kamal verification failed"
        return 1
    fi
    
    # Check services
    remote_exec "systemctl is-active docker" "Checking Docker service"
    
    if [ "$SETUP_FIREWALL" = true ]; then
        remote_exec "ufw status" "Checking firewall status"
    fi
    
    if [ "$SETUP_MONITORING" = true ]; then
        remote_exec "systemctl is-active fail2ban" "Checking fail2ban service"
    fi
    
    log_success "Server setup verification completed"
    return 0
}

# Function to display final instructions
show_final_instructions() {
    log_success "Server setup completed successfully!"
    echo ""
    log_info "Server Details:"
    echo "  IP Address: $SERVER_IP"
    echo "  SSH User: $SERVER_USER"
    if [ -n "$DOMAIN" ]; then
        echo "  Domain: $DOMAIN"
    fi
    echo ""
    log_info "Next Steps:"
    echo "  1. Test Docker: ssh $SERVER_USER@$SERVER_IP 'docker run hello-world'"
    echo "  2. Configure your Kamal deploy.yml file"
    echo "  3. Set up your application environment variables"
    echo "  4. Run your first deployment"
    echo ""
    if [ "$SETUP_BACKUPS" = true ]; then
        log_info "Backup Information:"
        echo "  - Database backups: /opt/backups/databases/"
        echo "  - Backup scripts: /opt/backups/scripts/"
        echo "  - Daily backup cron job configured at 2:00 AM"
    fi
    echo ""
    log_info "Monitoring:"
    echo "  - Use 'htop' for system monitoring"
    echo "  - Check logs with 'journalctl -f'"
    if [ "$SETUP_MONITORING" = true ]; then
        echo "  - fail2ban status: 'fail2ban-client status'"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--server)
            SERVER_IP="$2"
            shift 2
            ;;
        -u|--user)
            SERVER_USER="$2"
            shift 2
            ;;
        -k|--key)
            SSH_KEY="$2"
            shift 2
            ;;
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -e|--email)
            EMAIL="$2"
            shift 2
            ;;
        --no-firewall)
            SETUP_FIREWALL=false
            shift
            ;;
        --no-monitoring)
            SETUP_MONITORING=false
            shift
            ;;
        --no-backups)
            SETUP_BACKUPS=false
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$SERVER_IP" ]; then
    log_error "Server IP is required"
    show_usage
    exit 1
fi

# Main execution
main() {
    log_info "Starting Allspark server setup for $SERVER_IP"
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "DRY RUN MODE - No changes will be made"
    fi
    
    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi
    
    # Execute setup steps
    update_system
    install_docker
    install_docker_compose
    install_kamal
    setup_firewall
    setup_ssl
    setup_monitoring
    setup_backups
    optimize_system
    create_deployment_user
    
    # Verify everything is working
    if ! verify_installation; then
        log_error "Setup verification failed"
        exit 1
    fi
    
    # Show final instructions
    show_final_instructions
}

# Run main function
main "$@"