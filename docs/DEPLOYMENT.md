# Redis Memory Central - Deployment Guide

This guide walks through deploying Redis Memory Central on your Proxmox infrastructure.

## Prerequisites

### Proxmox Host Requirements
- Proxmox VE 7.x or 8.x
- At least 8GB free RAM
- 100GB available storage
- Network access to 10.10.20.0/24 subnet

### Required Tools
- Terraform >= 1.0
- Ansible >= 2.9
- Git
- SSH access to Proxmox host

### API Keys
- OpenAI API key (for embeddings)
- Anthropic API key (optional, for Claude integration)

## Deployment Steps

### 1. Clone Repository

On your Proxmox host:

```bash
cd /opt
git clone https://github.com/eddygk/redis-memory-central.git
cd redis-memory-central
```

### 2. Configure Environment

Copy and edit the environment file:

```bash
cp .env.example .env
nano .env
```

Required settings:
```bash
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
PROXMOX_PASSWORD=your-proxmox-password
```

### 3. Configure Terraform

```bash
cd infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Example configuration:
```hcl
proxmox_api_url = "https://proxmox.local:8006/api2/json"
proxmox_user = "root@pam"
proxmox_password = "your-password"
proxmox_node = "pve"
lxc_template = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
storage_pool = "local-lvm"
```

### 4. Run Installation

Execute the automated installation:

```bash
cd /opt/redis-memory-central
./scripts/setup/install.sh
```

This will:
1. Create LXC container using Terraform
2. Configure container with Ansible
3. Deploy Docker services
4. Run health checks

Expected output:
```
🚀 Redis Memory Central - Installation Script
===========================================
📁 Repository: /opt/redis-memory-central
🖥️  Node: pve
📦 LXC ID: 850

1️⃣ Creating LXC container with Terraform...
✅ LXC created at IP: 10.10.20.85

2️⃣ Waiting for container to be ready...
Ready!

3️⃣ Configuring container with Ansible...
[Ansible output...]

4️⃣ Deploying Redis Memory services...
[Docker compose output...]

5️⃣ Waiting for services to start...

6️⃣ Running health checks...
✅ All checks passed!

✅ Installation complete!
```

### 5. Verify Deployment

Access the services:

- **API Documentation**: http://10.10.20.85:8000/docs
- **RedisInsight**: http://10.10.20.85:18001
- **Health Check**: http://10.10.20.85:8000/v1/health

Run comprehensive tests:

```bash
python3 scripts/client/test-connection.py
```

### 6. Configure Clients

For each client machine, run the appropriate configuration script:

**Linux/Mac:**
```bash
./scripts/client/configure-claude.sh
```

**Windows:**
```powershell
.\scripts\client\configure-claude.ps1
```

## Manual Deployment

If you prefer manual deployment:

### 1. Create LXC Container

```bash
# Create container
pct create 850 local:vztmpl/ubuntu-24.04-standard_24.04-1_amd64.tar.zst \
  --hostname redis-memory-central \
  --memory 8192 \
  --cores 4 \
  --net0 name=eth0,bridge=vmbr0,ip=10.10.20.85/24,gw=10.10.20.1,tag=20 \
  --storage local-lvm \
  --rootfs local-lvm:100 \
  --unprivileged 1 \
  --features nesting=1,fuse=1

# Enable Docker support
echo "lxc.apparmor.profile: unconfined" >> /etc/pve/lxc/850.conf
echo "lxc.cgroup2.devices.allow: a" >> /etc/pve/lxc/850.conf

# Start container
pct start 850
```

### 2. Install Dependencies

Enter the container:
```bash
pct enter 850
```

Install Docker:
```bash
curl -fsSL https://get.docker.com | sh
```

### 3. Deploy Services

```bash
cd /opt
git clone https://github.com/redis-developer/agent-memory-server.git redis-memory
cd redis-memory

# Create .env file with your API keys
cp deployment/.env.example deployment/.env
nano deployment/.env

# Start services
docker-compose -f deployment/docker-compose.yml up -d
```

## Post-Deployment

### 1. Enable Monitoring

If you have Prometheus:

```yaml
# Add to prometheus.yml
scrape_configs:
  - job_name: 'redis-memory'
    static_configs:
      - targets: ['10.10.20.85:9090']
