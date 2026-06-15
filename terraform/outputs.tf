output "airsolid_vm_ids" {
  description = "VMIDs des VMs AIRSOLID créées"
  value = {
    firewall   = proxmox_virtual_environment_vm.airsolid_firewall.vm_id
    dc1        = proxmox_virtual_environment_vm.airsolid_dc1.vm_id
    erp        = proxmox_virtual_environment_vm.airsolid_erp.vm_id
    fileserver = proxmox_virtual_environment_vm.airsolid_fileserver.vm_id
    monitoring = proxmox_virtual_environment_vm.airsolid_monitoring.vm_id
    backup     = proxmox_virtual_environment_vm.airsolid_backup.vm_id
  }
}

output "airsolid_vm_names" {
  description = "Noms des VMs AIRSOLID créées"
  value = {
    firewall   = proxmox_virtual_environment_vm.airsolid_firewall.name
    dc1        = proxmox_virtual_environment_vm.airsolid_dc1.name
    erp        = proxmox_virtual_environment_vm.airsolid_erp.name
    fileserver = proxmox_virtual_environment_vm.airsolid_fileserver.name
    monitoring = proxmox_virtual_environment_vm.airsolid_monitoring.name
    backup     = proxmox_virtual_environment_vm.airsolid_backup.name
  }
}

output "proxmox_node" {
  description = "Nœud Proxmox utilisé"
  value       = var.proxmox_node
}

output "ram_total_allocated_mb" {
  description = "RAM totale allouée aux VMs AIRSOLID (MB) — ne doit pas dépasser 10240 MB"
  value       = 1024 + 2048 + 2048 + 1024 + 2048 + 2048
}
