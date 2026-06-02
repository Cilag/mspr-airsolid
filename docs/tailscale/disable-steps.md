# Désactivation du service Tailscale — Serveur MSI

**Issue :** GUI-106  
**Date :** 2026-06-02  
**Statut :** Prêt à exécuter — validation client requise avant l'étape finale

---

## 1. Détection de l'OS du serveur MSI

Avant toute action, confirmer l'OS en vous connectant au serveur :

```bash
# Si accès SSH (Linux probable)
uname -a

# Si bureau Windows : Démarrer → Exécuter → winver
```

---

## 2. Désactivation sur Linux

### 2.1 Arrêt immédiat du service

```bash
sudo systemctl stop tailscaled
```

### 2.2 Désactivation au démarrage

```bash
sudo systemctl disable tailscaled
```

### 2.3 Vérification

```bash
systemctl is-active tailscaled      # doit retourner : inactive
systemctl is-enabled tailscaled     # doit retourner : disabled
```

### 2.4 Couper la connexion réseau Tailscale (sans désinstaller)

```bash
sudo tailscale down
```

### 2.5 Vérification réseau

```bash
ip addr show tailscale0    # l'interface doit être absente ou DOWN
tailscale status           # doit retourner : Tailscale is stopped
```

---

## 3. Désactivation sur Windows

### 3.1 Via PowerShell (administrateur)

```powershell
# Arrêt immédiat du service
Stop-Service -Name Tailscale -Force

# Désactivation au démarrage
Set-Service -Name Tailscale -StartupType Disabled
```

### 3.2 Couper la connexion réseau Tailscale

```powershell
tailscale down
```

### 3.3 Vérification

```powershell
Get-Service -Name Tailscale          # Status doit être : Stopped
tailscale status                     # doit retourner : Tailscale is stopped
```

### 3.4 Vérification alternative via Services graphique

`services.msc` → chercher **Tailscale** → Status : Stopped, Démarrage : Désactivé

---

## 4. Contraintes importantes

- **Ne pas désinstaller** Tailscale tant que le VPN Freebox n'est pas validé (voir `fallback-reactivation.md`).
- Coordonner avec le Network Engineer (GUI-104) avant désactivation définitive.
- En cas de doute sur la connectivité, réactiver immédiatement (voir `fallback-reactivation.md`).

---

## 5. Critère de succès

| Vérification | Résultat attendu |
|---|---|
| `systemctl is-active tailscaled` (Linux) | `inactive` |
| `systemctl is-enabled tailscaled` (Linux) | `disabled` |
| `Get-Service Tailscale` (Windows) | `Stopped` + `Disabled` |
| `tailscale status` | `Tailscale is stopped.` |
| Ping vers IP Tailscale du serveur | Timeout (non joignable) |
