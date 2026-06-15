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

### Techniques

1. **Quorum Proxmox avec 2 nœuds** : comment gérer le split-brain avec seulement 2 serveurs ? (Solution : QDevice tiers ou 3e nœud léger)
2. **Migration à chaud de l'AD** : comment éviter l'impact sur les postes utilisateurs lors du transfert des rôles FSMO ?
3. **Résilience réseau** : que se passe-t-il si le switch unique tombe ? (Évolution : 2 switches en LAG/LACP)
4. **Performance ERP** : comment dimensionner VM-ERP si la charge double avec le nouveau site ?
5. **Gestion des snapshots PBS** : quelle stratégie de rétention optimiser le ratio espace/couverture temporelle ?

### Organisationnels

1. Comment former le prestataire externe à l'administration Proxmox sans créer de dépendance ?
2. Qui valide les tests de PRA chez AIRSOLID sans équipe IT interne ?
3. Comment documenter les procédures pour un éventuel futur DSI AIRSOLID ?

### Réglementaires

1. RGPD : les données clients dans VM-ERP et VM-FILE sont-elles suffisamment protégées ?
2. La copie Azure Backup en région France Central est-elle conforme aux exigences de souveraineté ?
3. Assurance cyber : quels prérequis techniques pour bénéficier d'une couverture ransomware ?

---

## 5.4 Points forts à valoriser à l'entretien

- **Élimination du SPOF** : démonstration chiffrée (48h → < 5 min RTO)
- **Choix Proxmox vs VMware** : argumentaire coût/bénéfice pour une PME sans IT interne
- **Hybride pragmatique** : M365 pour la productivité, on-prem pour l'ERP critique
- **3-2-1 complet** : PBS local + Azure hors site + rotation HDD mensuelle
- **Évolutivité prouvée** : ajout du site secondaire sans refonte d'architecture

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
