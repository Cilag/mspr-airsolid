# 02 — Architecture proposée

## 2.1 Principes directeurs

L'architecture retenue repose sur cinq axes :

1. **Élimination du SPOF** — deux serveurs physiques avec réplication automatique des VMs
2. **Virtualisation type 1** — Proxmox VE sur bare-metal, isolation des services en VMs dédiées
3. **Hybride maîtrisé** — Active Directory on-premise, messagerie et collaboration via Microsoft 365
4. **Défense en profondeur** — segmentation VLAN, pare-feu, VPN modernes, sauvegardes hors site
5. **Budget maîtrisé** — options économiques priorisées (Proxmox open-source, réutilisation du matériel existant si possible) ; 2 à 3 devis comparatifs à présenter

---

## 2.2 Vue d'ensemble de l'architecture cible

```mermaid
flowchart TD
    subgraph SITE["Site Principal — AIRSOLID"]
        subgraph SRV1["Serveur Primaire — Proxmox VE 8.x"]
            VM_AD["VM-AD\nWindows Server 2022\nAD DS + DNS + DHCP"]
            VM_ERP["VM-ERP\nWindows Server 2022\nERP Web + IIS"]
            VM_FILE["VM-FILE\nWindows Server 2022\nPartages SMB + DFS"]
            VM_MON["VM-MON\nDebian 12\nNetdata + Grafana + AlertMgr"]
        end
        subgraph SRV2["Serveur Secondaire — Proxmox VE 8.x"]
            VM_PBS["PBS\nProxmox Backup Server\nSauvegardes locales"]
            VM_AD2["VM-AD-REP\nWindows Server 2022\nAD DS Replica"]
        end
        SW["Switch manageable L2/L3\nVLAN 10 / 20 / 30 / 99"]
        FW["Pare-feu OPNsense\nNAT + filtrage + IDS"]
    end

    subgraph CLOUD["Services Cloud"]
        M365["Microsoft 365\nEmail + Teams + SharePoint"]
        AZ_BKP["Azure Backup\nSauvegarde hors site"]
        AAD["Entra ID\nSSO + MFA"]
    end

    subgraph USERS["Postes utilisateurs"]
        BUREAU["Postes Bureau\nVLAN 20 — 10.0.20.0/24"]
        SAV["Postes Atelier SAV\nVLAN 30 — 10.0.30.0/24"]
        NOMADES["Commerciaux Nomades\nVPN WireGuard"]
    end

    SRV1 <-->|"Réplication Proxmox\n+ Sauvegarde PBS"| SRV2
    SRV1 --> SW
    SRV2 --> SW
    SW --> FW
    FW -->|"HTTPS / VPN"| CLOUD
    BUREAU --> SW
    SAV --> SW
    NOMADES -->|"WireGuard UDP 51820"| FW
    VM_AD -->|"Azure AD Connect"| AAD
    VM_PBS -->|"Azure Backup Agent"| AZ_BKP
    AAD --> M365
```

---

## 2.3 Composants de l'architecture

### 2.3.1 Couche physique — deux serveurs

| Paramètre | Serveur Primaire (SRV1) | Serveur Secondaire (SRV2) |
|---|---|---|
| **Modèle recommandé** | Dell PowerEdge R550 (ou HP DL380 Gen10+) | Idem |
| **Processeur** | 2x Intel Xeon Silver 4410Y (12c/24t) | 2x Intel Xeon Silver 4410Y |
| **RAM** | 128 GB DDR4 ECC | 128 GB DDR4 ECC |
| **Stockage OS** | 2x 480 GB SSD SATA (RAID 1) | 2x 480 GB SSD SATA (RAID 1) |
| **Stockage VMs** | 4x 1.92 TB NVMe (RAID 10 = 3.84 TB utile) | 4x 1.92 TB NVMe (RAID 10) |
| **Réseau** | 2x 10 GbE SFP+ + 2x 1 GbE | Idem |
| **Alimentation** | Dual PSU redondant | Dual PSU redondant |
| **Hyperviseur** | Proxmox VE 8.x | Proxmox VE 8.x |

> Les deux serveurs forment un **cluster Proxmox VE** en mode HA (High Availability). En cas de panne du nœud primaire, les VMs basculent automatiquement sur le secondaire en moins de 5 minutes.

