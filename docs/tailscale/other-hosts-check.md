# Inventaire des autres hôtes utilisant Tailscale — Réseau MSI

**Issue :** GUI-106  
**Date :** 2026-06-02

---

## 1. Méthode de découverte

### 1.1 Depuis un hôte Tailscale actif (avant désactivation du serveur MSI)

```bash
# Lister tous les hôtes du réseau Tailscale (tailnet)
tailscale status

# Format détaillé
tailscale status --json | jq '.Peer[] | {Hostname: .HostName, IP: .TailscaleIPs[0], OS: .OS, Active: .Active, LastSeen: .LastSeen}'
```

### 1.2 Depuis le tableau de bord Tailscale (admin)

URL : https://login.tailscale.com/admin/machines  
→ Affiche tous les appareils enregistrés dans le tailnet avec leur statut (actif/inactif).

---

## 2. Inventaire connu à documenter

> Compléter ce tableau lors de l'exécution de `tailscale status` sur le réseau MSI.

| Hostname | IP Tailscale | OS | Rôle | Statut Tailscale | Action recommandée |
|---|---|---|---|---|---|
| serveur-msi | À récupérer | Windows/Linux | Serveur principal | Actif → à désactiver | Désactiver (GUI-106) |
| *(hôte 2)* | *(à remplir)* | *(à remplir)* | *(à remplir)* | *(à remplir)* | *(à remplir)* |
| *(hôte 3)* | *(à remplir)* | *(à remplir)* | *(à remplir)* | *(à remplir)* | *(à remplir)* |

---

## 3. Procédure de vérification sur chaque hôte découvert

### 3.1 Hôtes Linux

```bash
# Vérifier si Tailscale est installé
which tailscale && tailscale version

# Vérifier si le service est actif
systemctl is-active tailscaled
systemctl is-enabled tailscaled

# Voir les connexions actives
tailscale status
```

### 3.2 Hôtes Windows

```powershell
# Vérifier si Tailscale est installé
Get-Command tailscale -ErrorAction SilentlyContinue
tailscale version

# Vérifier si le service est actif
Get-Service -Name Tailscale -ErrorAction SilentlyContinue

# Voir les connexions actives
tailscale status
```

---

## 4. Recommandations par catégorie d'hôte

| Catégorie | Recommandation |
|---|---|
| Serveur MSI (hôte principal) | Désactiver maintenant (GUI-106) — garder installé comme solution de secours |
| Hôtes clients du réseau MSI | Désactiver après validation VPN Freebox — coordonner avec Network Engineer |
| Hôtes hors réseau MSI (télétravailleurs) | Évaluer au cas par cas — consulter le client avant toute action |
| Hôtes avec rôle relais (subnet router) | Ne pas toucher sans audit complet — risque d'isolement réseau |

---

## 5. Action post-inventaire

Une fois le tableau complété :

1. Identifier les hôtes avec Tailscale actif **et indispensable** (relais, accès distant critique).
2. Créer un plan de désactivation progressif coordonné avec le Network Engineer.
3. Ne désactiver un hôte que **après** confirmation que la connectivité alternative (VPN Freebox ou autre) est opérationnelle vers cet hôte.
4. Documenter chaque désactivation avec date et opérateur.

---

## 6. Commandes de scan réseau complémentaires

Si l'accès admin Tailscale n'est pas disponible, scanner le sous-réseau Tailscale par défaut (100.64.0.0/10) :

```bash
# Depuis un hôte Tailscale actif
nmap -sn 100.64.0.0/10 --open 2>/dev/null | grep -E "^Nmap|latency"

# Ou via arp si sur le même LAN physique
arp -a | grep -v incomplete
```
