#!/bin/bash
set -euo pipefail

# Redis Memory Central Installation Script
# For Proxmox LXC deployment

echo "🚀 Redis Memory Central - Installation Script"
echo "==========================================="

# Check if running on Proxmox
if [ ! -f /etc/pve/version ]; then
    echo "❌ This script must be run on a Proxmox host"
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