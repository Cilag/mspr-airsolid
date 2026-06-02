# Configuration VPN WireGuard — FreeboxOS

## Prérequis

- Accès admin FreeboxOS (http://mafreebox.freebox.fr)
- WireGuard for Windows installé sur le client (déjà fait ✓)
- IP locale du serveur MSI (à confirmer — supposée `192.168.1.50`)

## Paramètres serveur (déjà configurés)

| Paramètre | Valeur |
|---|---|
| Protocole | WireGuard |
| Port serveur | **61032/UDP** |
| MTU | **1360** |
| Statut | Activé ✓ |

## Étape 1 — Créer un utilisateur VPN WireGuard sur la Freebox

1. Connectez-vous à FreeboxOS → **Paramètres de la Freebox**
2. Naviguer : **Serveur VPN → WireGuard**
3. Le serveur est déjà **Activé** ✓
4. Cliquer **Utilisateurs** → **Ajouter un utilisateur**
5. Renseigner un nom (ex. `vpn-msi`) et valider
6. La Freebox génère automatiquement les clés et le fichier de configuration

## Étape 2 — Télécharger le profil client

**Option A — Fichier de configuration (recommandé pour PC) :**

1. Cliquer sur l'utilisateur créé
2. Cliquer **Télécharger le fichier de configuration** → fichier `.conf` généré

**Option B — QR Code (mobile uniquement) :**

1. Cliquer **Afficher le QR Code**
2. Scanner depuis l'application WireGuard mobile

## Étape 3 — Importer dans WireGuard for Windows

1. Ouvrir **WireGuard for Windows**
2. Cliquer **Import tunnel(s) from file**
3. Sélectionner le fichier `.conf` téléchargé
4. Le tunnel apparaît avec les paramètres :
   - **Endpoint** : `<IP_WAN_Freebox>:61032`
   - **MTU** : 1360

## Étape 4 — Activer le tunnel

1. Cliquer **Activate** dans WireGuard for Windows
2. Vérifier le statut : **Active** avec trafic entrant/sortant visible

## Étape 5 — Test de connectivité

### Depuis un réseau externe (partage 4G ou autre réseau)

```
ping 192.168.1.50
```

Accès RDP (Bureau à distance) :
```
mstsc /v:192.168.1.50
```

Résultat attendu : ping répond, Bureau à distance se connecte.

### Vérification côté Freebox

FreeboxOS → Serveur VPN → WireGuard → Utilisateurs → statut **Connecté** ✓

## Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| Tunnel ne s'active pas | Fichier .conf invalide | Régénérer depuis FreeboxOS |
| Ping timeout | Firewall Windows MSI | Vérifier règles PowerShell (voir `nat-firewall-rules.md`) |
| RDP échoue | Port 3389 bloqué | Ajouter règle RDP depuis 10.x.x.x/VPN |
| Endpoint injoignable | IP WAN dynamique | Vérifier DDNS ou IP WAN actuelle sur Freebox |
| MTU errors | Fragmentation | Forcer MTU 1360 dans le fichier .conf |
| Reconnexion lente | Keepalive absent | Ajouter `PersistentKeepalive = 25` dans .conf |
| Pas de trafic après connexion | Routes manquantes | Vérifier `AllowedIPs = 192.168.1.0/24` dans .conf |
