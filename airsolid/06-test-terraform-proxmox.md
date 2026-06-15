# 06 — Test Terraform + Proxmox

**Date :** 2026-06-15  
**Opérateur :** Infra Lead (GUI-203)  
**Hôte PVE :** 192.168.1.100 (Proxmox VE 9.2.3)  
**Provider Terraform :** bpg/proxmox v0.109.0  

---

## Environnement de test

| Paramètre | Valeur |
|-----------|--------|
| Hôte Proxmox | 192.168.1.100 |
| Version PVE | 9.2.3 |
| RAM hôte | 16 Go |
| RAM libre (VMs homelab arrêtées) | ~14 Go |
| Stockage images | local (ISO, backup) |
| Stockage disques VM | local-lvm (LVM thin) |
| Bridge réseau | vmbr0 (LAN, 192.168.1.100/24) |
| Terraform | >= 1.5 (bpg/proxmox v0.109.0) |

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

**Templates VM cloud-init :** aucun — pas de template Ubuntu/Windows disponible.

---

## Token API créé

```bash
pveum user add terraform@pve
pveum aclmod / -user terraform@pve -role PVEVMAdmin
pveum aclmod /storage/local-lvm -user terraform@pve -role PVEDatastoreAdmin
pveum aclmod /storage/local -user terraform@pve -role PVEDatastoreAdmin
pveum aclmod /sdn/zones/localnetwork -user terraform@pve -role PVESDNUser
pveum user token add terraform@pve mytoken --privsep=0
```

**Token ID :** `terraform@pve!mytoken`  
**Permissions effectives :**

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

> Note : `PVESDNUser` (SDN.Use sur `/sdn/zones/localnetwork`) est requis par PVE 9.x pour attacher une interface réseau à un bridge. Non documenté dans les guides courants, découvert empiriquement.

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
data.proxmox_virtual_environment_nodes.pve: Reading...
data.proxmox_virtual_environment_nodes.pve: Read complete after 0s [id=nodes]

Terraform will perform the following actions:

  # proxmox_virtual_environment_vm.airsolid["dc1"] will be created
  # proxmox_virtual_environment_vm.airsolid["erp_web"] will be created
  # proxmox_virtual_environment_vm.airsolid["fs"] will be created
  # proxmox_virtual_environment_vm.airsolid["monitoring"] will be created
  # proxmox_virtual_environment_vm.airsolid["opnsense"] will be created
  # proxmox_virtual_environment_vm.airsolid["pbs"] will be created

Plan: 6 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + airsolid_vm_ids = {
      + dc1        = 201
      + erp_web    = 202
      + fs         = 203
      + monitoring = 204
      + opnsense   = 200
      + pbs        = 205
    }
```

**Résultat plan : 0 erreur, 6 ressources à créer.**

---

## `terraform apply` (sortie complète)

```
proxmox_virtual_environment_vm.airsolid["pbs"]: Creating...
proxmox_virtual_environment_vm.airsolid["erp_web"]: Creating...
proxmox_virtual_environment_vm.airsolid["dc1"]: Creating...
proxmox_virtual_environment_vm.airsolid["monitoring"]: Creating...
proxmox_virtual_environment_vm.airsolid["opnsense"]: Creating...
proxmox_virtual_environment_vm.airsolid["fs"]: Creating...
proxmox_virtual_environment_vm.airsolid["dc1"]: Creation complete after 1s [id=201]
proxmox_virtual_environment_vm.airsolid["fs"]: Creation complete after 1s [id=203]
proxmox_virtual_environment_vm.airsolid["pbs"]: Creation complete after 1s [id=205]
proxmox_virtual_environment_vm.airsolid["erp_web"]: Creation complete after 1s [id=202]
proxmox_virtual_environment_vm.airsolid["monitoring"]: Creation complete after 1s [id=204]
proxmox_virtual_environment_vm.airsolid["opnsense"]: Creation complete after 2s [id=200]

Apply complete! Resources: 6 added, 0 changed, 0 destroyed.
```

**Durée totale apply : ~2 secondes. 0 erreur.**

---

## Vérification `qm list` après apply

```
      VMID NAME                 STATUS     MEM(MB)    BOOTDISK(GB) PID
       100 vyos                 stopped    512                4.00 0
       101 truenas              stopped    4096              20.00 0
       102 monitoring           stopped    1024              10.00 0
       103 pihole               stopped    512                5.00 0
       200 airsolid-firewall    stopped    1024              20.00 0
       201 airsolid-dc1         stopped    2048              40.00 0
       202 airsolid-erp-web     stopped    2048              40.00 0
       203 airsolid-fs          stopped    1024              80.00 0
       204 airsolid-monitoring  stopped    2048              20.00 0
       205 airsolid-pbs         stopped    2048              50.00 0
```

**VMIDs 200–205 créés. VMIDs 100–103 (homelab) non touchés. ✅**

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
proxmox_virtual_environment_vm.airsolid["opnsense"]: Destroying... [id=200]
proxmox_virtual_environment_vm.airsolid["erp_web"]: Destroying... [id=202]
proxmox_virtual_environment_vm.airsolid["dc1"]: Destroying... [id=201]
proxmox_virtual_environment_vm.airsolid["pbs"]: Destroying... [id=205]
proxmox_virtual_environment_vm.airsolid["fs"]: Destroying... [id=203]
proxmox_virtual_environment_vm.airsolid["monitoring"]: Destroying... [id=204]

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

| Élément | Cible | Réel | Raison |
|---------|-------|------|--------|
| OS DC1, ERP-Web, FS | Windows Server 2022 | Disque vide (`started=false`) | Aucun template Win2022 sur PVE |
| OS OPNsense | ISO OPNsense | Disque vide (`started=false`) | Pas de template OPNsense cloud-init |
| OS Monitoring, PBS | Ubuntu cloud-init | Disque vide (`started=false`) | Aucun template cloud-init sur PVE |
| Bridge WAN/DMZ | vmbr1 | Absent | Non configuré sur hôte homelab |
| VLANs 10/20/30/40 | Segments séparés | Non implémentés en HW | Attendus via OPNsense interne |
| Permission SDN | Non documentée | `PVESDNUser` requis | PVE 9.x impose SDN.Use sur les bridges |

**Actions correctrices pour mise en prod :**
1. Télécharger template Ubuntu cloud-init sur PVE : `qm create 9000 --cdrom local:iso/ubuntu-24.04-server-cloudimg-amd64.img --name ubuntu-2404-cloud`
2. Créer vmbr1 dans `/etc/network/interfaces` (WAN/DMZ)
3. Acquérir licences Windows Server 2022 + créer templates

---

## Conclusion

Le cycle complet Terraform **init → plan → apply → vérification → idempotence → destroy** a été validé en environnement réel sur Proxmox PVE 9.2.3.

- **6 VMs créées** (VMIDs 200–205, nomenclature AIRSOLID)
- **Idempotence confirmée** (0 changement au re-apply)
- **Destroy propre** (aucun artefact résiduel)
- **Homelab préservé** (VMs 100–103 intactes)
- **Provider bpg/proxmox** opérationnel, version 0.109.0

Le code Terraform est prêt pour déploiement avec templates OS réels. Les écarts sont documentés et ne bloquent pas la démonstration d'architecture.
