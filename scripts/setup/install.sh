#!/bin/bash
set -euo pipefail

# Redis Memory Central Installation Script
# For Proxmox LXC deployment

echo "🚀 Redis Memory Central - Installation Script"
echo "==========================================="

# Function to check if running on Proxmox
check_proxmox() {
    local indicators=0
    local reasons=()
    
    # Check for /etc/pve/version (traditional check)
    if [ -f /etc/pve/version ]; then
        indicators=$((indicators + 1))
    else
        reasons+=("'/etc/pve/version' not found")
    fi
    
    # Check for essential pct command (most important since script uses it)
    local pct_available=false
    if command -v pct >/dev/null 2>&1; then
        pct_available=true
        indicators=$((indicators + 1))
    else
        reasons+=("'pct' command not available")
    fi
    
    # Check for Proxmox VE perl modules
    if [ -d /usr/share/perl5/PVE ]; then
        indicators=$((indicators + 1))
    else
        reasons+=("Proxmox VE perl modules not found")
    fi
    
    # Check for proxmox-ve package
    if dpkg -s proxmox-ve >/dev/null 2>&1; then
        indicators=$((indicators + 1))
    else
        reasons+=("'proxmox-ve' package not installed")
    fi
    
    # Need at least $MIN_INDICATORS indicators for confidence, but pct is mandatory
    if [ "$pct_available" = false ]; then
        echo "❌ This script requires the 'pct' command which is not available"
        echo "   This script is designed to run on a Proxmox VE host"
        echo "   Missing indicators:"
        for reason in "${reasons[@]}"; do
            echo "     - $reason"
        done
        return 1
    elif [ $indicators -ge 2 ]; then
        echo "✅ Proxmox VE environment detected"
        return 0
    else
        if [ $indicators -eq 1 ]; then
            echo "⚠️  Warning: Only $indicators Proxmox indicator found"
        else
            echo "⚠️  Warning: Only $indicators Proxmox indicators found"
        fi
        echo "   Missing indicators:"
        for reason in "${reasons[@]}"; do
            echo "     - $reason"
        done
        echo "   Continuing since 'pct' command is available..."
        return 0
    fi
}

# Check if running on Proxmox
if ! check_proxmox; then
    exit 1
fi

# Configuration
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LXC_ID="${LXC_ID:-850}"  # Default container ID
NODE="${PROXMOX_NODE:-$(hostname)}"

echo "📁 Repository: $REPO_DIR"
echo "🖥️  Node: $NODE"
echo "📦 LXC ID: $LXC_ID"

# Step 1: Create LXC using Terraform
echo -e "\n1️⃣ Creating LXC container with Terraform..."
cd "$REPO_DIR/infrastructure/terraform"

if [ ! -f terraform.tfvars ]; then
    echo "❌ Please create terraform.tfvars from terraform.tfvars.example"
    exit 1
fi

terraform init
terraform plan
terraform apply -auto-approve

# Get LXC IP
LXC_IP=$(terraform output -raw container_ip)
echo "✅ LXC created at IP: $LXC_IP"

# Step 2: Wait for container to be ready
echo -e "\n2️⃣ Waiting for container to be ready..."
for i in {1..30}; do
    if pct exec $LXC_ID -- echo "Container ready" 2>/dev/null; then
        break
    fi
    echo -n "."
    sleep 2
done
echo " Ready!"

# Step 3: Run Ansible playbook
echo -e "\n3️⃣ Configuring container with Ansible..."
cd "$REPO_DIR/infrastructure/ansible"

# Update inventory with actual IP
sed -i "s/ansible_host=.*/ansible_host=$LXC_IP/" inventory.ini

ansible-playbook -i inventory.ini playbook.yml

# Step 4: Deploy services
echo -e "\n4️⃣ Deploying Redis Memory services..."
pct push $LXC_ID "$REPO_DIR/deployment" /opt/redis-memory -r
pct exec $LXC_ID -- bash -c "cd /opt/redis-memory && docker-compose up -d"

# Step 5: Wait for services
echo -e "\n5️⃣ Waiting for services to start..."
sleep 30

# Step 6: Run health checks
echo -e "\n6️⃣ Running health checks..."
"$REPO_DIR/scripts/maintenance/health-check.sh" $LXC_IP

echo -e "\n✅ Installation complete!"
echo "📍 Redis Memory Central is available at:"
echo "   - API: http://$LXC_IP:8000"
echo "   - MCP: http://$LXC_IP:9000"
echo "   - Redis: redis://$LXC_IP:16379"
echo "   - RedisInsight: http://$LXC_IP:18001"
echo ""
echo "Next steps:"
echo "1. Configure your clients: ./scripts/client/configure-claude.sh"
echo "2. Test the connection: python3 ./scripts/client/test-connection.py"
echo "3. Migrate existing data: ./scripts/migration/migrate-memories.py"