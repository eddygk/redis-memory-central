#!/bin/bash
set -euo pipefail

# Configure Claude Desktop for centralized Redis Memory Server

echo "🤖 Configuring Claude Desktop for Redis Memory Central"
echo "===================================================="

REDIS_MEMORY_IP="${REDIS_MEMORY_IP:-10.10.20.85}"
CONFIG_DIR=""

# Detect OS and set config directory
if [[ "$OSTYPE" == "darwin"* ]]; then
    CONFIG_DIR="$HOME/Library/Application Support/Claude"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    CONFIG_DIR="$APPDATA/Claude"
else
    CONFIG_DIR="$HOME/.config/Claude"
fi

CONFIG_FILE="$CONFIG_DIR/claude_desktop_config.json"

echo "📁 Config location: $CONFIG_FILE"
echo "🌐 Redis Memory Server: $REDIS_MEMORY_IP"

# Backup existing config
if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    echo "✅ Backed up existing configuration"
fi

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Read existing config or create new
if [ -f "$CONFIG_FILE" ]; then
    CONFIG=$(cat "$CONFIG_FILE")
else
    CONFIG='{}'
fi

# Update config with jq
UPDATED_CONFIG=$(echo "$CONFIG" | jq --arg ip "$REDIS_MEMORY_IP" '
  .["redis-memory-server"] = {
    "command": "docker",
    "args": [
      "run", "--rm", "-i",
      "--network", "host",
      "-e", ("REDIS_URL=redis://" + $ip + ":16379"),
      "-e", ("API_URL=http://" + $ip + ":8000"),
      "-e", "DISABLE_AUTH=true",
      "ghcr.io/redis-developer/agent-memory-mcp:latest"
    ]
  }
')

# Write updated config
echo "$UPDATED_CONFIG" > "$CONFIG_FILE"

echo "✅ Configuration updated successfully!"
echo ""
echo "📝 Added Redis Memory Server MCP configuration:"
echo "$UPDATED_CONFIG" | jq '.["redis-memory-server"]'
echo ""
echo "⚠️  Please restart Claude Desktop for changes to take effect"
echo ""
echo "🧪 To test the connection, run:"
echo "   python3 $(dirname "$0")/test-connection.py"