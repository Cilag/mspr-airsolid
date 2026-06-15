provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = "${var.proxmox_token_id}=${var.proxmox_token_secret}"

  # Accept the self-signed TLS certificate shipped with Proxmox VE
  insecure = true
}
