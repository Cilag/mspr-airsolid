output "airsolid_ad_dc_vmid" {
  description = "VMID of the Active Directory / Domain Controller VM"
  value       = proxmox_virtual_environment_vm.airsolid_ad_dc.vm_id
}

output "airsolid_ad_dc_name" {
  description = "Name of the Active Directory / Domain Controller VM"
  value       = proxmox_virtual_environment_vm.airsolid_ad_dc.name
}

output "airsolid_erp_vmid" {
  description = "VMID of the ERP server VM"
  value       = proxmox_virtual_environment_vm.airsolid_erp.vm_id
}

output "airsolid_erp_name" {
  description = "Name of the ERP server VM"
  value       = proxmox_virtual_environment_vm.airsolid_erp.name
}

output "airsolid_backup_pra_vmid" {
  description = "VMID of the Backup / PRA server VM"
  value       = proxmox_virtual_environment_vm.airsolid_backup_pra.vm_id
}

output "airsolid_backup_pra_name" {
  description = "Name of the Backup / PRA server VM"
  value       = proxmox_virtual_environment_vm.airsolid_backup_pra.name
}
