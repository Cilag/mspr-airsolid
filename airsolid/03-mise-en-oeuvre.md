# 03 — Mise en œuvre

## 3.1 Choix de l'hyperviseur : Proxmox VE

### Comparatif des options

| Critère | Proxmox VE 8.x | VMware vSphere | Hyper-V |
|---|---|---|---|
| Type | Type 1 (bare-metal) | Type 1 | Type 1 (intégré WS) |
| Coût licence | Gratuit (souscription support optionnel) | ~3 000 €/an | Inclus dans Windows Server |
| Interface administration | Web (navigateur) | vCenter (client lourd) | Windows Admin Center |
| HA intégré | Oui (Proxmox HA) | Oui (vMotion) | Oui (Hyper-V Failover Clustering) |
| Sauvegarde intégrée | PBS (open-source) | vSphere Backup APIs | Windows Server Backup |
| Communauté | Très active | VMware par Broadcom (incertitude licences) | Microsoft |
| Adapté sans IT interne | Oui (interface simple) | Non (complexité élevée) | Moyen |

**Décision : Proxmox VE 8.x** — hyperviseur type 1 basé sur Debian 12 + KVM + LXC, sans frais de licence, interface d'administration web intuitive adaptée à un prestataire externe.

---

## 3.2 Installation et configuration du cluster Proxmox

### 3.2.1 Installation sur chaque nœud

```bash
# Sur SRV1 et SRV2 : installer Proxmox VE depuis l'ISO officielle
# https://www.proxmox.com/en/downloads
# Boot ISO → installation graphique → configuration IP statique

# SRV1 : 10.0.99.11/24 (VLAN Management)
# SRV2 : 10.0.99.12/24 (VLAN Management)
```

**Partitionnement du stockage SRV1/SRV2** :

| Partition | Taille | Système de fichiers | Usage |
|---|---|---|---|
| /boot/efi | 512 MB | vfat | UEFI |
| / (root OS) | 60 GB | ext4 | Système Proxmox |
| /var/lib/pve | Reste SSD RAID-1 | ext4 | Logs, config |
| VM Storage (NVMe RAID-10) | ~3.8 TB | ZFS / LVM-thin | Images disques VMs |

### 3.2.2 Création du cluster HA

```bash
# Sur SRV1 (nœud initial) :
pvecm create airsolid-cluster

# Sur SRV2 (rejoindre le cluster) :
pvecm add 10.0.99.11

# Vérification :
pvecm status
# Expected: Quorum information — Nodes: 2
```

**Réseau de cluster** : lien dédié 10 GbE direct entre SRV1 et SRV2 (corosync cluster communication), distinct du réseau de production.

### 3.2.3 Configuration du stockage partagé

```bash
# ZFS RAID-10 sur NVMe (à effectuer sur chaque nœud) :
zpool create -f vm-data raidz nvme0n1 nvme1n1 nvme2n1 nvme3n1

# Ajout du stockage dans Proxmox :
# Interface Web → Datacenter → Storage → Add → ZFS
# ID: vm-data, Pool: vm-data
```

---

## 3.3 Configuration réseau (VLANs et bridges Proxmox)

### 3.3.1 Configuration du switch manageable

| Port | VLAN natif | VLANs taggés | Équipement |
|---|---|---|---|
| 1-2 | 99 | 10, 20, 30 | SRV1 (uplink trunk) |
| 3-4 | 99 | 10, 20, 30 | SRV2 (uplink trunk) |
| 5-6 | — | — | Pare-feu Sophos (trunk) |
| 7-20 | 20 | — | Postes utilisateurs |
| 21-24 | 30 | — | Postes Atelier |

### 3.3.2 Bridges Proxmox (fichier `/etc/network/interfaces` sur SRV1)

```
# Interface physique (trunk VLAN)
auto eno1
iface eno1 inet manual

# Bridge principal avec support VLAN
auto vmbr0
iface vmbr0 inet manual
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094

# Interface Admin (VLAN 99)
auto vmbr0.99
iface vmbr0.99 inet static
    address 10.0.99.11/24
    gateway 10.0.99.1
```

Les VMs sont attachées à `vmbr0` avec leur VLAN respectif configuré dans Proxmox (ex: VM-AD → VLAN 10).

### 3.3.3 Pare-feu Sophos

Interfaces Sophos :
- `WAN` — IP publique FAI (interface vers internet)
- `VLAN10` (Serveurs) — 10.0.10.1/24
- `VLAN20` (Utilisateurs) — 10.0.20.1/24
- `VLAN30` (SAV) — 10.0.30.1/24
- `VLAN99` (Management) — 10.0.99.1/24

Règles de filtrage principales :

