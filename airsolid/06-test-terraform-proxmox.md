# 06 — Rapport de test Terraform / Proxmox

> Exécuté le 2026-06-15 — Proxmox VE 9.2.3 (`pve`, `192.168.1.100`) — Terraform v1.15.5 / bpg/proxmox v0.109.0

---

## Contexte

Ce document prouve l'exécution réelle du cycle Terraform complet (init → plan → apply → idempotence → destroy) sur le Proxmox de test AIRSOLID. Les VMs créées sont dans la plage VMID **200-299**, sans jamais toucher les VMs 100-103 (existantes) ni le bridge `vmbr0`.

---

## Pré-requis mis en place

### Token API Proxmox

Token créé via `pveum` sur le Proxmox host :

```
pveum user token add root@pam airsolid-tf --privsep=0
```

| Champ         | Valeur              |
|---------------|---------------------|
| full-tokenid  | `root@pam!airsolid-tf` |
| privsep       | 0 (accès complet)   |

### Bridge vmbr99 (réseau AIRSOLID isolé)

Bridge interne créé sur le Proxmox host, sans uplink vers `vmbr0` :

```bash
cat >> /etc/network/interfaces << 'EOF'

auto vmbr99
iface vmbr99 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    bridge-maxwait 0
    # AIRSOLID isolated internal bridge - no uplink
EOF
ifup vmbr99
```

Vérification :

```
19: vmbr99: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/ether be:3a:77:96:1b:5a brd ff:ff:ff:ff:ff:ff
```

---

## Étape 0 — qm list avant Terraform (baseline)

```
      VMID NAME                 STATUS     MEM(MB)    BOOTDISK(GB) PID
       100 vyos                 stopped    512                4.00 0
       101 truenas              stopped    4096              20.00 0
       102 monitoring           stopped    1024              10.00 0
       103 pihole               stopped    512                5.00 0
```

---

## Étape 1 — terraform init ✅

```
Initializing provider plugins found in the configuration...
- Finding bpg/proxmox versions matching "~> 0.69"...
- Installing bpg/proxmox v0.109.0...
- Installed bpg/proxmox v0.109.0 (self-signed, key ID F0582AD6AE97C188)

Terraform has been successfully initialized!
```

---

## Étape 2 — terraform plan ✅

```
Plan: 3 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + airsolid_ad_dc_name      = "airsolid-ad-dc"
  + airsolid_ad_dc_vmid      = 201
  + airsolid_backup_pra_name = "airsolid-backup-pra"
  + airsolid_backup_pra_vmid = 203
  + airsolid_erp_name        = "airsolid-erp"
  + airsolid_erp_vmid        = 202
```

Ressources planifiées :

| VMID | Nom                 | vCPU | RAM (MB) | Disque  | Bridge  |
|------|---------------------|------|----------|---------|---------|
| 201  | airsolid-ad-dc      | 2    | 2048     | 32 GB   | vmbr99  |
| 202  | airsolid-erp        | 2    | 4096     | 50 GB   | vmbr99  |
| 203  | airsolid-backup-pra | 2    | 2048     | 100 GB  | vmbr99  |

**RAM totale : 8 192 MB ≤ 10 240 MB** ✓

---

## Étape 3 — terraform apply -auto-approve ✅

```
proxmox_virtual_environment_vm.airsolid_erp: Creating...
proxmox_virtual_environment_vm.airsolid_ad_dc: Creating...
proxmox_virtual_environment_vm.airsolid_backup_pra: Creating...
proxmox_virtual_environment_vm.airsolid_erp: Creation complete after 1s [id=202]
proxmox_virtual_environment_vm.airsolid_backup_pra: Creation complete after 1s [id=203]
proxmox_virtual_environment_vm.airsolid_ad_dc: Creation complete after 1s [id=201]

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:
airsolid_ad_dc_name      = "airsolid-ad-dc"
airsolid_ad_dc_vmid      = 201
airsolid_backup_pra_name = "airsolid-backup-pra"
airsolid_backup_pra_vmid = 203
airsolid_erp_name        = "airsolid-erp"
airsolid_erp_vmid        = 202
```

