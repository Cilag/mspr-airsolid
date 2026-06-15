variable "proxmox_endpoint" {
  description = "URL of the Proxmox VE API (include trailing slash)"
  type        = string
  default     = "https://192.168.1.100:8006/"
}

variable "proxmox_token_id" {
  description = "Proxmox API token ID in the form user@realm!tokenname"
  type        = string
  sensitive   = true
}

variable "proxmox_token_secret" {
  description = "Proxmox API token secret UUID"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Name of the Proxmox node where VMs will be created"
  type        = string
  default     = "pve"
}
