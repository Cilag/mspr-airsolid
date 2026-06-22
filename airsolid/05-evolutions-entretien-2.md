# 05 — Évolutions et pistes pour l'entretien 2

Pas de changements majeurs impactants notre vision de la nouvelle architecture proposée. 
Nous avons présenté ce que nous avions structuré pour AIRSOLID qui a été saatisfaisant selon les retours. 
Alors nous garderons le projet proposé afin de le mettre en oeuvre et delivrer l'architecture attendue. 

---

## 5.1 Évolutions à court terme (0–12 mois)

### 5.1.1 Intégration du site secondaire

L'ouverture du dépôt secondaire prévue dans 12 mois nécessite :

| Action | Détail | Priorité |
|---|---|---|
| Extension du cluster Proxmox | Ajout d'un 3e nœud sur le site secondaire | Haute |
| VPN site-à-site | VPN Sophos entre les deux sites (lien dédié ou fibre) | Haute |
| AD Sites and Services | Configuration des sous-réseaux AD pour routage LDAP optimal | Haute |
| Réplication VEEAM inter-sites | Sauvegarde des VMs critiques sur le site secondaire | Moyenne |
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

## 5.3 Bibliographie et ressources complémentaires

| Ressource | URL / Référence |
|---|---|
| Documentation officielle Proxmox VE | https://pve.proxmox.com/wiki/Main_Page |
| Proxmox Backup Server | https://pbs.proxmox.com/docs/index.html |
| Azure AD Connect — Microsoft | Docs Microsoft Learn : Azure AD Connect |
| Sophos Documentation | https://docs.sophos.com/nsg/sophos-utm/utm/9.708/help/en-us/Content/utm/utmAdminGuide/SupportDocumentation.htm |
| ANSSI — Guide hygiène informatique | ANSSI-GP-078 |
| NIST SP 800-34 — PRA | NIST Special Publication 800-34 Rev. 1 |