> **Option budget contraint** : si le serveur existant (10 TB, 15+ ans) est encore fonctionnel après audit, il peut être utilisé comme nœud secondaire (PBS / réplication) en attendant son remplacement, permettant de réduire le CAPEX initial. Audit préalable obligatoire (SMART, benchmarks, alimentation).

### 2.3.2 Machines virtuelles

| VM | OS | vCPU | RAM | Stockage | Rôle |
|---|---|---|---|---|---|
| **VM-AD** | Windows Server 2022 STD | 2 | 4 GB | 80 GB | AD DS, DNS, DHCP |
| **VM-ERP** | Windows Server 2022 STD | 8 | 16 GB | 200 GB | ERP Web (IIS/SQL) |
| **VM-FILE** | Windows Server 2022 STD | 4 | 8 GB | 2 TB | Partages SMB, DFS |
| **VM-MON** | Debian 12 | 2 | 4 GB | 100 GB | Supervision (Netdata, Grafana) |
| **VM-AD-REP** | Windows Server 2022 STD | 2 | 4 GB | 80 GB | Contrôleur AD secondaire |
| **PBS** | Proxmox Backup Server | 4 | 8 GB | 4 TB | Sauvegarde locale des VMs |

**Total ressources SRV1** : 16 vCPU / 32 GB RAM alloués (capacité physique : 48 cœurs / 128 GB)
**Réserve disponible** : ~66 % CPU et 75 % RAM → marge pour l'entrepôt secondaire

### 2.3.3 Réseau — segmentation VLAN

```mermaid
flowchart LR
    subgraph VLANS["Segmentation VLAN"]
        V10["VLAN 10\n10.0.10.0/24\nServeurs"]
        V20["VLAN 20\n10.0.20.0/24\nBureau"]
        V30["VLAN 30\n10.0.30.0/24\nAtelier SAV"]
        V99["VLAN 99\n10.0.99.0/24\nManagement Proxmox"]
    end

    FW["OPNsense\nRoutage inter-VLAN\n+ Règles de filtrage"]

    V10 <-->|"Accès contrôlé\nPort TCP 443 ERP\nPort TCP 445 SMB"| FW
    V20 <-->|"Accès ERP + Fichiers\nBloqué vers VLAN 30"| FW
    V30 <-->|"Accès ERP + Fichiers\nBloqué vers VLAN 20"| FW
    V99 <-->|"SSH / HTTPS Proxmox\nIP whitelist"| FW
```

| VLAN | Réseau | Population | Accès autorisés |
|---|---|---|---|
| **VLAN 10** | 10.0.10.0/24 | Serveurs virtuels (VMs) | Toutes VMs entre elles |
| **VLAN 20** | 10.0.20.0/24 | Postes bureautique | ERP (443), Fichiers (445/139), AD (389/636) |
| **VLAN 30** | 10.0.30.0/24 | Atelier SAV | ERP (443), Fichiers (445/139), AD — isolé de VLAN 20 |
| **VLAN 99** | 10.0.99.0/24 | Management Proxmox | SSH (22), HTTPS Proxmox (8006) — IP whitelist uniquement |

> **VPN pour 30 télétravailleurs** : 30 collaborateurs en télétravail ont été identifiés lors de l'entretien 1. Le VPN WireGuard est dimensionné pour accueillir ces 30 utilisateurs simultanés. Chaque pair dispose d'un certificat et d'un fichier de configuration individuels générés par le script de provisioning.

### 2.3.4 Flux EDI

Le client n'a pas de flux EDI existants définis. La proposition ci-dessous constitue une **architecture EDI de départ légère**, à valider avec l'éditeur ERP et les partenaires logistiques.

```mermaid
sequenceDiagram
    participant ERP as VM-ERP (AIRSOLID)
    participant FW as Pare-feu OPNsense
    participant EDI as Partenaire EDI / VAN
    participant FOURNISSEUR as Fournisseur / Transporteur

    ERP->>FW: Fichier EDI (EDIFACT/XML) via SFTP ou AS2
    FW->>EDI: Transfert chiffré TLS 1.3 (port 443 ou 22)
    EDI->>FOURNISSEUR: Routage EDI normalisé
    FOURNISSEUR-->>EDI: Accusé de réception (997/CONTRL)
    EDI-->>FW: Réponse chiffrée
    FW-->>ERP: Confirmation réception
```

