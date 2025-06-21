# 🚀 Redis Memory Central - Proxmox LXC Deployment

Transform your distributed Redis Memory Server instances into a powerful centralized AI memory system accessible by all agents on your LAN.

## 🎯 What This Does

- **Centralizes** all AI agent memories in one location (10.10.20.85)
- **Shares** knowledge between all your AI agents and Claude instances
- **Scales** efficiently with your growing AI infrastructure
- **Integrates** seamlessly with your existing Neo4j setup
- **Simplifies** management with single-point administration

## 📋 Quick Start

```bash
# On your Proxmox host
cd /opt
git clone https://github.com/eddygk/redis-memory-central.git
cd redis-memory-central

# Configure environment
cp .env.example .env
nano .env  # Add your API keys

# Run automated installation
./scripts/setup/install.sh

# Test the deployment
python3 scripts/client/test-connection.py
```

That's it! Your centralized Redis Memory Server is now running at `http://10.10.20.85`

## 🏗️ Architecture

```
Your LAN (10.10.20.0/24) - VLAN 20
├── Proxmox Host
│   ├── LXC: Redis Memory (10.10.20.85)
│   │   ├── Redis Stack (Port 16379)
│   │   ├── API Server (Port 8000)
│   │   ├── MCP Server (Port 9000)
│   │   └── Task Worker
│   └── LXC: Neo4j (10.10.20.84)
│
└── AI Clients
    ├── Windows PCs with Claude
    ├── Mac machines with Claude
    └── Linux servers with agents
```

## 📁 Repository Structure

```
redis-memory-central/
├── 📄 README.md (this file)
├── 🔧 .env.example (configuration template)
├── 📚 docs/
│   ├── ARCHITECTURE.md (system design)
│   ├── DEPLOYMENT.md (step-by-step guide)
│   ├── MIGRATION.md (move from local to central)
│   └── TROUBLESHOOTING.md (common issues)
├── 🏗️ infrastructure/
│   ├── terraform/ (LXC provisioning)
│   └── ansible/ (configuration management)
├── 🐳 deployment/
│   └── docker-compose.yml (service definitions)
├── 📜 scripts/
│   ├── setup/ (installation scripts)
│   ├── client/ (Claude configuration)
│   ├── migration/ (data migration tools)
│   └── maintenance/ (backup, monitoring)
└── 🧪 tests/
    └── integration/ (validation suite)
```

## 🔧 Key Features

### For System Admins
- **One-command deployment** on Proxmox
- **Automated backups** to Proxmox Backup Server
- **Built-in monitoring** with health checks
- **Systemd integration** for reliability
- **Resource efficient** LXC containers

### For AI Users
- **Shared memory** across all agents
- **Fast searches** with semantic similarity
- **Automatic summarization** of conversations
- **Topic extraction** and entity recognition
- **Cross-system memory** with Neo4j integration

### For Developers
- **REST API** at port 8000
- **MCP Protocol** at port 9000
- **Redis interface** at port 16379
- **Python client libraries**
- **Comprehensive test suite**

## 📦 What's Included

### Core Services
- ✅ Redis Stack with RediSearch
- ✅ FastAPI REST server
- ✅ MCP server (stdio & SSE)
- ✅ Background task worker
- ✅ RedisInsight UI

### Management Tools
- ✅ Automated installer
- ✅ Client configurators
- ✅ Migration scripts
- ✅ Health monitors
- ✅ Backup automation

### Documentation
- ✅ Architecture guide
- ✅ Deployment walkthrough
- ✅ Migration playbook
- ✅ Troubleshooting guide
- ✅ API documentation

## 🚀 Getting Started

### 1. Prerequisites
- Proxmox VE 7.x or 8.x
- 8GB RAM, 100GB storage
- OpenAI API key
- Network access to 10.10.20.0/24

### 2. Deploy Server
```bash
# Clone and configure
git clone https://github.com/eddygk/redis-memory-central.git
cd redis-memory-central
cp .env.example .env
# Edit .env with your API keys

# Deploy to Proxmox
./scripts/setup/install.sh
```

### 3. Configure Clients
```bash
# On each client machine
./scripts/client/configure-claude.sh
```

### 4. Migrate Data
```bash
# From existing local instances
python3 scripts/migration/migrate-memories.py
```

## 📊 Monitoring

### Health Status
- API Health: http://10.10.20.85:8000/v1/health
- RedisInsight: http://10.10.20.85:18001
- Metrics: http://10.10.20.85:9090/metrics

### Quick Checks
```bash
# Test all services
./scripts/maintenance/health-check.sh

# View logs
ssh redis-memory@10.10.20.85
docker-compose logs -f

# Check resource usage
docker stats
```

## 🔐 Security

Default configuration for internal LAN use:
- ✅ Firewall restricted to 10.10.20.0/24
- ✅ No external access
- ✅ Auth disabled for internal use
- ✅ API keys stored securely

For production with external access, see [Security Guide](docs/SECURITY.md).

## 🆘 Troubleshooting

### Common Issues

**Can't connect from client:**
```bash
# Check network connectivity
ping 10.10.20.85
# Verify firewall
ssh redis-memory@10.10.20.85 ufw status
```

**Memories not searchable:**
```bash
# Check task worker
docker logs redis-memory-task-worker
# Reindex if needed
curl -X POST http://10.10.20.85:8000/v1/admin/reindex
```

**High memory usage:**
```bash
# Check Redis memory
redis-cli -h 10.10.20.85 -p 16379 INFO memory
# Run compaction
docker exec redis-memory-task-worker python -m compact_memories
```

See [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more.

## 📈 Performance

Expected performance on LAN:
- Memory search: < 200ms
- Memory creation: < 300ms  
- API response: < 100ms
- Concurrent clients: 50+

## 🔄 Updates

Keep your deployment current:
```bash
cd /opt/redis-memory-central
git pull
./scripts/maintenance/update-services.sh
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Test thoroughly
4. Submit pull request

## 📄 License

MIT License - See [LICENSE](LICENSE) file

## 🙏 Acknowledgments

- Built on [Redis Agent Memory Server](https://github.com/redis-developer/agent-memory-server)
- Powered by Redis Stack and OpenAI
- Deployed on Proxmox virtualization

---

## 🎉 Success Checklist

After deployment, you should have:

- [ ] LXC container running at 10.10.20.85
- [ ] All services healthy (check http://10.10.20.85:8000/v1/health)
- [ ] Claude Desktop configured on all clients
- [ ] Successful test run (`test-connection.py`)
- [ ] Data migrated from local instances
- [ ] Automated backups configured
- [ ] Monitoring alerts set up

**Congratulations!** Your AI agents now share a unified memory system! 🧠✨

---

*Need help? Check the [docs/](docs/) folder or open an issue.*