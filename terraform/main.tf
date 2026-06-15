# ============================================================
# AIRSOLID — Infrastructure virtualisée Proxmox
# Provider: bpg/proxmox  |  VMIDs: 200-299
# NE PAS TOUCHER les VMs homelab 100-103
# ============================================================

locals {
  node    = var.proxmox_node
  storage = var.airsolid_storage

  # Tags communs pour toutes les VMs AIRSOLID
  common_tags = ["airsolid", "mspr"]
}

# -----------------------------------------------------------
# VM 200 — OPNsense / Firewall
# -----------------------------------------------------------
resource "proxmox_virtual_environment_vm" "airsolid_firewall" {
  name      = "airsolid-fw"
  node_name = local.node
  vm_id     = 200

  description = "AIRSOLID — Pare-feu OPNsense (simulé via Linux cloud-init)"
  tags        = concat(local.common_tags, ["firewall", "network"])

  on_boot = false  # Ne pas démarrer automatiquement (RAM limitée)

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 1024
  }

  disk {
    datastore_id = local.storage
    size         = 20
    interface    = "virtio0"
    file_format  = "raw"
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = 10
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = 20
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.10.1/24"
        gateway = "192.168.1.1"
      }
    }
  }

  lifecycle {
    ignore_changes = [initialization]
  }
}

# -----------------------------------------------------------
# VM 201 — DC1 / Active Directory (Windows → Linux cloud-init)
# -----------------------------------------------------------
resource "proxmox_virtual_environment_vm" "airsolid_dc1" {
  name      = "airsolid-dc1"
  node_name = local.node
  vm_id     = 201

  description = "AIRSOLID — Contrôleur de domaine AD/ADDS (Linux cloud-init, écart documenté : cible Windows Server 2022)"
  tags        = concat(local.common_tags, ["ad", "dc", "identity"])

  on_boot = false

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = local.storage
    size         = 40
    interface    = "virtio0"
    file_format  = "raw"
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = 20
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.20.10/24"
        gateway = "192.168.1.1"
      }
    }
    user_account {
      username = "airsolid"
      password = "ChangeMe123!"
    }
  }

  lifecycle {
    ignore_changes = [initialization]
  }
}

# -----------------------------------------------------------
# VM 202 — ERP Web (Windows → Linux cloud-init)
# -----------------------------------------------------------
resource "proxmox_virtual_environment_vm" "airsolid_erp" {
  name      = "airsolid-erp"
  node_name = local.node
  vm_id     = 202

  description = "AIRSOLID — Serveur ERP Web (Linux cloud-init, écart documenté : cible Windows Server 2022 + ERP)"
  tags        = concat(local.common_tags, ["erp", "app"])

  on_boot = false

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = local.storage
    size         = 40
    interface    = "virtio0"
    file_format  = "raw"
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = 20
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.20.20/24"
        gateway = "192.168.1.1"
      }
    }
    user_account {
      username = "airsolid"
      password = "ChangeMe123!"
    }
  }

  lifecycle {
    ignore_changes = [initialization]
  }
}

# -----------------------------------------------------------
# VM 203 — Serveur de fichiers (Windows → Linux cloud-init)
# -----------------------------------------------------------
resource "proxmox_virtual_environment_vm" "airsolid_fileserver" {
  name      = "airsolid-fs"
  node_name = local.node
  vm_id     = 203

  description = "AIRSOLID — Serveur de fichiers / partages (Linux cloud-init, écart documenté : cible Windows Server 2022 + partages SMB)"
  tags        = concat(local.common_tags, ["fileserver", "storage"])

  on_boot = false

  cpu {
    cores = 1
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 1024
  }

  disk {
    datastore_id = local.storage
    size         = 80
    interface    = "virtio0"
    file_format  = "raw"
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = 20
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.20.30/24"
        gateway = "192.168.1.1"
      }
    }
    user_account {
      username = "airsolid"
      password = "ChangeMe123!"
    }
  }

  lifecycle {
    ignore_changes = [initialization]
  }
}

# -----------------------------------------------------------
# VM 204 — Supervision / Monitoring (Netdata/Zabbix)
# -----------------------------------------------------------
resource "proxmox_virtual_environment_vm" "airsolid_monitoring" {
  name      = "airsolid-monitoring"
  node_name = local.node
  vm_id     = 204

  description = "AIRSOLID — Supervision centralisée (Netdata ou Zabbix, Linux cloud-init)"
  tags        = concat(local.common_tags, ["monitoring", "supervision"])

  on_boot = false

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = local.storage
    size         = 20
    interface    = "virtio0"
    file_format  = "raw"
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = 10
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.10.50/24"
        gateway = "192.168.1.1"
      }
    }
    user_account {
      username = "airsolid"
      password = "ChangeMe123!"
    }
  }

  lifecycle {
    ignore_changes = [initialization]
  }
}

# -----------------------------------------------------------
# VM 205 — Proxmox Backup Server (simulé via Linux)
# -----------------------------------------------------------
resource "proxmox_virtual_environment_vm" "airsolid_backup" {
  name      = "airsolid-pbs"
  node_name = local.node
  vm_id     = 205

  description = "AIRSOLID — Proxmox Backup Server simulé (Linux cloud-init, écart documenté : cible PBS dédié)"
  tags        = concat(local.common_tags, ["backup", "pbs"])

  on_boot = false

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = local.storage
    size         = 50
    interface    = "virtio0"
    file_format  = "raw"
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = 40
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.40.10/24"
        gateway = "192.168.1.1"
      }
    }
    user_account {
      username = "airsolid"
      password = "ChangeMe123!"
    }
  }

  lifecycle {
    ignore_changes = [initialization]
  }
}
