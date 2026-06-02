# Procédure de secours — Réactivation Tailscale

**Issue :** GUI-106  
**Date :** 2026-06-02  
**Usage :** En cas de défaillance du VPN Freebox, réactiver Tailscale pour restaurer la connectivité vers le serveur MSI.

---

## 1. Scénario de déclenchement

Utiliser cette procédure si **l'une** de ces conditions est vraie :

- Le VPN Freebox ne répond plus / connexion perdue vers le serveur MSI
- Perte d'accès distant au serveur MSI via tous les autres canaux
- Incident réseau nécessitant une connexion de secours d'urgence

---

## 2. Réactivation sur Linux

### 2.1 Réactivation rapide (service déjà installé, juste désactivé)

```bash
# Redémarrer et réactiver le service
sudo systemctl enable tailscaled
sudo systemctl start tailscaled

# Vérification
systemctl is-active tailscaled    # doit retourner : active
tailscale status                  # doit montrer l'IP Tailscale du serveur
```

### 2.2 Si la connexion Tailscale est coupée (après `tailscale down`)

```bash
sudo tailscale up
# Suivre les instructions d'authentification si demandé
```

### 2.3 Si une auth key est nécessaire (premier démarrage ou expirée)

```bash
# Générer une auth key sur https://login.tailscale.com/admin/settings/keys
sudo tailscale up --authkey=tskey-auth-XXXXXXXXX
```

### 2.4 Vérification complète

```bash
tailscale status
tailscale ping <hostname-autre-hote>   # test connectivité
ip addr show tailscale0                # vérifier que l'interface est UP
```

---

## 3. Réactivation sur Windows

### 3.1 Réactivation rapide (service déjà installé, juste désactivé)

```powershell
# Réactiver et démarrer le service
Set-Service -Name Tailscale -StartupType Automatic
Start-Service -Name Tailscale

# Vérification
Get-Service -Name Tailscale    # Status doit être : Running
tailscale status
```

### 3.2 Si la connexion Tailscale est coupée

```powershell
tailscale up
```

### 3.3 Si une auth key est nécessaire

```powershell
tailscale up --authkey=tskey-auth-XXXXXXXXX
```

### 3.4 Vérification complète

```powershell
tailscale status
tailscale ping <hostname-autre-hote>
Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*Tailscale*" }  # doit être Up
```

---

## 4. Contacts et ressources en cas de blocage

| Besoin | Ressource |
|---|---|
| Auth key Tailscale | https://login.tailscale.com/admin/settings/keys (accès admin requis) |
| Statut du service Tailscale | https://tailscalestatus.com |
| Network Engineer (VPN Freebox) | Escalader via Infra Lead / GUI-104 |
| Accès physique au serveur MSI | Contact client direct |

---

## 5. Procédure de re-désactivation après résolution de l'incident

Une fois l'incident VPN Freebox résolu et la connectivité restaurée :

1. Confirmer avec le Network Engineer que le VPN Freebox est stable.
2. Re-appliquer la désactivation Tailscale (voir `disable-steps.md`).
3. Mettre à jour l'issue GUI-106 avec la date et le motif.

---

## 6. Temps estimé de réactivation

| Étape | Durée estimée |
|---|---|
| Démarrage du service (Linux/Windows) | < 30 secondes |
| Reconnexion au tailnet | < 2 minutes |
| Disponibilité complète | < 5 minutes |

> La réactivation est rapide tant que Tailscale n'est **pas désinstallé**. C'est pourquoi la désinstallation ne doit avoir lieu qu'après validation définitive du VPN Freebox.
