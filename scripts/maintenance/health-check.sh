#!/bin/bash
set -euo pipefail

# Health check script for Redis Memory Central

SERVER_IP="${1:-10.10.20.85}"
VERBOSE="${2:-false}"

echo "🏥 Redis Memory Central Health Check"
echo "==================================="
echo "Server: $SERVER_IP"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check functions
check_service() {
    local name=$1
    local port=$2
    local endpoint=${3:-""}
    
    echo -n "Checking $name (port $port)... "
    
    if nc -z -w2 $SERVER_IP $port 2>/dev/null; then
        if [ -n "$endpoint" ]; then
            # HTTP check
            response=$(curl -s -o /dev/null -w "%{http_code}" "http://$SERVER_IP:$port$endpoint" 2>/dev/null || echo "000")
            if [ "$response" = "200" ]; then
                echo -e "${GREEN}✓ OK${NC}"
                return 0
            else
                echo -e "${YELLOW}⚠ Service up but returned $response${NC}"
                return 1
            fi
        else
            echo -e "${GREEN}✓ OK${NC}"
            return 0
        fi
    else
        echo -e "${RED}✗ FAILED${NC}"
        return 1
    fi
}

# Run checks
FAILED=0

echo "Service Checks:"
echo "--------------"
check_service "Redis" 16379 || ((FAILED++))
check_service "API Server" 8000 "/health" || ((FAILED++))
check_service "MCP Server" 9000 || ((FAILED++))
check_service "RedisInsight" 18001 || ((FAILED++))

# Redis detailed check
echo -e "\nRedis Status:"
echo "-------------"
if redis-cli -h $SERVER_IP -p 16379 ping > /dev/null 2>&1; then
    echo -e "Ping: ${GREEN}✓ PONG${NC}"
    
    # Get Redis info
    if [ "$VERBOSE" = "true" ]; then
        redis-cli -h $SERVER_IP -p 16379 INFO server | grep -E "redis_version|uptime_in_days"
        redis-cli -h $SERVER_IP -p 16379 INFO memory | grep -E "used_memory_human|maxmemory_human"
    fi
else
    echo -e "Ping: ${RED}✗ FAILED${NC}"
    ((FAILED++))
fi

# API detailed check
echo -e "\nAPI Status:"
echo "-----------"
api_response=$(curl -s "http://$SERVER_IP:8000/v1/health" 2>/dev/null)
if [ $? -eq 0 ]; then
    echo -e "Health Endpoint: ${GREEN}✓ OK${NC}"
    if [ "$VERBOSE" = "true" ]; then
        echo "$api_response" | jq -r '.status, .redis_connected' 2>/dev/null || echo "$api_response"
    fi
else
    echo -e "Health Endpoint: ${RED}✗ FAILED${NC}"
    ((FAILED++))
fi

# Memory test
echo -e "\nMemory Test:"
echo "------------"
test_response=$(curl -s -X POST "http://$SERVER_IP:8000/v1/long-term-memory" \
    -H "Content-Type: application/json" \
    -d '{
        "memories": [{
            "text": "Health check test memory",
            "memory_type": "semantic",
            "id": "health_check_test"
        }]
    }' 2>/dev/null)

if [ $? -eq 0 ]; then
    echo -e "Create Memory: ${GREEN}✓ OK${NC}"
    
    # Try to search for it
    search_response=$(curl -s -X POST "http://$SERVER_IP:8000/v1/long-term-memory/search" \
        -H "Content-Type: application/json" \
        -d '{"text": "health check test"}' 2>/dev/null)
    
    if echo "$search_response" | grep -q "health_check_test"; then
        echo -e "Search Memory: ${GREEN}✓ OK${NC}"
    else
        echo -e "Search Memory: ${YELLOW}⚠ No results${NC}"
    fi
else
    echo -e "Create Memory: ${RED}✗ FAILED${NC}"
    ((FAILED++))
fi

# Summary
echo -e "\n==================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ $FAILED checks failed${NC}"
    exit 1
fi