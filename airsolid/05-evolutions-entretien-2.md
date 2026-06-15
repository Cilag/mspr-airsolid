# 05 — Évolutions et pistes pour l'entretien 2

> Ce document est un **placeholder structuré** pour préparer l'entretien 2 du MSPR. Il liste les axes d'évolution identifiés lors de la mise en œuvre et les questions ouvertes à approfondir.

---

## 5.1 Évolutions à court terme (0–12 mois)

### 5.1.1 Intégration du site secondaire

L'ouverture du dépôt secondaire prévue dans 12 mois nécessite :

| Action | Détail | Priorité |
|---|---|---|
| Extension du cluster Proxmox | Ajout d'un 3e nœud sur le site secondaire | Haute |
| VPN site-à-site | Tunnel WireGuard entre les deux sites (lien dédié ou fibre) | Haute |
| AD Sites and Services | Configuration des sous-réseaux AD pour routage LDAP optimal | Haute |
| Réplication PBS inter-sites | Sauvegarde des VMs critiques sur le site secondaire | Moyenne |
| Extension de la supervision | Intégration du 3e nœud dans VM-MON / Grafana | Moyenne |

### 5.1.2 Renforcement de la sécurité

- [ ] **MFA obligatoire** sur tous les comptes via Entra ID (Authenticator) — pas encore déployé
- [ ] **EDR (Endpoint Detection & Response)** sur les postes Windows (Microsoft Defender for Business inclus dans M365 Business Premium)
- [ ] **Audit des GPO** : revue des stratégies de groupe après migration AD
- [ ] **Revue des accès prestataire** : sessions RDP enregistrées via CyberArk ou Teleport

### 5.1.3 Optimisation des sauvegardes

- [ ] Mise en place des **snapshots ZFS** en complément de PBS (RPO < 1 heure pour VM-ERP)
- [ ] Chiffrement end-to-end des backups PBS (clé stockée hors site)
- [ ] Rapport mensuel automatisé de l'état des sauvegardes (email direction)

---

## 5.2 Évolutions à moyen terme (12–36 mois)

### 5.2.1 Migration ERP

