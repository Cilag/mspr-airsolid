# Désinstallation complète de Tailscale — Serveur MSI

**Issue :** GUI-106  
**Date :** 2026-06-02  
**Statut :** En attente de validation explicite du client

> **PRÉREQUIS :** Le VPN Freebox doit être validé en production ET le client doit donner son accord explicite avant d'exécuter ces étapes.

---

## 1. Désinstallation sur Linux

### 1.1 Debian / Ubuntu

```bash
# Arrêt préalable
sudo tailscale down
sudo systemctl stop tailscaled
sudo systemctl disable tailscaled

# Désinstallation du paquet
sudo apt-get remove --purge tailscale -y
sudo apt-get autoremove -y

# Suppression des dépôts Tailscale
sudo rm -f /etc/apt/sources.list.d/tailscale.list
sudo rm -f /usr/share/keyrings/tailscale-archive-keyring.gpg

# Nettoyage de la configuration réseau
sudo rm -rf /var/lib/tailscale
sudo rm -f /etc/tailscale/
```

### 1.2 RHEL / Rocky / AlmaLinux

```bash
sudo tailscale down
sudo systemctl stop tailscaled
sudo systemctl disable tailscaled

sudo dnf remove tailscale -y

# Suppression du dépôt
sudo rm -f /etc/yum.repos.d/tailscale.repo
sudo rm -rf /var/lib/tailscale
```

### 1.3 Vérification post-désinstallation (Linux)

```bash
which tailscale 2>/dev/null && echo "ENCORE PRESENT" || echo "OK - supprimé"
ip link show tailscale0 2>/dev/null && echo "INTERFACE ENCORE PRESENTE" || echo "OK - interface absente"
systemctl status tailscaled 2>/dev/null; echo "Exit: $?"
```

---

## 2. Désinstallation sur Windows

### 2.1 Via PowerShell (administrateur)

```powershell
# Arrêt préalable
Stop-Service -Name Tailscale -Force -ErrorAction SilentlyContinue
tailscale down

# Désinstallation via winget
winget uninstall --id Tailscale.Tailscale --silent

# OU via msiexec si installé par MSI
# Récupérer le ProductCode dans le registre
$ts = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Tailscale*" }
if ($ts) { $ts.Uninstall() }
```

### 2.2 Via Panneau de configuration (méthode graphique)

1. Panneau de configuration → Programmes → Désinstaller un programme
2. Sélectionner **Tailscale** → Désinstaller
3. Suivre l'assistant

### 2.3 Nettoyage des données résiduelles (Windows)

```powershell
# Supprimer données Tailscale
Remove-Item -Recurse -Force "C:\ProgramData\Tailscale" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Tailscale" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:APPDATA\Tailscale" -ErrorAction SilentlyContinue

# Supprimer l'interface réseau virtuelle résiduelle si présente
Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*Tailscale*" } | Remove-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue
```

### 2.4 Vérification post-désinstallation (Windows)

```powershell
Get-Command tailscale -ErrorAction SilentlyContinue  # doit retourner rien
Get-Service -Name Tailscale -ErrorAction SilentlyContinue  # doit retourner rien
Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*Tailscale*" }  # doit être vide
```

---

## 3. Checklist de validation finale

- [ ] Client a donné son accord explicite (par écrit/ticket)
- [ ] VPN Freebox validé en production (GUI-104 fermé)
- [ ] Procédure de désactivation déjà appliquée avec succès
- [ ] Sauvegarde / copie de la clé auth Tailscale si nécessaire au réenregistrement futur
- [ ] Désinstallation exécutée
- [ ] Vérifications post-désinstallation toutes positives

---

## 4. Note : Réinstallation si besoin futur

En cas de besoin de réinstallation ultérieure, consulter : https://tailscale.com/download  
La clé auth devra être régénérée depuis le tableau de bord Tailscale (admin.tailscale.com).
