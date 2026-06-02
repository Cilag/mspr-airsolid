# Règles NAT/Pare-feu — VPN WireGuard FreeboxOS

## Règle NAT automatique (FreeboxOS)

Le serveur WireGuard FreeboxOS gère automatiquement la règle NAT WAN→Freebox.

| Direction | Port | Protocole | Statut |
|---|---|---|---|
| WAN → Freebox (VPN) | **61032** | UDP | Automatique ✓ |

> ⚠️ Si la Freebox est derrière un routeur/modem ISP, ouvrir manuellement le port **61032/UDP** sur ce routeur vers l'IP de la Freebox.

## Règles de filtrage VPN → Serveur MSI

Une fois connecté au VPN, l'accès au serveur MSI (IP : `192.168.1.50`) doit être autorisé pour les services suivants :

| Service | Port | Protocole |
|---|---|---|
| Bureau à distance (RDP) | 3389 | TCP |
| Partage de fichiers (SMB) | 445 | TCP |
| SSH (si applicable) | 22 | TCP |
| Ping | — | ICMP |

## Configuration Pare-feu Windows (serveur MSI)

Restreindre l'accès RDP et SMB au sous-réseau VPN uniquement (via PowerShell en tant qu'Administrateur) :

```powershell
# Autoriser RDP depuis le VPN uniquement
New-NetFirewallRule -DisplayName "RDP depuis VPN WireGuard" `
  -Direction Inbound -Protocol TCP -LocalPort 3389 `
  -RemoteAddress "10.0.0.0/8" -Action Allow

# Autoriser SMB depuis le VPN uniquement
New-NetFirewallRule -DisplayName "SMB depuis VPN WireGuard" `
  -Direction Inbound -Protocol TCP -LocalPort 445 `
  -RemoteAddress "10.0.0.0/8" -Action Allow

# Autoriser ICMP (ping) depuis le VPN
New-NetFirewallRule -DisplayName "Ping depuis VPN WireGuard" `
  -Direction Inbound -Protocol ICMPv4 `
  -RemoteAddress "10.0.0.0/8" -Action Allow
```

> Note : Adapter `10.0.0.0/8` au sous-réseau VPN réel indiqué dans le fichier `.conf` généré par la Freebox (champ `Address`).

## Paramètres MTU

MTU du tunnel WireGuard : **1360**

Si nécessaire, ajouter dans le fichier `.conf` client :
```ini
[Interface]
MTU = 1360
```