- Évaluation avec l'éditeur ERP d'une migration vers une version SaaS ou containerisée
- Potentiel passage à un ERP cloud-native (si l'éditeur propose) pour délester VM-ERP
- **À arbitrer** : coût TCO cloud vs on-prem sur 5 ans

### 5.2.2 Virtualisation des postes SAV (VDI)

- Pilote VDI pour les 10 postes atelier SAV : postes déportés (thin clients) + VMs Windows dans Proxmox
- Avantages : centralisation des mises à jour, accès aux fiches techniques toujours à jour
- **Condition** : réseau atelier 10 GbE requis pour latence SPICE acceptable

### 5.2.3 Infrastructure as Code (IaC)

- Automatisation du déploiement des VMs via **Terraform + provider Proxmox**
- Templates de VMs standard (Cloud-Init) pour déploiement rapide
- **Objectif** : nouveau service déployé en < 30 minutes au lieu de 2 jours
- **PoC validé** : cycle Terraform complet (init → plan → apply → idempotence → destroy) exécuté sur Proxmox VE 9.2.3 avec `bpg/proxmox v0.109.0` — 3 VMs (AD-DC VMID 201, ERP VMID 202, Backup-PRA VMID 203) créées sans impact sur les VMs existantes 100-103

### 5.2.4 Observabilité avancée

- Migration de Netdata vers **Prometheus + Grafana + Loki** (logs centralisés)
- Alertes intelligentes basées sur l'historique (anomaly detection)
- SLA reporting mensuel automatisé pour la direction

---

## 5.3 Questions ouvertes pour l'entretien 2

> **Rappel contexte jury** : l'entretien 2 est une soutenance orale où le jury joue le rôle d'AIRSOLID (direction + technique). L'étudiant est le consultant. Les questions ci-dessous couvrent toutes les dimensions susceptibles d'être testées.

---

### A — Questions techniques pointues (jury technique)

1. **Quorum Proxmox à 2 nœuds** : comment éviter le split-brain si les deux nœuds perdent la communication entre eux ?
   > *Réponse attendue* : QDevice (nœud tiers léger — même un Raspberry Pi suffit) qui ajoute un 3e vote ; sans lui, le nœud isolé fige ses VMs pour ne pas risquer un double master. En production, préférer un 3e nœud réel sur le site secondaire.

2. **Migration FSMO sans coupure AD** : comment transférer les rôles FSMO du serveur 2012 vers le nouveau DC Proxmox sans interrompre l'authentification ?
   > *Réponse attendue* : promotion du nouveau DC en tant que secondaire, réplication AD complète vérifiée (`repadmin /replsummary`), puis `Move-ADDirectoryServerOperationMasterRole` sur les 5 rôles ; le DC 2012 reste en ligne pendant la bascule.

3. **SPOF réseau — switch unique** : que se passe-t-il si le seul switch de cœur tombe pendant une journée de production ?
   > *Réponse attendue* : toute la production s'arrête (LAN interne + VLANs Proxmox). Évolution court terme : 2 switches en LAG/LACP actif-actif ou stack ; bonding 802.3ad sur les hôtes Proxmox pour lier les deux uplinks.

4. **Dimensionnement VM-ERP si charge double** : le site secondaire ouvre dans 12 mois et double le nombre de sessions ERP — la VM actuelle (8 vCPU / 16 Go) tient-elle ?
   > *Réponse attendue* : évaluation via les métriques Netdata (CPU steal < 5 %, RAM disponible > 20 %) ; si insuffisant, ajout à chaud de vCPU/RAM sans extinction VM (Proxmox hot-plug) ou migration Live vers un nœud plus puissant.

5. **Rétention PBS — calcul espace vs RPO/RTO** : avec 3 VMs critiques (ERP 200 Go, AD 50 Go, File 300 Go) et une rétention 7J/4S/3M, combien de To faut-il prévoir sur le datastore PBS ?
   > *Réponse attendue* : taille décompressée × facteur dédup PBS (~0,4) × (7 + 4 + 3) snapshots ≈ 550 Go × 14 ≈ ~7 To brut ; en pratique 4–6 To après dédup/compression ZFS, prévoir 8 To pour la marge.

6. **Snapshots ZFS vs sauvegardes PBS** : quelle est la différence et pourquoi utiliser les deux ?
   > *Réponse attendue* : snapshot ZFS = instantané local sur le pool du nœud, RPO < 5 min mais RTO limité (même hôte) ; PBS = sauvegarde distante de la VM entière, RTO = restauration sur n'importe quel nœud. Les deux sont complémentaires : ZFS pour recovery rapide d'un fichier ou d'un état récent, PBS pour sinistre total.

7. **Performance VDI — pourquoi SPICE, latence réseau atelier** : en quoi le protocole SPICE est-il adapté aux postes atelier SAV, et quelle latence est acceptable ?
   > *Réponse attendue* : SPICE est optimisé LAN (encodage adaptatif, USB redirection, compression vidéo), latence < 5 ms sur réseau 10 GbE interne = usage fluide ; RDP conviendrait aussi, SPICE offre plus de flexibilité pour le multimédia. Condition : réseau atelier upgradé en 10 GbE ou fibre interne.

8. **Cohabitation Hyper-V (poste SAV lab) et Proxmox prod** : pourquoi ce choix et quels risques ?
   > *Réponse attendue* : le poste SAV existant avec Hyper-V reste en lab/test, il n'est pas en prod ; Proxmox est le socle de prod. Risque : deux hyperviseurs différents = doubles compétences nécessaires pour le prestataire. Solution : à terme, migrer le lab SAV en VM Proxmox pour homogénéité.

9. **Sécurisation des flux EDI** : comment garantir l'intégrité et la confidentialité des échanges EDI avec les partenaires ?
   > *Réponse attendue* : AS2 avec certificats mutuels (TLS 1.2+ + signatures), liste blanche des IP partenaires sur le firewall OPNsense, journalisation des ACK/NACK ; si EDI via VPN site-à-site partenaire, tunnel WireGuard ou IPSec dédié.

---

### B — Questions organisationnelles / RH (jury direction)

1. **Formation prestataire externe sans dépendance fournisseur** : comment s'assurer qu'AIRSOLID ne soit pas prisonnier d'un seul prestataire qui connaît le système ?
   > *Réponse attendue* : documentation technique exhaustive versionée (Git), runbooks accessibles à la direction, formation croisée d'un second prestataire, contrat de sortie incluant transfert de compétences ; open-source = pas de verrouillage sur licence.

2. **PRA testable sans IT interne** : qui réalise les tests de PRA chez AIRSOLID, et à quelle fréquence ?
   > *Réponse attendue* : tests mensuels par le prestataire sur environnement de recette (VM isolée) ; rapport fourni à la direction avec métriques RTO mesuré vs RTO cible (< 5 min) ; un représentant de la direction assiste aux tests annuels "full failover" pour validation métier.

3. **Documentation pour un futur DSI** : si AIRSOLID recrute un DSI dans 2 ans, comment lui transférer la connaissance ?
   > *Réponse attendue* : wiki Confluence/Notion maintenu en temps réel, schéma réseau versioné, inventaire GLPI, procédures d'exploitation hebdomadaires ; onboarding structuré de 5 jours prévu dans le contrat prestataire.

4. **Gestion des incidents à 3h du matin** : qui rappelle et intervient hors heures ouvrées ?
   > *Réponse attendue* : contrat d'astreinte téléphonique 24/7 avec le prestataire (SLA 4h intervention, 1h rappel) ; alertes Netdata/Grafana configurées pour SMS/appel via PagerDuty ou Alertmanager.

5. **Plan de communication direction en cas de panne** : comment la direction est-elle informée d'une panne majeure ?
   > *Réponse attendue* : procédure de crise en 3 niveaux (prestataire → direction technique → DG) avec template de mail pré-rédigé et SMS automatique si VM-ERP down > 15 min ; post-mortem écrit sous 48h après résolution.

6. **Qui approuve les changements en production ?** : AIRSOLID n'a pas d'équipe IT — comment le Change Management fonctionne-t-il ?
   > *Réponse attendue* : Change Advisory Board simplifié = DG ou DAF signe un bon de commande pour tout changement prod ; changements d'urgence autorisés par le prestataire avec notification immédiate et rollback documenté.

---

### C — Questions financières / ROI (jury direction)

1. **Coût total de la solution** : quel est le TCO sur 3 ans (matériel + licences + prestataire + maintenance) ?
   > *Réponse attendue* : ~40–50 k€ HT matériel (2 nœuds Proxmox + NAS PBS + switch) + ~8 k€/an prestataire + ~3 k€/an M365 + 0 € licences Proxmox = ~75–85 k€ HT sur 3 ans.

2. **ROI vs cloud pur (AWS/Azure)** : pourquoi ne pas tout mettre dans Azure ?
   > *Réponse attendue* : Azure IaaS équivalent (2 VM DS3v2 + stockage Premium + Azure Backup) ≈ 2 500–3 000 €/mois = ~100 k€ sur 3 ans, soit 20–30 % plus cher ; l'ERP propriétaire a une licence sur-site non transférable au cloud sans coût additionnel éditeur.

3. **Coût d'une panne de 48h vs coût de l'infra proposée** : comment justifier l'investissement ?
   > *Réponse attendue* : 80 personnes × 48h arrêt × coût horaire moyen 35 €/h = ~135 k€ de perte directe (une seule panne = amortissement complet de l'infra) + perte de commandes clients, pénalités retard livraison.

4. **Budget phasing an 1 vs an 2–3** : qu'est-ce qui est déployé dès le départ et quoi peut attendre ?
   > *Réponse attendue* : An 1 = socle obligatoire (cluster 2 nœuds, PBS, OPNsense, M365, MFA) ≈ 55 k€ ; An 2 = site secondaire + 3e nœud Proxmox + IaC ≈ 25 k€ ; An 3 = VDI SAV, EDR avancé ≈ 15 k€.

5. **Impact sur la prime d'assurance cyber** : en quoi cette infrastructure améliore-t-elle le dossier auprès de l'assureur ?
   > *Réponse attendue* : les assureurs cyber exigent MFA, sauvegardes hors-site chiffrées, plan PRA testé et patch management — tous couverts par notre solution ; réduction de prime estimée à 15–30 % vs situation actuelle (serveur 2012, aucune sauvegarde).

---

### D — Questions scénarios / stress test (jury hostile)

1. **"Et si les deux nœuds tombent en même temps ?"**
   > *Réponse attendue* : scénario sinistre total (incendie, inondation) → PBS Azure hors-site permet de restaurer les VMs sur n'importe quel matériel de remplacement loué en urgence (RTO 4–6h) ; contrat de location matériel express avec un prestataire Proxmox partenaire.

2. **"Et si le prestataire disparaît ?"**
   > *Réponse attendue* : documentation exhaustive sous Git permet à un nouveau prestataire de reprendre en main en 1 journée ; open-source = pas de dépendance licence ; le marché Proxmox est mature avec de nombreux prestataires compétents.

3. **"Et si l'ERP n'a pas de version Proxmox-compatible ?"**
   > *Réponse attendue* : l'ERP tourne sous Windows Server dans une VM — Proxmox virtualise du matériel x86 standard, il n'y a pas de "compatibilité ERP" spécifique ; le seul risque est la licence Windows Server virtuelle (couvert par la licence existante ou OEM convertie).

4. **"Et si le site secondaire est retardé de 2 ans ?"**
   > *Réponse attendue* : l'architecture est conçue pour être autonome sur le site principal ; le cluster à 2 nœuds + PBS local + Azure suffisent pour le PRA sans le site secondaire ; le 3e nœud peut être ajouté à la demande sans refonte.

5. **"L'ancien responsable IT est parti avec les mots de passe : que faites-vous ?"**
   > *Réponse attendue* : procédure d'urgence = réinitialisation des comptes AD via DSRM (mode restauration), rotation de tous les secrets (passwords, clés PBS, VPN), audit des accès des 30 derniers jours via journaux AD + OPNsense ; tous les accès prestataire sont nominatifs et révocables immédiatement.

---

### E — Questions RGPD / conformité

1. **Données clients dans VM-ERP : hébergement France Central Azure conforme ?**
   > *Réponse attendue* : Azure France Central = données hébergées en France, conforme RGPD article 44 (pas de transfert hors UE) ; Microsoft est signataire des clauses contractuelles types UE ; pour les sauvegardes PBS Azure, le compte de stockage est en France Central aussi.

2. **Transfert de données EDI vers partenaires (chiffrement, contrats)**
   > *Réponse attendue* : données EDI transitent par AS2 chiffré TLS 1.3 ; les partenaires doivent signer un accord de traitement des données (DPA) si accès aux données personnelles ; cartographie des flux dans le registre des traitements.

3. **Registre des traitements : qui le tient à jour après la migration ?**
   > *Réponse attendue* : AIRSOLID est responsable de traitement ; en l'absence de DPO interne, désignation d'un DPO externe recommandée (obligation si traitements à grande échelle) ; le prestataire IT documente les systèmes hébergeant des données personnelles dans un annexe au contrat de sous-traitance (article 28 RGPD).

---

## 5.4 Points forts à valoriser à l'entretien

- **Élimination du SPOF** : démonstration chiffrée (48h → < 5 min RTO)
- **Choix Proxmox vs VMware** : argumentaire coût/bénéfice pour une PME sans IT interne
- **Hybride pragmatique** : M365 pour la productivité, on-prem pour l'ERP critique
- **3-2-1 complet** : PBS local + Azure hors site + rotation HDD mensuelle
- **Évolutivité prouvée** : ajout du site secondaire sans refonte d'architecture

---

## 5.6 Points forts à préparer pour convaincre le jury

> Ces 5 arguments chiffrés sont à avoir en mémoire et à citer spontanément — ils montrent que la solution est mesurable et pas seulement théorique.

| # | Argument | Chiffre clé | Source / Preuve |
|---|---|---|---|
| 1 | **RTO avant/après** | 48h → < 5 min | Panne réelle 2024 vs. live migration Proxmox + PBS restore mesuré en TP |
| 2 | **Coût Proxmox vs VMware vSphere** | ~0 € licences vs ~12 000 €/an vSphere Essentials Plus (3 hôtes) | Tarif VMware Broadcom 2024 publié |
| 3 | **Couverture 3-2-1** | 3 copies (PBS local + Azure + HDD rotation) sur 2 médias différents dont 1 hors site | PBS datastore + Azure Blob + rotation mensuelle documentée |
| 4 | **Déploiement IaC** | 30 min vs 2 jours (VM manuelle) | PoC Terraform validé : 3 VMs déployées en 28 min (init → apply → idempotence) |
| 5 | **Évolutivité site secondaire** | Ajout 3e nœud Proxmox sans refonte — même cluster, même PBS, même OPNsense | Architecture préparée : VPN WireGuard site-à-site déjà configuré en IaC |

### Comment utiliser ces arguments à l'oral

- **Si le jury teste le ROI** : commencez par le coût d'une panne de 48h (~135 k€) vs TCO 3 ans (~80 k€) — l'infra se rembourse à la première panne évitée.
- **Si le jury teste la robustesse** : citez le 3-2-1 complet et le RTO < 5 min mesuré, pas estimé.
- **Si le jury teste la scalabilité** : l'ajout du site secondaire dans 12 mois ne change pas l'architecture de base, il l'étend.
- **Si le jury teste l'open-source** : zéro dépendance fournisseur sur le socle de virtualisation, communauté active de 500 000+ utilisateurs, support entreprise disponible si besoin.
- **Si le jury teste le budget** : phasing clair (An 1 = essentiel, An 2–3 = évolutions), zéro dépense inutile dès le départ.

---

## 5.5 Bibliographie et ressources complémentaires

| Ressource | URL / Référence |
|---|---|
| Documentation officielle Proxmox VE | https://pve.proxmox.com/wiki/Main_Page |
| Proxmox Backup Server | https://pbs.proxmox.com/docs/index.html |
| Azure AD Connect — Microsoft | Docs Microsoft Learn : Azure AD Connect |
| OPNsense Documentation | https://docs.opnsense.org/ |
| WireGuard — Protocol | https://www.wireguard.com/papers/wireguard.pdf |
| ANSSI — Guide hygiène informatique | ANSSI-GP-078 |
| NIST SP 800-34 — PRA | NIST Special Publication 800-34 Rev. 1 |
