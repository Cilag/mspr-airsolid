# 04 — Objectifs pédagogiques

> Ce document décline les 8 objectifs officiels du MSPR Virtualisation, appliqués concrètement au cas AIRSOLID.

---

## Objectif 1 — Proxmox — hyperviseur type 1 adapté au besoin

### Pourquoi Proxmox VE pour AIRSOLID ?

Proxmox VE est un hyperviseur de **type 1** (bare-metal) basé sur Debian Linux avec KVM comme moteur de virtualisation. Il s'installe directement sur le matériel sans OS hôte intermédiaire, ce qui garantit des performances optimales et une isolation robuste entre les VMs.

### Adéquation au besoin AIRSOLID

| Critère AIRSOLID | Réponse Proxmox VE |
|---|---|
| Aucune équipe IT interne | Interface d'administration web (port 8006), intuitive pour un prestataire externe |
| Budget contraint | Licence AGPL-3.0 — gratuit en production ; support commercial optionnel (180 €/an/nœud) |
| Continuité de service | Cluster HA natif sur 2 nœuds : bascule automatique en < 5 min en cas de panne nœud |
| Sauvegarde intégrée | Proxmox Backup Server (PBS) — sauvegardes incrémentielles déduplicatées sans coût |
| Évolutivité | Ajout d'un 3e nœud pour le site secondaire sans réinstallation |

### Comparaison avec XCP-ng

XCP-ng (fork de XenServer, maintenu par Vates) est une alternative valide de type 1 :
- Hyperviseur Xen vs KVM pour Proxmox — les deux sont matures et performants
- XCP-ng dispose de Xen Orchestra (XO) pour l'administration, open-source
- **Proxmox est retenu ici** car l'écosystème PBS + HA est plus intégré et la base installée en PME est plus large en France

### Lien avec le cours

Ce cas illustre le choix d'un hyperviseur en fonction des contraintes organisationnelles (absence d'IT), budgétaires (open-source), et techniques (HA sur 2 nœuds minimum).

---

## Objectif 2 — Ressources & sécurité — dimensionnement, isolation, accès, tiers

### Dimensionnement des ressources

Le dimensionnement est basé sur l'analyse de la charge actuelle (~80 utilisateurs) avec une marge de croissance de 30 % :

| VM | vCPU alloués | RAM allouée | Stockage | Justification |
|---|---|---|---|---|
| VM-AD | 2 | 4 GB | 80 GB | AD léger, charge < 5 % hors pointe |
| VM-ERP | 8 | 16 GB | 200 GB | Pic de charge matin et clôture de journée |
| VM-FILE | 4 | 8 GB | 2 TB | I/O intensif lors des exports comptables |
| VM-MON | 2 | 4 GB | 100 GB | Supervision continue, données 90 jours |
| VM-AD-REP | 2 | 4 GB | 80 GB | Réplication AD, réserve en cas de panne VM-AD |
| PBS | 4 | 8 GB | 4 TB | Stockage déduplicaté, calcul de delta |

**Ratio de surcharge** (overcommit) : 1:1.5 pour CPU et 1:1.2 pour RAM — raisonnable pour des VMs Windows dont les pics ne sont pas simultanés.

### Isolation et sécurité des VMs

- **Isolation réseau** : chaque VM est sur son propre VLAN (VLAN 10 serveurs) — pas de communication inter-VM sans passer par le pare-feu OPNsense
- **Isolation stockage** : chaque VM sur son propre volume ZFS — pas de partage de blocs entre VMs
- **ACLs Proxmox** : rôles définis par principe de moindre privilège :
  - `PVEAdmin` : prestataire principal (accès complet)
  - `PVEAudit` : responsable AIRSOLID (lecture seule, monitoring)
  - `PVEVMUser` : opérations limitées (démarrage/arrêt) pour astreinte

### Niveaux de service (tiers)

