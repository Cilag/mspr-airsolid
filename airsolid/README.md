# AIRSOLID — Dossier MSPR Virtualisation

## Contexte client (résumé)

AIRSOLID est un distributeur d'équipements aérauliques et de climatisation (~80 personnes) sans équipe IT interne. Un serveur physique unique de 2012 héberge l'Active Directory, l'ERP web et les partages fichiers. Une panne récente de 48 h a paralysé l'activité commerciale et les expéditions. La direction exige une infrastructure virtualisée éliminant toute dépendance à un point unique de défaillance.

## Index des fichiers

| Fichier | Contenu |
|---|---|
| [01-contexte.md](01-contexte.md) | Analyse du besoin : contraintes techniques, objectifs direction, contraintes budgétaires |
| [02-architecture.md](02-architecture.md) | Architecture virtualisée cible avec schémas Mermaid (topologie, réseau, flux) |
| [03-mise-en-oeuvre.md](03-mise-en-oeuvre.md) | Mise en œuvre : hyperviseur Proxmox VE, configuration VMs, réseau, stockage, AD |
| [04-objectifs.md](04-objectifs.md) | Les 8 objectifs pédagogiques officiels du MSPR appliqués au cas AIRSOLID |
| [05-evolutions.md](05-evolutions.md) | Pistes d'évolution et points de discussion — préparation entretien 2 |
| [assets/](assets/) | Répertoire pour schémas supplémentaires |

## Arborescence

```
airsolid/
├── README.md              ← Ce fichier
├── 01-contexte.md         ← Analyse du besoin
├── 02-architecture.md     ← Architecture cible + schémas
├── 03-mise-en-oeuvre.md   ← Implémentation technique
├── 04-objectifs.md        ← 8 objectifs MSPR
├── 05-evolutions.md       ← Évolutions / entretien 2
└── assets/                ← Ressources graphiques
```

## Points clés de la solution

- **Hyperviseur** : Proxmox VE 8.x (type 1, open-source) sur 2 serveurs physiques
- **Résilience** : réplication inter-nœuds, plus de SPOF, RTO < 4 h
- **Hybride** : AD on-premise + Microsoft 365 (synchronisation Azure AD Connect)
- **Sauvegardes** : règle 3-2-1 — PBS local + Azure Backup hors site
- **Sécurité réseau** : segmentation VLAN + pare-feu OPNsense + VPN WireGuard nomades
