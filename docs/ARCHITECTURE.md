# Redis Memory Central - Architecture

## Overview

This document describes the architecture of the centralized Redis Memory Server deployment on Proxmox LXC.

## Network Topology

```
┌─────────────────────────────────────────────────────────────┐
│                    Proxmox Cluster                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────┐  ┌──────────────────────────┐   │
│  │  LXC: Redis Memory        │  │  LXC: Neo4j          │   │
│  │  ID: 850                  │  │  ID: 840             │   │
│  │  IP: 10.10.20.85         │  │  IP: 10.10.20.84     │   │
│  │                          │  │                      │   │
│  │  Services:               │  │  Services:           │   │
│  │  - Redis Stack (16379)   │  │  - Neo4j (7687)      │   │
│  │  - API Server (8000)     │  │  - HTTP (7474)       │   │
│  │  - MCP Server (9000)     │  │                      │   │
│  │  - Task Worker           │  │                      │   │
│  │  - RedisInsight (18001)  │  │                      │   │
│  └──────────────────────────────┘  └──────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Internal Network
                            │ 10.10.20.0/24
                            │
┌─────────────────────────────────────────────────────────────┐
│                    Client Machines                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐    │
│  │ Windows PC   │  │ Mac Machine  │  │ Linux Server │    │
│  │ Claude/AI    │  │ Claude/AI    │  │ Services     │    │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Component Architecture

### 1. LXC Container
- **Base OS**: Ubuntu 22.04 LTS
- **Resources**: 4 CPU, 8GB RAM, 100GB Storage
- **Features**: Nested containers, Docker support

### 2. Service Stack

#### Redis Stack (Port 16379)
- Redis 7.x with RediSearch module
- Persistence: AOF + RDB snapshots
- Memory limit: 4GB
- RedisInsight UI on port 18001

#### API Server (Port 8000)
- FastAPI application
- RESTful endpoints
- OAuth2/JWT support (disabled for LAN)
- Health monitoring

#### MCP Server (Port 9000)
- Model Context Protocol server
- SSE and stdio modes
- AI agent integration

#### Background Worker
- Celery-based task processing
- Semantic indexing via OpenAI
- Memory compaction and promotion
- Concurrency: 2 workers

### 3. Data Flow

```
AI Agent Request → MCP Server (9000)
                        ↓
                  Redis Memory Logic
                        ↓
                  Redis Stack (16379)
                        ↓
                  Background Worker
                        ↓
                  OpenAI Embeddings
```

### 4. High Availability

- **Systemd**: Service management with auto-restart
- **Docker**: Container restart policies
- **Monitoring**: Prometheus metrics + alerts
- **Backups**: Daily snapshots to PBS

### 5. Security Model

- **Network**: Internal LAN only (10.10.20.0/24)
- **Firewall**: UFW rules restrict access
- **Auth**: Disabled for internal use (configurable)
- **Secrets**: Environment variables in .env

## Scaling Considerations

### Vertical Scaling
- Increase LXC resources (CPU/RAM)
- Adjust Redis memory limits
- Add more background workers

### Horizontal Scaling (Future)
- Redis Cluster for sharding
- Multiple API/MCP instances
- Load balancer (HAProxy/Nginx)
- Shared storage (NFS/Ceph)

## Integration Points

### With Neo4j (10.10.20.84)
- Unified memory queries
- Cross-system memory sync
- Shared authentication (future)

### With Monitoring Stack
- Prometheus metrics export
- Grafana dashboards
- Log aggregation (Loki)
- Alert routing

### With Backup Infrastructure
- Proxmox Backup Server integration
- Redis persistence files
- Configuration versioning

## Performance Targets

- API Response: < 100ms (LAN)
- Memory Search: < 200ms
- Embedding Generation: < 500ms
- Concurrent Clients: 50+
- Memory Usage: < 6GB total