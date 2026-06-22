# 01 — Contexte et analyse du besoin

## 1.1 Présentation du client

**AIRSOLID** est un distributeur spécialisé en équipements aérauliques et climatisation basé en France, comptant environ 80 collaborateurs répartis entre :
- Le siège social avec les équipes commerciales sédentaires, administration et direction
- Un atelier de service après-vente (SAV) avec des techniciens
- Des commerciaux nomades intervenant en itinérance chez les clients

L'entreprise est **multisite** : elle dispose d'un entrepôt avec des collaborateurs présents en **France et en Allemagne**. Les postes de travail sont des **ordinateurs de bureau fixes** (pas de BYOD, pas de mobilité interne) et la téléphonie repose sur des **téléphones fixes filaires** sur site.

L'entreprise ne dispose plus d'équipe IT interne depuis le départ de son dernier responsable informatique. La gestion de l'infrastructure repose actuellement sur des interventions ponctuelles d'un prestataire externe.

---

## 1.2 Situation technique actuelle

### Infrastructure existante

| Composant | Description |
|---|---|
| Serveur physique | 1 machine Dell PowerEdge (2012), processeur Intel Xeon E5-2600 v1, 32 GB RAM |
| Système d'exploitation | Windows Server 2012 R2 (fin de support Microsoft depuis octobre 2023) |
| Rôles hébergés | Active Directory Domain Services (ADDS), DNS, DHCP, partages fichiers (SMB), ERP web (IIS) |
| Stockage | Disques SAS internes, RAID 5 dégradé (une panne antérieure non remplacée) — capacité **10 TB**, serveur âgé de **plus de 15 ans** |
| Réseau | Réseau plat, sans segmentation VLAN, switch non manageable |
| Sauvegarde | Aucune politique formelle ; seul un disque USB branché manuellement de façon irrégulière |
| Accès distant | VPN PPTP héritée, connexion directe RDP exposée sur internet pour certains postes |
| Alimentation secourue | **UPS en place** (existant — point positif pour la continuité) |
| Accès ERP | Accès pour tous, **aucun VPN configuré** — risque de sécurité |
| Partage de fichiers | Via le navigateur de fichiers intégré à l'ERP — pas de serveur de fichiers dédié actuellement |
| Supervision | Aucune surveillance automatisée des services ou de la disponibilité |

### Points de défaillance critiques identifiés

1. **SPOF absolu** : un seul serveur physique concentre l'ensemble des services critiques (AD, ERP, fichiers). Toute panne matérielle entraîne l'arrêt complet de l'activité.
2. **OS hors support** : Windows Server 2012 R2 n'est plus patché ; vulnérabilités connues non corrigées.
3. **Stockage dégradé** : RAID 5 avec un disque manquant = une deuxième panne disque entraîne une perte totale des données.
4. **Absence de sauvegarde fiable** : le disque USB manuel ne garantit ni la fréquence ni l'intégrité des données.
5. **Réseau plat** : aucune isolation entre les postes bureautiques, l'atelier SAV et les serveurs.
6. **Accès nomades non sécurisés** : PPTP est considéré comme non sûr depuis 2012 ; RDP exposé = surface d'attaque ransomware.
7. **Aucun VPN pour l'accès ERP** : l'ERP est accessible à tous sans VPN — exposition directe des données métier.
8. **Sécurité : terra incognita** : le client n'a aucune politique de sécurité connue et déclare « je ne sais pas » sur l'état de la sécurité.

### Incident déclencheur

En 2025, **l'ERP on-premise a perdu sa connexion internet**, provoquant **48 heures d'indisponibilité totale** :
- Arrêt complet de l'ERP → aucune commande, aucune expédition possible
- **30 collaborateurs en télétravail** dans l'impossibilité de se connecter
- Impossibilité d'accéder aux partages fichiers (bons de livraison, fiches techniques)
- Commerciaux bloqués sans accès aux données clients
- Perte estimée : chiffre d'affaires de deux journées complètes + impact image client

---

## 1.3 Objectifs exprimés par la direction

La direction d'AIRSOLID a formulé les exigences suivantes, par ordre de priorité :

### Priorité 1 — Continuité d'activité
> *"Plus jamais 48 heures sans ERP."*

- **RTO cible** (Recovery Time Objective) : < 4 heures en cas de panne d'un serveur
- **RPO cible** (Recovery Point Objective) : < 24 heures de perte de données maximale
- Tolérance aux pannes matérielles sans interruption de service visible par les utilisateurs

### Priorité 2 — Modernisation et pérennité
- Migrer vers des systèmes d'exploitation supportés (Windows Server 2022 ou 2025)
- Capitaliser sur le déploiement **Microsoft 365** en cours (synchronisation des identités, accès cloud) — Migration complète de TOUS les utilisateurs vers 365, abandon de GMAIL pour un passage complet sur les outils du cloud Microsoft 
- Prévoir l'intégration du **dépôt secondaire** ouverture sous 12 mois

### Priorité 3 — Sécurisation des flux EDI et des accès nomades
- Flux EDI (échanges de données avec les fournisseurs/transporteurs) à sécuriser
- Remplacement du VPN PPTP par une solution moderne pour les commerciaux itinérants
- Segmentation réseau entre les différentes populations (bureau, atelier, serveurs)

### Priorité 4 — Sauvegardes et conformité
- Mise en place d'une politique de sauvegarde formelle et testée
- Conservation des données en dehors du site (sinistre, incendie, inondation)
- Conformité RGPD sur la gestion des données personnelles clients

---

## 1.4 Contraintes techniques

| Contrainte | Détail |
|---|---|
| **Absence d'IT interne** | La solution doit être gérable par un prestataire externe ; interface d'administration simple |
| **Dépendance à l'ERP** | L'ERP web est un logiciel tiers critique ; migration à coordonner avec l'éditeur |
| **Active Directory existant** | Les postes Windows sont joints au domaine ; l'AD doit être maintenu opérationnel |
| **Postes hétérogènes** | Mix Windows 10/11 bureaux + postes atelier sous Windows (potentiellement anciens) |
| **Bande passante limitée** | Connexion internet standard (fibre 1 Gb/500 Mb) ; cloud hybride à dimensionner |
| **Continuité pendant migration** | Pas d'interruption acceptable pendant les heures ouvrées (L-V 8h-18h) |
| **Présence multisite** | Entrepôt avec collaborateurs en France et en Allemagne — architecture à prévoir pour les deux sites |
| **Postes fixes uniquement** | Ordinateurs de bureau sur site, téléphonie fixe — pas de BYOD, pas de mobilité interne |

---

## 1.5 Synthèse du besoin

```
Situation actuelle → Problème → Besoin
─────────────────────────────────────────────────────────────────
1 serveur unique    → SPOF        → ≥ 2 nœuds avec réplication
OS hors support     → Vulnérable  → Migration WS 2022
Pas de sauvegarde   → Perte data  → 3-2-1 automatisé + testé
Réseau plat         → Exposition  → VLANs + pare-feu
VPN PPTP obsolète   → Non sécurisé→ WireGuard ou OpenVPN
Pas de VPN ERP      → Accès non sécurisé → VPN WireGuard pour télétravailleurs
EDI non défini      → Flux à risque      → Proposition AS2/SFTP à soumettre
Aucune supervision  → Panne non détectée → Monitoring 24/7
```