---

## Étape 4 — qm list après apply ✅

VMs AIRSOLID (201-203) présentes — VMs 100-103 intactes :

```
      VMID NAME                 STATUS     MEM(MB)    BOOTDISK(GB) PID
       100 vyos                 stopped    512                4.00 0
       101 truenas              stopped    4096              20.00 0
       102 monitoring           stopped    1024              10.00 0
       103 pihole               stopped    512                5.00 0
       201 airsolid-ad-dc       stopped    2048              32.00 0
       202 airsolid-erp         stopped    4096              50.00 0
       203 airsolid-backup-pra  stopped    2048             100.00 0
```

---

## Étape 5 — Idempotence (re-apply) ✅

```
proxmox_virtual_environment_vm.airsolid_ad_dc: Refreshing state... [id=201]
proxmox_virtual_environment_vm.airsolid_backup_pra: Refreshing state... [id=203]
proxmox_virtual_environment_vm.airsolid_erp: Refreshing state... [id=202]

No changes. Your infrastructure matches the configuration.

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

---

## Étape 6 — terraform destroy -auto-approve ✅

```
proxmox_virtual_environment_vm.airsolid_backup_pra: Destroying... [id=203]
proxmox_virtual_environment_vm.airsolid_ad_dc: Destroying... [id=201]
proxmox_virtual_environment_vm.airsolid_erp: Destroying... [id=202]
proxmox_virtual_environment_vm.airsolid_erp: Destruction complete after 1s
proxmox_virtual_environment_vm.airsolid_backup_pra: Destruction complete after 1s
proxmox_virtual_environment_vm.airsolid_ad_dc: Destruction complete after 1s

Destroy complete! Resources: 3 destroyed.
```

---

## Étape 7 — qm list final ✅

Seules les VMs 100-103 subsistent, inchangées :

```
      VMID NAME                 STATUS     MEM(MB)    BOOTDISK(GB) PID
       100 vyos                 stopped    512                4.00 0
       101 truenas              stopped    4096              20.00 0
       102 monitoring           stopped    1024              10.00 0
       103 pihole               stopped    512                5.00 0
```

---

## Écarts et notes techniques

### VMs sans OS (bare VMs)

Les VMs ont été créées avec un disque vide (format `raw`) et `started = false`. Aucun template Windows n'étant disponible sur ce Proxmox de test, les VMs sont des coquilles vides fonctionnelles au sens Terraform/Proxmox, mais non bootables sans ISO.

**Justification** : ce choix permet de valider le cycle Terraform complet (init/plan/apply/idempotence/destroy) indépendamment de l'existence de templates. En production, les blocs `disk {}` seraient remplacés par des blocs `clone {}` pointant vers des templates Windows Server 2022 ou Debian cloud-init.

### CPU type x86-64-v2-AES

Baseline QEMU sécurisée sans fuite du CPU hôte. En production avec un cluster HA, remplacer par `kvm64` ou `host` selon la politique de live migration.

### Provider bpg/proxmox v0.109.0

La contrainte `~> 0.69` du fichier `versions.tf` a résolu vers v0.109.0 (dernière release stable). Compatible avec Proxmox VE 8.x et 9.x.

---

## Résultat global

| Étape                        | Résultat |
|------------------------------|----------|
| terraform init               | ✅ Succès |
| terraform plan               | ✅ 3 à créer |
| terraform apply -auto-approve | ✅ 3 créées |
| qm list — VMs 201-203 présentes | ✅ Confirmé |
| qm list — VMs 100-103 intactes | ✅ Confirmé |
| terraform apply (idempotence) | ✅ No changes |
| terraform destroy -auto-approve | ✅ 3 détruites |
| qm list final — 100-103 seuls | ✅ Confirmé |
