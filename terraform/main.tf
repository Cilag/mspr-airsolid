# =============================================================================
# AIRSOLID MSPR — Proxmox VM definitions
# Provider: bpg/proxmox ~> 0.69
#
# VMID range: 200-299 (MSPR project range — NEVER touch 100-103)
# Total RAM: 2048 + 4096 + 2048 = 8192 MB (≤ 10 240 MB limit ✓)
#
# Network bridge: vmbr99
#   An isolated internal bridge with NO uplink to vmbr0.
#   It must be created manually on the Proxmox host BEFORE running
#   `terraform apply`, because bpg/proxmox does not manage Linux bridges.
#   Run on the Proxmox host (as root):
#
#     pvesh create /nodes/pve/network \
#       --iface vmbr99 \
#       --type bridge \
#       --autostart 1 \
#       --comments "AIRSOLID isolated internal bridge — no uplink"
#     pvesh set /nodes/pve/network   # apply changes
#
#   Verify with: ip link show vmbr99
#
# VM creation strategy: bare VMs (no template clone)
#   We create empty-disk VMs so that `terraform apply` succeeds regardless of
#   whether a cloud-init template exists on the node.  The VMs are left in
#   stopped state (`started = false`).  To make them bootable, either:
#     a) Attach an ISO via the Proxmox UI and install the OS manually, or
#     b) Replace the resource blocks with clone{} blocks pointing to a
#        pre-built cloud-init template (e.g. local:9000 for a Debian template).
# =============================================================================

# -----------------------------------------------------------------------------
# VMID 201 — airsolid-ad-dc — Active Directory / Domain Controller
# -----------------------------------------------------------------------------
resource "proxmox_virtual_environment_vm" "airsolid_ad_dc" {
  vm_id     = 201
  name      = "airsolid-ad-dc"
  node_name = var.proxmox_node

  description = "AIRSOLID MSPR — Active Directory / Domain Controller. Install Windows Server 2022 (or Samba AD on Debian) via Proxmox console after terraform apply."

  # Leave stopped — no OS image is attached at provisioning time.
  started = false

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 2048
  }

  # Primary disk — empty, 32 GB on local-lvm.
  # Attach an OS ISO via the Proxmox UI to make this VM bootable.
  disk {
    interface    = "scsi0"
    size         = 32
    datastore_id = "local-lvm"
    file_format  = "raw"
  }

  # Isolated AIRSOLID bridge — no uplink to vmbr0 (see header note).
  network_device {
    bridge = "vmbr99"
    model  = "virtio"
  }

  # Avoid Terraform drift if cloud-init config is set later via the UI.
  lifecycle {
    ignore_changes = [initialization]
  }
}

# -----------------------------------------------------------------------------
# VMID 202 — airsolid-erp — ERP server
# -----------------------------------------------------------------------------
resource "proxmox_virtual_environment_vm" "airsolid_erp" {
  vm_id     = 202
  name      = "airsolid-erp"
  node_name = var.proxmox_node

  description = "AIRSOLID MSPR — ERP server (e.g. Odoo / Dolibarr). Install OS via Proxmox console after terraform apply."

  started = false

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
  }

  disk {
    interface    = "scsi0"
    size         = 50
    datastore_id = "local-lvm"
    file_format  = "raw"
  }

  network_device {
    bridge = "vmbr99"
    model  = "virtio"
  }

  lifecycle {
    ignore_changes = [initialization]
  }
}

# -----------------------------------------------------------------------------
# VMID 203 — airsolid-backup-pra — Backup / PRA server
# -----------------------------------------------------------------------------
resource "proxmox_virtual_environment_vm" "airsolid_backup_pra" {
  vm_id     = 203
  name      = "airsolid-backup-pra"
  node_name = var.proxmox_node

  description = "AIRSOLID MSPR — Backup and PRA server (e.g. Veeam Agent / Bacula / BorgBackup). Install OS via Proxmox console after terraform apply."

  started = false

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 2048
  }

  disk {
    interface    = "scsi0"
    size         = 100
    datastore_id = "local-lvm"
    file_format  = "raw"
  }

  network_device {
    bridge = "vmbr99"
    model  = "virtio"
  }

  lifecycle {
    ignore_changes = [initialization]
  }
}