| Tier | VMs concernées | Disponibilité cible | Protection |
|---|---|---|---|
| Critique (Tier 1) | VM-AD, VM-ERP | 99,9 % (~8h d'interruption/an) | HA Proxmox + DC secondaire |
| Important (Tier 2) | VM-FILE, VM-AD-REP | 99,5 % | Réplication PBS quotidienne |
| Standard (Tier 3) | VM-MON, PBS | 99 % | Backup hebdomadaire |

---

## Objectif 3 — Hybride on-prem / cloud — local / SaaS / hébergement externe

### Stratégie hybride AIRSOLID

AIRSOLID est déjà engagé dans une démarche cloud (déploiement M365 en cours). L'architecture retenue adopte une position **hybride pragmatique** :

| Couche | Solution | Hébergement | Raison |
|---|---|---|---|
| Identité | Active Directory + Entra ID (sync) | On-prem + Cloud | AD source d'autorité, Entra pour SSO cloud |
| Messagerie | Microsoft 365 Exchange Online | Cloud (SaaS) | Délestage on-prem, disponibilité 99,9 % garantie Microsoft |
| Collaboration | Teams + SharePoint | Cloud (SaaS) | Nomades, accès partout sans VPN |
| ERP | Application on-premise | On-prem | Contraintes éditeur, données sensibles, performances |
| Fichiers métier | Windows SMB + DFS | On-prem | Volumes > 1 TB, accès réseau local LAN |
| Sauvegarde | PBS (local) + Azure Backup | Hybride | Règle 3-2-1 : local rapide, cloud hors site |
| Accès nomade | WireGuard VPN | On-prem (OPNsense) | Accès ERP et fichiers sans dépendance cloud |

### Azure AD Connect — synchronisation des identités

```
On-premise AD ──[Azure AD Connect]──► Entra ID ──► M365
      │                                    │
  Comptes AD                          SSO + MFA
  Mots de passe                       (Authenticator)
  Groupes                             Accès Teams/SharePoint
```

La synchronisation se fait toutes les 30 minutes. En cas de panne internet, l'AD local reste opérationnel — les utilisateurs continuent à se connecter et à accéder aux ressources on-prem.

### Positionnement pour le site secondaire (12 mois)

L'ouverture du dépôt secondaire n'imposera pas de nouvel hébergement cloud : extension du cluster Proxmox + VPN site-à-site suffit pour un démarrage. Une révision en mode « cloud-first » pourra être envisagée à 3 ans selon la maturité digitale d'AIRSOLID.

---

## Objectif 4 — Supervision — suivi des VMs / services critiques

### Architecture de supervision

La supervision repose sur VM-MON (Debian 12) hébergeant :

```
Netdata Agent (sur chaque VM)
        │
        ▼
Netdata Cloud / Prometheus scrape
        │
        ▼
Grafana (dashboards) + Alertmanager
        │
        ▼
Email (DSI prestataire) + Teams webhook
```

### Métriques surveillées

| Objet surveillé | Métriques clés | Seuil alerte | Seuil critique |
|---|---|---|---|
| Nœuds Proxmox (SRV1/2) | CPU, RAM, I/O disque, réseau | 75 % | 90 % |
| VM-AD | LDAP query time, SYSVOL sync, DC replication | > 500 ms | Service arrêté |
| VM-ERP | HTTP response time (port 443), CPU, RAM | > 2 s | > 5 s ou HTTP 5xx |
| VM-FILE | Espace disque, IOPS, sessions SMB actives | 80 % disque | 95 % disque |
| PBS | Dernier backup (timestamp), taux déduplication | > 26h sans backup | Job en échec |
| OPNsense | Bande passante WAN, état tunnels WireGuard, paquets bloqués | 80 % bande passante | Tunnel down |
| Services critiques | Ping ICMP + port check (AD:389, ERP:443, FILE:445) | Timeout 1 cycle | 3 cycles consécutifs |

### Alertes et astreinte

- **Heures ouvrées (L-V 8h-18h)** : alerte Teams + email prestataire, SLA < 4h
- **Hors heures ouvrées** : alerte email prestataire, PagerDuty / SMS si criticité haute
- **Tableau de bord** : accessible depuis l'interface Grafana (accessible en HTTPS via reverse proxy sur pare-feu, authentification AD)

---

## Objectif 5 — Sauvegardes & PRA — stratégie, tests de restauration

### Politique de sauvegarde (règle 3-2-1)

> **3** copies des données · **2** supports différents · **1** copie hors site

| Copie | Emplacement | Technologie | Fréquence | Rétention |
|---|---|---|---|---|
| **Copie 1** (production) | SRV1 — stockage VM | ZFS (instantané) | Temps réel | Production |
| **Copie 2** (locale) | SRV2 — PBS | Proxmox Backup Server | Nightly 23h00 | 30 jours |
| **Copie 3** (hors site) | Azure Backup Vault | Agent Azure Backup | 2x/semaine | 12 mois |

### RTO / RPO cibles

| Scénario | RTO cible | RPO cible |
|---|---|---|
| Panne d'une VM (corruption logicielle) | < 30 min | < 24 h (dernier backup) |
| Panne d'un nœud Proxmox complet | < 5 min | 0 (HA Proxmox bascule les VMs) |
| Panne des 2 nœuds (catastrophe site) | < 4 h | < 48 h (restauration Azure) |
| Ransomware (chiffrement données) | < 4 h | < 24 h (backup immuable Azure) |
| Incendie / sinistre total | < 8 h | < 48 h (Azure Backup + nouveau matériel) |

### Plan de tests de restauration

| Test | Fréquence | Procédure | Critère de succès |
|---|---|---|---|
| Restauration VM de test (PBS) | Mensuel | Cloner VM depuis PBS dans env. isolé Proxmox | VM démarre, données cohérentes |
| Vérification Azure Backup | Mensuel | Restauration d'un fichier unique depuis le portail Azure | Fichier récupéré en < 30 min |
| Test de bascule HA | Trimestriel | Éteindre SRV1, vérifier migration VMs sur SRV2 | VMs opérationnelles en < 5 min |
| Simulation PRA complet | Annuel | Restauration complète sur matériel de test depuis Azure | ERP fonctionnel en < 4 h |

### Immutabilité des sauvegardes (anti-ransomware)

- PBS : option de verrouillage des backups (immutable backup)
- Azure Backup : vault avec protection contre la suppression (soft-delete 14 jours + immutability policy)
- Les backups ne sont jamais accessibles directement depuis les VMs de production (réseau séparé PBS)

---

## Objectif 6 — VDI & profils — accès distant / postes centralisés si pertinent

### Analyse du besoin VDI chez AIRSOLID

Une infrastructure VDI complète (Citrix, VMware Horizon, Proxmox VE VDI) est **disproportionnée** pour AIRSOLID à ce stade :

| Population | Taille | Mobilité | Solution retenue |
|---|---|---|---|
| Commerciaux nomades | ~15 | Forte | VPN WireGuard + profils AD itinérants |
| Postes bureau | ~55 | Faible | Postes fixes joints au domaine, profils locaux |
| Techniciens SAV | ~10 | Moyenne (atelier) | Postes fixes VLAN 30, profils locaux |

### Solution retenue : profils itinérants Windows + VPN

**Profils itinérants (Roaming Profiles)** via Group Policy sur VM-FILE :

```
GPO → Profils utilisateurs
  → Chemin : \\SRV-FILE01\Profiles\%username%
  → Redirection de dossiers : Bureau, Documents, AppData\Roaming
```

**Avantages** : mise en œuvre simple, pas de nouvelle infrastructure, compatible avec le parc existant.

### Scénario VDI futur (entretien 2)

Si AIRSOLID recrute > 10 nomades supplémentaires ou ouvre le site secondaire, Proxmox VE supporte nativement les sessions VDI (via SPICE ou RDP) sans surcoût. Un pilote VDI pour les postes SAV pourrait être évalué à 18 mois pour centraliser les mises à jour des fiches techniques.

---

## Objectif 7 — Hyper-V & résilience — lien atelier « résilience Windows » + ce cas

### Lien pédagogique avec l'atelier Hyper-V

L'atelier de résilience Windows utilise Hyper-V pour illustrer les concepts de haute disponibilité. Ces concepts se transposent directement au cas AIRSOLID avec Proxmox VE :

| Concept Hyper-V (atelier) | Équivalent Proxmox VE (AIRSOLID) |
|---|---|
| Hyper-V Failover Clustering | Proxmox VE HA Manager |
| Live Migration (vMotion) | Proxmox VM Migration (online) |
| Hyper-V Replica | Proxmox Storage Replication (ZFS) |
| Checkpoints (snapshots) | Proxmox Snapshots (qemu) |
| Windows Server Backup | Proxmox Backup Server (PBS) |
| CSV (Cluster Shared Volumes) | Ceph (optionnel) ou ZFS repliqué |

### Résilience spécifique à AIRSOLID

**Scénario de panne SRV1** (exercice pratique) :

```
État initial : VM-ERP tourne sur SRV1
↓
Simulation : SRV1 éteint brusquement
↓
Détection HA (watchdog corosync) : ~30 secondes
↓
Décision HA Manager : VM-ERP migre sur SRV2
↓
Redémarrage VM-ERP sur SRV2 : ~3-4 minutes
↓
État final : VM-ERP opérationnelle sur SRV2, utilisateurs reconnectés
```

**RTO mesuré** : < 5 minutes → **objectif "plus jamais 48h" atteint**

### Points de résilience Windows maintenus

- VM-AD + VM-AD-REP : 2 contrôleurs de domaine → si VM-AD tombe, VM-AD-REP prend le relais immédiatement (DNS, authentification continuent)
- DHCP en failover : DHCP configuré en mode failover actif/passif entre VM-AD et VM-AD-REP
- DFS-R : si VM-FILE tombe, les partages peuvent basculer sur un second nœud DFS (évolution)

---

## Objectif 8 — PRA / PCO — plan de continuité documenté

### Définitions

- **PRA** (Plan de Reprise d'Activité) : procédures techniques pour rétablir les services après sinistre
- **PCO** (Plan de Continuité des Opérations) : procédures organisationnelles pour maintenir l'activité pendant l'incident

### Scénarios couverts

#### Scénario A — Panne d'un serveur physique (incident partiel)

**Détection** : alerte VM-MON en < 5 min  
**Impact** : VMs basculent automatiquement sur le nœud survivant (HA)  
**Actions prestataire** :
1. Confirmer la bascule HA depuis l'interface Proxmox
2. Diagnostiquer la cause sur le nœud en panne
3. Commander les pièces si matériel défaillant (SLA HPE/Dell Next-Business-Day)
4. Réintégrer le nœud réparé au cluster
**RTO** : < 5 min (automatique) / RTO réparation nœud : < 8h (NBD)

#### Scénario B — Ransomware (chiffrement des données)

**Détection** : alerte sur activité I/O anormale + surveillance comportementale OPNsense IDS  
**Actions immédiates** (Direction + Prestataire) :
1. Isoler les VMs infectées (couper réseau depuis Proxmox)
2. Identifier le périmètre de l'infection (quelles VMs touchées)
3. Vérifier l'intégrité des backups PBS (immutables)
4. Restaurer depuis PBS ou Azure Backup selon le périmètre
5. Réinstaller et patcher les VMs affectées avant reconnexion
**RTO** : < 4 h | **RPO** : < 24 h

#### Scénario C — Sinistre total (incendie, inondation)

**Actions** :
1. Activer le mode dégradé (accès M365 cloud disponible immédiatement)
2. Contacter le prestataire pour déploiement d'urgence
3. Louer serveurs temporaires (hébergeur partenaire ou cloud Azure IaaS)
4. Restaurer les VMs depuis Azure Backup Vault
5. Reconfigurer DNS + VPN pour pointer vers le site de repli
**RTO** : < 8 h | **RPO** : < 48 h

### Annuaire de crise

| Rôle | Nom | Contact | Disponibilité |
|---|---|---|---|
| Responsable décision | [Direction AIRSOLID] | [Tél. direct] | H24 |
| Prestataire IT principal | [Nom prestataire] | [Tél. astreinte] | H24 |
| Support Proxmox | Proxmox Support | support@proxmox.com | Selon contrat |
| Support Azure | Microsoft Azure | Via portail Azure | H24 |
| Éditeur ERP | [Nom éditeur] | [Tél. support] | H ouvrées |
| FAI | [Nom FAI] | [Numéro astreinte] | H24 |

### Document de procédure opérationnelle (extrait)

```
PROCÉDURE PRA-001 : Restauration VM depuis PBS

1. Connexion Proxmox Web UI : https://10.0.99.11:8006
   Identifiants : admin / [coffre-fort]

2. Aller dans : Datacenter → Backup → VM concernée
   Choisir le point de restauration (date/heure)

3. Clic "Restore" → Sélectionner nœud cible (SRV1 ou SRV2)
   → Décocher "Start after restore" (vérification avant démarrage)

4. Attendre la fin de la restauration (barre de progression)

5. Vérifier la cohérence des données avant démarrage
   → Snapshot temporaire (au cas où)
   → Démarrer la VM → Tester l'accès applicatif

Durée estimée : 15 à 45 min selon taille VM
```

### Tests du PRA

| Test | Planification | Participants | Critère de succès |
|---|---|---|---|
| Bascule HA (simulation panne nœud) | Trimestriel | Prestataire IT | VMs opérationnelles < 5 min |
| Restauration VM depuis PBS | Mensuel | Prestataire IT | Données cohérentes, service OK |
| Exercice PRA complet (scénario C) | Annuel | Direction + Prestataire | ERP fonctionnel sur site de repli < 8h |
| Mise à jour du document PRA | Annuel (janvier) | Prestataire IT + Direction | Document validé et signé |