```

### 2. Configure Backups

The backup script runs automatically at 2 AM. To run manually:

```bash
pct exec 850 -- /opt/redis-memory/backup.sh
```

### 3. Set Up Alerts

Example alert rules for Prometheus:

```yaml
groups:
  - name: redis_memory
    rules:
      - alert: RedisMemoryDown
        expr: up{job="redis-memory"} == 0
        for: 5m
        annotations:
          summary: "Redis Memory server is down"
      
      - alert: HighMemoryUsage
        expr: redis_memory_used_bytes / redis_memory_max_bytes > 0.9
        for: 10m
        annotations:
          summary: "Redis memory usage above 90%"
```

## Security Hardening

For production deployment:

### 1. Enable Authentication

Edit `/opt/redis-memory/.env`:
```bash
DISABLE_AUTH=false
OAUTH2_ISSUER_URL=https://your-auth-provider.com
OAUTH2_AUDIENCE=your-api-audience
```

### 2. Configure TLS

Add nginx reverse proxy with SSL:

```nginx
server {
    listen 443 ssl;
    server_name redis-memory.local;
    
    ssl_certificate /etc/ssl/certs/redis-memory.crt;
    ssl_certificate_key /etc/ssl/private/redis-memory.key;
    
    location / {
        proxy_pass http://10.10.20.85:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 3. Network Isolation

Create dedicated VLAN:

```bash
# On Proxmox host - Example for VLAN 100 (if different from default VLAN 20)
ip link add link vmbr0 name vmbr0.100 type vlan id 100
ip link set vmbr0.100 up
```

**Note**: The default configuration now uses VLAN 20. If you need a different VLAN, update the `vlan_tag` variable in your terraform.tfvars file.

## Troubleshooting

### Installation Script Fails

If the installation script fails with "'pct' command not available" or Proxmox detection errors:

1. **Check Proxmox Installation**: Verify that Proxmox VE is properly installed:
   ```bash
   # Check if pct command is available (required)
   which pct
   
   # Check Proxmox version
   pveversion
   
   # Check if this is a Proxmox node
   pvesh get /nodes
   ```

2. **Bare-metal Proxmox**: On some bare-metal installations, `/etc/pve/version` might not exist. The script will continue if the `pct` command is available.

3. **Run with verbose output**: Check what indicators are missing:
   ```bash
   bash -x ./scripts/setup/install.sh
   ```

The script checks for multiple Proxmox indicators:
- `/etc/pve/version` file
- `pct` command availability (mandatory)
- Proxmox VE perl modules
- `proxmox-ve` package

### Container Won't Start

Check LXC logs:
```bash
pct start 850 --debug
journalctl -u pve-container@850
```

### Services Not Accessible

Check firewall:
```bash
pct exec 850 -- ufw status
pct exec 850 -- docker ps
```

### Redis Connection Issues

Test Redis directly:
```bash
pct exec 850 -- redis-cli -p 16379 ping
```

### Performance Issues

Check resource usage:
```bash
pct exec 850 -- htop
pct exec 850 -- docker stats
```

## Maintenance

### Update Services

```bash
cd /opt/redis-memory-central
git pull
./scripts/maintenance/update-services.sh
```

### Clean Up Old Data

```bash
# Remove old backups
find /opt/redis-memory/backups -name "*.tar.gz" -mtime +30 -delete

# Compact Redis
docker exec redis-memory-redis redis-cli BGREWRITEAOF
```

### Monitor Logs

```bash
# API logs
docker logs -f redis-memory-api

# Task worker logs
docker logs -f redis-memory-task-worker

# All logs
docker-compose -f /opt/redis-memory/docker-compose.yml logs -f
```

## Scaling

### Vertical Scaling

Increase container resources:
```bash
pct set 850 -memory 16384 -cores 8
pct reboot 850
```

### Horizontal Scaling

For high availability, deploy multiple instances behind a load balancer:

1. Deploy additional containers (851, 852)
2. Configure Redis Sentinel
3. Add HAProxy load balancer
4. Update client configurations

See [SCALING.md](SCALING.md) for detailed instructions.

## Support

- Check logs: `/var/log/redis-memory/`
- Run health check: `./scripts/maintenance/health-check.sh`
- Test connection: `python3 ./scripts/client/test-connection.py`
- GitHub Issues: https://github.com/eddygk/redis-memory-central/issues