# Guide client — Connexion VPN WireGuard

## Résumé

| Paramètre | Valeur |
|---|---|
| VPN | WireGuard (natif FreeboxOS) |
| Port | **61032/UDP** |
| MTU | **1360** |
| Client requis | WireGuard for Windows (déjà installé ✓) |

## Connexion pas-à-pas

### 1. Obtenir le fichier de configuration

Demander au responsable réseau (ou se connecter à FreeboxOS) :

- FreeboxOS → Serveur VPN → WireGuard → Utilisateurs → votre compte → **Télécharger la configuration**
- Le fichier `.conf` contient vos clés et l'endpoint de connexion

### 2. Importer dans WireGuard for Windows

1. Ouvrir **WireGuard** (icône dans la barre des tâches ou Menu Démarrer)
2. Cliquer **Import tunnel(s) from file**
3. Sélectionner le fichier `.conf`
4. Le tunnel apparaît dans la liste

### 3. Se connecter

1. Sélectionner le tunnel
2. Cliquer **Activate**
3. Statut : **Active** ✓ — vous êtes connecté au réseau local

### 4. Accéder au serveur MSI

| Accès | Commande / Application |
|---|---|
| Bureau à distance | Ouvrir **Connexion Bureau à distance** → `192.168.1.16` |
| Ping de test | `ping 192.168.1.16` dans un terminal |
| Partage réseau | `\\192.168.1.16\` dans l'Explorateur Windows |

> ⚠️ **IP à confirmer** : l'IP `192.168.1.16` est supposée. Vérifier avec l'administrateur si la connexion échoue.

### 5. Se déconnecter

Cliquer **Deactivate** dans WireGuard for Windows.

## IPs internes accessibles via VPN

| Hôte | IP | Services |
|---|---|---|
| Serveur MSI | `192.168.1.16` | RDP (3389), SMB (445), SSH (22) |
| Freebox / Gateway | `192.168.1.1` | FreeboxOS (admin) |

## Dépannage rapide

| Problème | Solution |
|---|---|
| Tunnel ne s'active pas | Vérifier connexion internet, réimporter le fichier .conf |
| Connecté mais serveur MSI inaccessible | Vérifier que le serveur MSI est allumé, IP correcte |
| Lenteur | Normal sur partage 4G — MTU 1360 déjà optimisé |
| Déconnexion fréquente | Ajouter `PersistentKeepalive = 25` dans le fichier .conf |

## Procédure de secours — Réactivation Tailscale

Si le VPN WireGuard ne fonctionne plus et qu'un accès distant urgent est nécessaire :

Voir `docs/tailscale/fallback-reactivation.md` — procédure de réactivation Tailscale en < 5 min.