| Source | Destination | Service | Action | Justification |
|---|---|---|---|---|
| VLAN20 | VLAN10 | TCP 443 (HTTPS ERP) | ALLOW | Accès ERP Utilisateurs |
| VLAN20 | VLAN10 | TCP 445, 139 (SMB) | ALLOW | Partages fichiers |
| VLAN20 | VLAN10 | TCP 389, 636 (LDAP/S) | ALLOW | Authentification AD |
| VLAN30 | VLAN10 | TCP 443, 445, 389 | ALLOW | Atelier SAV même accès |
| VLAN20 | VLAN30 | Any | DENY | Isolation Utilisateurs/atelier |
| Any | VLAN99 | Any | DENY | Sauf IP whitelist prestataire |
| VLAN10 | Internet | TCP 443, 22 | ALLOW | Azure Backup, mises à jour |
| Any | Internet | TCP 443 | ALLOW | Navigation web contrôlée |

---

## 3.4 Déploiement des machines virtuelles

### 3.4.1 VM-AD — Active Directory

```
Proxmox → Create VM
  Name: VM-AD
  OS: Windows Server 2022 STD (ISO montée depuis NFS/local)
  CPU: 2 vCPUs (type: host)
  RAM: 4096 MB (balloon: désactivé)
  Disk: 80 GB (ZFS vm-data, cache: writeback)
  Network: vmbr0, VLAN 10
```

**Unités d'organisation (OU) à créer** :

```
airsolid.local
├── OU=Serveurs
│   ├── SRV-AD01, SRV-AD02
│   ├── SRV-ERP01
│   └── SRV-FILE01
├── OU=Utilisateurs
│   ├── OU=Direction
│   ├── OU=Commercial
│   ├── OU=Administration
│   └── OU=SAV
├── OU=Postes
│   ├── OU=Utilisateurs
│   └── OU=Atelier
└── OU=ServiceAccounts
```

### 3.4.2 VM-AD-REP — Contrôleur de domaine secondaire

Déployé sur SRV2, même configuration que VM-AD mais promu en **DC supplémentaire** (pas de forest, réplication SYSVOL/NETLOGON automatique via DFS-R).

### 3.4.3 VM-ERP — Serveur d'application ERP

#### Install ODOO : 

### 3.4.4 VM-FILE — Serveur de fichiers

#### Structure de sauvegarde : 

### 3.4.5 VM-MON — Supervision

```bash
# Installation Netdata (agent de métriques temps réel)
wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh
sh /tmp/netdata-kickstart.sh --non-interactive

# Installation Grafana
apt-get install -y grafana
systemctl enable --now grafana-server

# Alertmanager (email / Teams webhook)
# Configuration dans /etc/netdata/health_alarm_notify.conf
# → Alertes email + Microsoft Teams webhook
```

Services supervisés :
- État des VMs Proxmox (CPU, RAM, I/O disque)
- Disponibilité services AD (LDAP, DNS, SYSVOL)
- Disponibilité ERP (port 443, temps de réponse HTTP)
- Espace disque VM-FILE (alerte à 80 %)
- État sauvegardes PBS (succès/échec nightly)
- Connectivité internet (ping 8.8.8.8 toutes les 60 s)

---

## 3.5 Configuration VPN Sophos intégré (nomades)

L'entretien 1 a confirmé **30 collaborateurs en télétravail** nécessitant un accès VPN.

Les commerciaux nomades accèdent à l'ERP et aux fichiers via le VPN comme s'ils étaient sur place, avec authentification AD intacte.

---

## 3.6 Plan de migration depuis l'existant

| Phase | Durée | Actions | Risque |
|---|---|---|---|
| **Phase 0 — Préparation** | 1 semaine | Achat serveurs, câblage réseau, switch, pare-feu | Faible |
| **Phase 1 — Infrastructure** | 2 semaines | Installation Proxmox, création VMs vides, réseau VLAN | Faible |
| **Phase 2 — AD Migration** | 3 jours | Nouveau DC VM-AD (domaine existant), FSMO transfer, retrait ancien DC | Moyen |
| **Phase 3 — ERP Migration** | 1 semaine | Migration ERP vers VM-ERP (en parallèle), tests, bascule DNS | Élevé |
| **Phase 4 — Fichiers** | 2 jours | Robocopy partages anciens → VM-FILE, cutover weekend | Faible |
| **Phase 5 — Finalisation** | 1 semaine | PBS, VPN, supervision, formation prestataire | Faible |

**Durée totale estimée** : 5 à 6 semaines (interventions hors heures ouvrées pour les phases critiques)

**Rollback** : l'ancien serveur reste opérationnel en parallèle jusqu'à la validation complète de la Phase 5.

---

## 3.7 Continuité d'activité — UPS existant

Le client dispose déjà d'une **alimentation secourue (UPS)** en place. Ce point est positif pour le plan de continuité :
- L'UPS existant doit être audité (autonomie, état des batteries) avant la migration
- Il protège le matériel existant pendant la phase de transition
- Dans l'architecture cible, les deux serveurs Proxmox doivent être raccordés à l'UPS (ou à deux UPS distincts pour redondance)
- Recommandation : UPS avec supervision SNMP (compatible avec VM-MON / Netdata)
