terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "~> 2.9"
    }
  }
}

provider "proxmox" {
  pm_api_url      = var.proxmox_api_url
  pm_user         = var.proxmox_user
  pm_password     = var.proxmox_password
  pm_tls_insecure = var.proxmox_tls_insecure
}

resource "proxmox_lxc" "redis_memory_server" {
  target_node  = var.proxmox_node
  hostname     = "redis-memory-central"
  ostemplate   = var.lxc_template
  unprivileged = true
  onboot       = true
  start        = true

  cores  = 4
  memory = 8192
  swap   = 2048

  rootfs {
    storage = var.storage_pool
    size    = "100G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "10.10.20.85/24"
    gw     = var.gateway
  }

  features {
    nesting = true
    fuse    = true
    mount   = "nfs;cifs"
  }

  # Enable Docker support in LXC
  lxc {
    lxc.apparmor.profile = "unconfined"
    lxc.cgroup2.devices.allow = "a"
    lxc.cap.drop = ""
  }
}