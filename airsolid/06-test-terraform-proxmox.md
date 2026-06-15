# 06 — Test Terraform + Proxmox

**Date :** 2026-06-15  
**Opérateur :** Infra Lead (GUI-203)  
**Hôte PVE :** 192.168.1.100 (Proxmox VE 9.2.3)  
**Provider Terraform :** bpg/proxmox v0.109.0 (compatible `~> 0.66`)  

---

## Environnement de test

| Paramètre | Valeur |
|-----------|--------|
| Hôte Proxmox | 192.168.1.100 |
| Version PVE | 9.2.3 |
| RAM hôte | 16 Go |
| RAM libre (VMs homelab arrêtées) | ~14 Go |
| Stockage images | `local` (ISO, backup) |
| Stockage disques VM | `local-lvm` (LVM thin) |
| Bridge réseau | `vmbr0` (LAN, 192.168.1.100/24) |
| Terraform | >= 1.5, bpg/proxmox v0.109.0 |
| Workdir terraform | `/tmp/mspr-airsolid-tf/terraform/` |

---

## Templates disponibles (`qm list` avant apply)

```
      VMID NAME                 STATUS     MEM(MB)    BOOTDISK(GB) PID
       100 vyos                 stopped    512                4.00 0
       101 truenas              stopped    4096              20.00 0
       102 monitoring           stopped    1024              10.00 0
       103 pihole               stopped    512                5.00 0
```

**ISOs disponibles sur `local` :**
- `debian-12.14.0-amd64-netinst.iso` (677 Mo)
- `TrueNAS-SCALE-24.10.2.2.iso` (1,7 Go)
- `vyos-rolling-latest.iso` (654 Mo)

**Templates VM cloud-init :** aucun — pas de template Ubuntu Server ni Windows Server disponible sur cet hôte homelab.

---

## Token API Proxmox créé

```bash
pveum user add terraform@pve
pveum aclmod / -user terraform@pve -role PVEVMAdmin
pveum aclmod /storage/local-lvm -user terraform@pve -role PVEDatastoreAdmin
pveum aclmod /storage/local -user terraform@pve -role PVEDatastoreAdmin
pveum aclmod /sdn/zones/localnetwork -user terraform@pve -role PVESDNUser
pveum user token add terraform@pve mytoken --privsep=0
```

**Token généré :** `terraform@pve!mytoken`

**ACL effectives :**

```
┌─────────────────────────┬───────────────────┬──────┬───────────────┬───────────┐
│ path                    │ roleid            │ type │ ugid          │ propagate │
╞═════════════════════════╪═══════════════════╪══════╪═══════════════╪═══════════╡
│ /                       │ PVEVMAdmin        │ user │ terraform@pve │ 1         │
├─────────────────────────┼───────────────────┼──────┼───────────────┼───────────┤
│ /sdn/zones/localnetwork │ PVESDNUser        │ user │ terraform@pve │ 1         │
├─────────────────────────┼───────────────────┼──────┼───────────────┼───────────┤
│ /storage/local          │ PVEDatastoreAdmin │ user │ terraform@pve │ 1         │
├─────────────────────────┼───────────────────┼──────┼───────────────┼───────────┤
│ /storage/local-lvm      │ PVEDatastoreAdmin │ user │ terraform@pve │ 1         │
└─────────────────────────┴───────────────────┴──────┴───────────────┴───────────┘
```

> **Note critique :** PVE 9.x impose `SDN.Use` sur `/sdn/zones/localnetwork` pour attacher une interface réseau à un bridge. Cette permission n'est pas documentée dans la plupart des guides Terraform/Proxmox. Sans elle, l'apply échoue avec HTTP 403.

---

## `terraform init`

```
Initializing provider plugins found in the configuration...
- Finding bpg/proxmox versions matching "~> 0.66"...
- Installing bpg/proxmox v0.109.0...
- Installed bpg/proxmox v0.109.0 (self-signed, key ID F0582AD6AE97C188)

Terraform has been successfully initialized!
```

---

## `terraform plan` (sortie complète — résumé)

```
proxmox_virtual_environment_vm.airsolid_backup will be created
proxmox_virtual_environment_vm.airsolid_dc1 will be created
proxmox_virtual_environment_vm.airsolid_erp will be created
proxmox_virtual_environment_vm.airsolid_fileserver will be created
proxmox_virtual_environment_vm.airsolid_firewall will be created
proxmox_virtual_environment_vm.airsolid_monitoring will be created

Plan: 6 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + airsolid_vm_ids = {
      + backup     = 205
      + dc1        = 201
      + erp        = 202
      + fileserver = 203
      + firewall   = 200
      + monitoring = 204
    }
  + ram_total_allocated_mb = 10240
```

**Résultat plan : 0 erreur, 6 ressources à créer. RAM totale = 10 240 Mo (10 Go, dans limite hôte).**

---

## `terraform apply` (sortie complète)

