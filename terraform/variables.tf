variable "proxmox_endpoint" {
  description = "URL de l'API Proxmox VE"
  type        = string
  default     = "https://192.168.1.100:8006/"
}

variable "proxmox_token_id" {
  description = "ID du token API Proxmox (format: user@realm!tokenname)"
  type        = string
  default     = "terraform@pve!mytoken"
}

variable "proxmox_token_secret" {
  description = "Secret du token API Proxmox"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Nom du nœud Proxmox cible"
  type        = string
  default     = "pve"
}

variable "airsolid_cloud_init_template" {
  description = "Template cloud-init à utiliser pour les VMs Linux (ex: local:iso/ubuntu-22.04-cloudimg.img)"
  type        = string
  default     = ""
}

variable "airsolid_storage" {
  description = "Stockage Proxmox pour les disques VMs AIRSOLID"
  type        = string
  default     = "local-lvm"
}
