variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://proxmox.local:8006/api2/json"
}

variable "proxmox_user" {
  description = "Proxmox user"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification"
  type        = bool
  default     = true
}

variable "lxc_template" {
  description = "LXC template to use"
  type        = string
  default     = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
}

variable "storage_pool" {
  description = "Storage pool for LXC"
  type        = string
  default     = "local-lvm"
}

variable "gateway" {
  description = "Network gateway"
  type        = string
  default     = "10.10.20.1"
}

variable "vlan_tag" {
  description = "VLAN tag for network interface (leave empty for no VLAN)"
  type        = number
  default     = 20
}