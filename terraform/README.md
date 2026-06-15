# Terraform AIRSOLID — Proxmox VE

Provisioning de l'infrastructure virtualisée AIRSOLID sur Proxmox VE via le provider **bpg/proxmox**.

## Architecture déployée

| VMID | Nom | Rôle | vCPU | RAM | Disk | VLAN | OS |
|------|-----|------|------|-----|------|------|----|
| 200 | airsolid-fw | Pare-feu OPNsense | 2 | 1 Go | 20 Go | 10 | Linux cloud-init¹ |
| 201 | airsolid-dc1 | AD/ADDS DC1 | 2 | 2 Go | 40 Go | 20 | Linux cloud-init¹ |
| 202 | airsolid-erp | ERP Web | 2 | 2 Go | 40 Go | 20 | Linux cloud-init¹ |
| 203 | airsolid-fs | Serveur de fichiers | 1 | 1 Go | 80 Go | 20 | Linux cloud-init¹ |
| 204 | airsolid-monitoring | Supervision | 2 | 2 Go | 20 Go | 10 | Linux cloud-init |
| 205 | airsolid-pbs | Sauvegarde (PBS) | 2 | 2 Go | 50 Go | 40 | Linux cloud-init¹ |

**Total RAM : 10 Go** (hôte 16 Go — budget sécurisé)

¹ Écart vs cible : les rôles AD/ERP/FS/OPNsense/PBS ciblent Windows Server 2022 ou PBS natif en production. Les VMs Linux prouvent le provisioning Terraform ; l'OS final est documenté dans `airsolid/06-test-terraform-proxmox.md`.

## Topologie réseau

```
vmbr0 (bridge LAN Proxmox — 192.168.1.0/24)
  ├── VLAN 10 — Management (fw, monitoring)     192.168.10.0/24
  ├── VLAN 20 — Serveurs (AD, ERP, FS)          192.168.20.0/24
  ├── VLAN 30 — Utilisateurs / VDI              192.168.30.0/24 (réservé)
  └── VLAN 40 — Sauvegarde (PBS)                192.168.40.0/24
```

## Prérequis

1. **Proxmox VE ≥ 8.x** sur `192.168.1.100` (testé sur PVE 9.2.3)
2. **Token API Proxmox** avec droits PVEVMAdmin :
   ```bash
   # Sur root@192.168.1.100 :
   pveum user add terraform@pve
   pveum aclmod / -user terraform@pve -role PVEVMAdmin
   pveum user token add terraform@pve mytoken --privsep=0
   # Noter le secret retourné
   ```
3. **Terraform ≥ 1.5** installé sur 192.168.1.16
4. **Storage** `local-lvm` disponible (ou adapter `airsolid_storage`)

## Utilisation

```bash
cd terraform/

# 1. Configurer les variables
cp terraform.tfvars.example terraform.tfvars
# Éditer terraform.tfvars avec vos valeurs (token secret)

# 2. Initialiser le provider
terraform init

# 3. Vérifier le plan
terraform plan

# 4. Appliquer (crée les VMs 200-205)
terraform apply

# 5. Vérifier sur Proxmox
ssh root@192.168.1.100 "qm list"

# 6. Test idempotence
terraform apply  # doit montrer "0 added, 0 changed, 0 destroyed"

# 7. Nettoyage
terraform destroy
ssh root@192.168.1.100 "qm list"  # VMs 200-205 absentes
```

## Garde-fous impératifs

- **VMIDs AIRSOLID : 200-299 UNIQUEMENT**
- **VMs homelab 100-103 : NE JAMAIS MODIFIER**
- `on_boot = false` sur toutes les VMs (démarrer manuellement selon les besoins RAM)
- Toutes les VMs sont créées sans démarrage auto pour éviter l'OOM
