output "container_id" {
  value = proxmox_lxc.redis_memory_server.id
  description = "The ID of the created LXC container"
}

output "container_ip" {
  value = "10.10.20.85"
  description = "The IP address of the Redis Memory server"
}

output "container_hostname" {
  value = proxmox_lxc.redis_memory_server.hostname
  description = "The hostname of the container"
}

output "api_url" {
  value = "http://10.10.20.85:8000"
  description = "The URL for the Redis Memory API"
}

output "mcp_url" {
  value = "http://10.10.20.85:9000"
  description = "The URL for the MCP server"
}

output "redis_url" {
  value = "redis://10.10.20.85:16379"
  description = "The Redis connection URL"
}