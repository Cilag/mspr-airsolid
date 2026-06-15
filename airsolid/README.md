# AIRSOLID — Dossier MSPR Virtualisation

## Contexte client (résumé)

AIRSOLID est un distributeur d'équipements aérauliques et de climatisation (~80 personnes) sans équipe IT interne. Un serveur physique unique de 2012 héberge l'Active Directory, l'ERP web et les partages fichiers. Une panne récente de 48 h a paralysé l'activité commerciale et les expéditions. La direction exige une infrastructure virtualisée éliminant toute dépendance à un point unique de défaillance.

## Index des fichiers

| Fichier | Contenu |
|---|---|
| [01-contexte-besoin.md](01-contexte-besoin.md) | Analyse du besoin : contraintes techniques, objectifs direction, contraintes budgétaires |
| [02-architecture-proposee.md](02-architecture-proposee.md) | Architecture virtualisée cible avec schémas Mermaid (topologie, réseau, flux) |
| [03-mise-en-oeuvre.md](03-mise-en-oeuvre.md) | Mise en œuvre : hyperviseur Proxmox VE, configuration VMs, réseau, stockage, AD |
| [04-objectifs-pedagogiques.md](04-objectifs-pedagogiques.md) | Les 8 objectifs pédagogiques officiels du MSPR appliqués au cas AIRSOLID |
| [05-evolutions-entretien-2.md](05-evolutions-entretien-2.md) | Pistes d'évolution et points de discussion — préparation entretien 2 |
| [assets/](assets/) | Répertoire pour schémas supplémentaires |

## Arborescence

```
airsolid/
├── README.md                       ← Ce fichier
├── 01-contexte-besoin.md           ← Analyse du besoin
├── 02-architecture-proposee.md     ← Architecture cible + schémas
├── 03-mise-en-oeuvre.md            ← Implémentation technique
├── 04-objectifs-pedagogiques.md    ← 8 objectifs MSPR
├── 05-evolutions-entretien-2.md    ← Évolutions / entretien 2
└── assets/                         ← Ressources graphiques
```

## Points clés de la solution

- **Hyperviseur** : Proxmox VE 8.x (type 1, open-source) sur 2 serveurs physiques
- **Résilience** : réplication inter-nœuds, plus de SPOF, RTO < 4 h
- **Hybride** : AD on-premise + Microsoft 365 (synchronisation Azure AD Connect)
- **Sauvegardes** : règle 3-2-1 — PBS local + Azure Backup hors site
- **Sécurité réseau** : segmentation VLAN + pare-feu OPNsense + VPN WireGuard nomades