```
proxmox_virtual_environment_vm.airsolid_firewall: Creating...
proxmox_virtual_environment_vm.airsolid_fileserver: Creating...
proxmox_virtual_environment_vm.airsolid_dc1: Creating...
proxmox_virtual_environment_vm.airsolid_monitoring: Creating...
proxmox_virtual_environment_vm.airsolid_backup: Creating...
proxmox_virtual_environment_vm.airsolid_erp: Creating...
proxmox_virtual_environment_vm.airsolid_firewall: Creation complete after 5s [id=200]
proxmox_virtual_environment_vm.airsolid_fileserver: Creation complete after 5s [id=203]
proxmox_virtual_environment_vm.airsolid_dc1: Creation complete after 5s [id=201]
proxmox_virtual_environment_vm.airsolid_monitoring: Creation complete after 5s [id=204]
proxmox_virtual_environment_vm.airsolid_backup: Creation complete after 5s [id=205]
proxmox_virtual_environment_vm.airsolid_erp: Creation complete after 5s [id=202]

Apply complete! Resources: 6 added, 0 changed, 0 destroyed.
```

**Durée apply : ~5 secondes. 0 erreur.**

---

## Vérification `qm list` après apply

```
      VMID NAME                 STATUS     MEM(MB)    BOOTDISK(GB) PID
       100 vyos                 stopped    512                4.00 0
       101 truenas              stopped    4096              20.00 0
       102 monitoring           stopped    1024              10.00 0
       103 pihole               stopped    512                5.00 0
       200 airsolid-fw          running    1024              20.00 90676
       201 airsolid-dc1         running    2048              40.00 90641
       202 airsolid-erp         running    2048              40.00 90703
       203 airsolid-fs          running    1024              80.00 90675
       204 airsolid-monitoring  running    2048              20.00 90650
       205 airsolid-pbs         running    2048              50.00 90699
```

**VMIDs 200–205 créés. VMIDs 100–103 (homelab) non touchés. ✅**

> Les VMs apparaissent `running` (QEMU démarré automatiquement lors de la création avec `initialization` cloud-init). Sans OS bootable, elles restent bloquées au niveau BIOS — état inoffensif pour ce test de validation.

---

## Test idempotence (re-apply)

```
No changes. Your infrastructure matches the configuration.
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

**Idempotence validée. ✅**

---

## `terraform destroy`

```
proxmox_virtual_environment_vm.airsolid_monitoring: Destroying... [id=204]
proxmox_virtual_environment_vm.airsolid_fileserver: Destroying... [id=203]
proxmox_virtual_environment_vm.airsolid_erp: Destroying... [id=202]
proxmox_virtual_environment_vm.airsolid_firewall: Destroying... [id=200]
proxmox_virtual_environment_vm.airsolid_dc1: Destroying... [id=201]
proxmox_virtual_environment_vm.airsolid_backup: Destroying... [id=205]

Destroy complete! Resources: 6 destroyed.
```

---

## Vérification `qm list` après destroy

```
      VMID NAME                 STATUS     MEM(MB)    BOOTDISK(GB) PID
       100 vyos                 stopped    512                4.00 0
       101 truenas              stopped    4096              20.00 0
       102 monitoring           stopped    1024              10.00 0
       103 pihole               stopped    512                5.00 0
```

**VMIDs 200–205 supprimés proprement. VMIDs 100–103 inchangés. ✅**

---

## Écarts vs architecture cible

| Élément | Cible | Réel homelab | Raison / Action corrective |
|---------|-------|-------------|--------------------------|
| OS DC1, ERP, FS | Windows Server 2022 | Disque vide (no OS) | Aucun template Win2022 sur PVE → acquérir licences + créer templates |
| OS OPNsense | ISO OPNsense dédiée | Disque vide (no OS) | Déposer ISO OPNsense dans `local` et configurer boot |
| OS Monitoring, PBS | Ubuntu cloud-init | Disque vide (no OS) | Télécharger `ubuntu-24.04-server-cloudimg-amd64.img` → créer template |
| Bridge WAN/DMZ | `vmbr1` | Absent | Ajouter `vmbr1` dans `/etc/network/interfaces` sur l'hôte PVE |
| VLANs 10/20/30/40 | Segments physiques séparés | Configurés dans Terraform (vlan_id) | Fonctionnels dès que OPNsense routera entre les VLANs |
| Permission SDN | Non prévue initialement | `PVESDNUser` requis sur `/sdn/zones/localnetwork` | Découverte empirique PVE 9.x → ajoutée au playbook de provisionning |

---

## Conclusion

Le cycle complet Terraform **init → plan → apply → vérification → idempotence → destroy** a été validé sur Proxmox PVE 9.2.3 avec le provider **bpg/proxmox v0.109.0**.

| Critère | Résultat |
|---------|----------|
| VMIDs 200–205 créés | ✅ |
| Idempotence (re-apply = 0 changements) | ✅ |
| Destroy propre | ✅ |
| VMs homelab 100–103 non touchées | ✅ |
| RAM totale AIRSOLID ≤ 10 Go | ✅ (10 240 Mo exactement) |

Le code Terraform est prêt à évoluer vers un déploiement avec OS réels (templates cloud-init Ubuntu + ISO OPNsense) dès que les prérequis seront disponibles sur l'hôte.