Les flux EDI transitent exclusivement via le pare-feu avec :
- Certificats TLS valides (Let's Encrypt ou PKI interne)
- Port source fixe et destination IP allowlistée
- Journalisation des échanges dans VM-MON

---

## 2.4 Architecture hybride on-premise / cloud

```mermaid
flowchart LR
    subgraph ONPREM["On-Premise AIRSOLID"]
        AD["VM-AD\nActive Directory\n(Source d'autorité)"]
        ERP["VM-ERP\nERP Web\n(On-prem)"]
        FILE["VM-FILE\nPartages SMB\n(On-prem)"]
        PBS_LOCAL["PBS\nSauvegarde locale\n(Site)"]
    end

    subgraph AZURE["Microsoft Azure / M365"]
        ENTRA["Entra ID\n(Azure AD)\nSynchronisation"]
        M365_SVC["Microsoft 365\nEmail + Teams + OneDrive"]
        AZ_BACKUP["Azure Backup\nVault hors site"]
    end

    AD -->|"Azure AD Connect\nSync toutes les 30 min"| ENTRA
    ENTRA --> M365_SVC
    PBS_LOCAL -->|"Agent Azure Backup\nCopie nightly chiffrée"| AZ_BACKUP
    FILE -.->|"OneDrive Sync\n(optionnel pour nomades)"| M365_SVC
```

### Répartition des services

| Service | Hébergement | Justification |
|---|---|---|
| Active Directory | On-premise (VM-AD + VM-AD-REP) | Dépendance critique des postes ; latence faible requise |
| ERP web | On-premise (VM-ERP) | Spécificités métier, données sensibles, éditeur à consulter |
| Partages fichiers | On-premise (VM-FILE) | Volumes importants, accès rapide réseau local |
| Messagerie | Microsoft 365 (cloud) | Déjà en déploiement, délestage du serveur on-prem |
| Collaboration | Microsoft 365 (cloud) | Teams, SharePoint, Planner |
| Sauvegarde hors site | Azure Backup | Externalisation géographique, conformité RGPD |
| Identité cloud | Entra ID (synchronisé) | SSO unifié on-prem + cloud, MFA imposé |

---

## 2.5 Stratégie de sauvegarde 3-2-1

```mermaid
flowchart TD
    VMS["VMs en production\n(SRV1)"]
    PBS["Proxmox Backup Server\n(SRV2 — sur site)\nCopie 1 — Locale"]
    AZURE["Azure Backup Vault\n(Région France Central)\nCopie 2 — Hors site"]
    TAPE["NAS portable / HDD externe\n(Stockage hors site mensuel)\nCopie 3 — Offline"]

    VMS -->|"Sauvegarde incrémentale\nnightly 23h00"| PBS
    PBS -->|"Réplication Azure Backup\n2x/semaine"| AZURE
    PBS -->|"Export mensuel manuel\n(rotation HDD)"| TAPE
```

| Type | Fréquence | Rétention | Support |
|---|---|---|---|
| Sauvegarde incrémentale | Quotidienne (23h00) | 30 jours | PBS local (SRV2) |
| Sauvegarde hebdomadaire | Dimanche 01h00 | 12 semaines | PBS local |
| Sauvegarde mensuelle | 1er du mois | 12 mois | Azure Backup + HDD externe |
| Test de restauration | Mensuel | — | Environnement de test isolé |

---

## 2.6 Évolutivité — Site secondaire (12 mois)

L'architecture est conçue pour absorber le second dépôt prévu dans 12 mois :
- Extension du cluster Proxmox avec un 3e nœud sur le site secondaire (WAN link 1 Gb requis)
- Réplication PBS inter-sites pour les VMs critiques
- Extension du VPN site-à-site (WireGuard) entre les deux dépôts
- Active Directory Sites and Services configuré pour routing LDAP optimal

> **Extension Allemagne (site secondaire)** : la présence de collaborateurs en Allemagne nécessitera, à terme, soit un VPN site-à-site permanent (WireGuard inter-sites), soit un nœud Proxmox délocalisé sur le site allemand répliquant les VMs critiques. Cette évolution est intégrée dans la feuille de route à 12-24 mois.
