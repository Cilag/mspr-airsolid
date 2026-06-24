# Réseau VLAN Enterprise — AIRSOLID PHASE 1

**Date d'exécution :** 2026-06-17  
**Issue :** [GUI-237](/GUI/issues/GUI-237)  
**Proxmox :** 192.168.1.100  
**Statut :** DÉPLOYÉ ✓

---

## Architecture réseau

```
Internet
    │
    └─ 192.168.1.1 (gateway LAN)
          │
          └─ 192.168.1.100 (Proxmox pve)
                │
                ├─ vmbr0 (bridge LAN physique — JAMAIS modifier)
                │     ├─ 192.168.1.100/24  ← mgmt host
                │     └─ tap VM201(net1), tap VM202(net1)
                │
                └─ vmbr99 (bridge VLAN-aware, aucun uplink physique)
                      ├─ vmbr99.10 → 10.0.10.254/24  (SVI rescue)
                      ├─ tap VM201(net0), tap VM202(net0), tap VM203(net0)  ← VLAN 1 untagged
                      └─ tap fw01(net1)  ← trunk (toutes VLANs)
```

## Bridges Proxmox

### vmbr0 — Management LAN (NE PAS TOUCHER)
- Bridge physique sur nic1
- IP host : 192.168.1.100/24, gw 192.168.1.1
- VMs : 201(net1), 202(net1)

### vmbr99 — Réseau interne VLAN-aware
- `bridge-vlan-aware yes`
- `bridge-vids 2-4094`
- Pas d'uplink physique (interne uniquement)
- SVI de secours : `vmbr99.10` → 10.0.10.254/24 (accès mgmt depuis Proxmox)
- VMs existantes 201/202/203 : VLAN 1 untagged (PVID 1)
- fw01 net1 : trunk (toutes VLANs tagged)

## VM fw01 — Routeur/Pare-feu Linux

| Paramètre   | Valeur                          |
|-------------|----------------------------------|
| VMID        | 208                              |
| Nom         | fw01                             |
| OS          | Debian 12 (cloud image)          |
| vCPU        | 1                                |
| RAM         | 1 Go                             |
| Disque      | 10 Go (local-lvm)                |
| net0 (eth0) | vmbr0 → 192.168.1.208/24 (WAN)  |
| net1 (eth1) | vmbr99 → trunk (toutes VLANs)   |

## Plan d'adressage VLAN

| VLAN | Interface fw01 | Réseau         | Gateway      | Usage               |
|------|---------------|----------------|--------------|---------------------|
| 10   | eth1.10       | 10.0.10.0/24   | 10.0.10.1    | Serveurs/Office LAN |
| 20   | eth1.20       | 10.0.20.0/24   | 10.0.20.1    | Postes de travail   |
| 30   | eth1.30       | 10.0.30.0/24   | 10.0.30.1    | IoT/DMZ             |
| 99   | eth1.99       | 10.0.99.0/24   | 10.0.99.1    | Management          |
| —    | SVI vmbr99.10 | 10.0.10.254/24 | (Proxmox)    | Accès secours host  |

## Matrice de filtrage nftables

| Source  | Destination | Ports autorisés                        | Commentaire               |
|---------|------------|----------------------------------------|---------------------------|
| VLAN20  | VLAN10     | TCP 139, 389, 443, 445, 636            | Workstations → Serveurs   |
| VLAN30  | VLAN10     | TCP 139, 389, 443, 445, 636            | IoT → Serveurs (isolé V20)|
| VLAN20  | VLAN30     | Interdit                               | Isolation IoT             |
| VLAN30  | VLAN20     | Interdit                               | Isolation IoT             |
| VLAN99  | Tout       | Tout (management)                      | Whitelist mgmt            |
| Tout    | WAN        | Masquerade (sortie internet)           | NAT via eth0              |
| wg0     | Tout       | Tout                                   | VPN tunnelé               |

## Services sur fw01

### IP Forwarding
```
/etc/sysctl.d/99-fw01.conf:
  net.ipv4.ip_forward=1
  net.ipv4.conf.all.rp_filter=0
```

### nftables (`/etc/nftables.conf`)
- Table `inet fw01`
- Chains : forward (drop policy), input (drop policy), output (accept), postrouting (nat)
- Masquerade activé sur eth0 (WAN)

### dnsmasq DHCP
- VLAN 20 : plage 10.0.20.100–200, gw 10.0.20.1
- VLAN 30 : plage 10.0.30.100–200, gw 10.0.30.1
- DNS upstream : 1.1.1.1, 8.8.8.8

### WireGuard (`wg0`)
- Interface : wg0
- Réseau VPN : 10.10.0.0/24
- Écoute : UDP 51820
- Clé publique serveur : `jWJ4zaX8uKX+JTFAv+CWPcn9qHotytubawTXwtIXW3g=`
- Capacité : jusqu'à 30 pairs
- Config : `/etc/wireguard/wg0.conf`

## DoD — Preuves de fonctionnement

```
# ping 10.0.10.1 (gateway VLAN10 sur fw01)
PING 10.0.10.1: 2 packets transmitted, 2 received, 0% packet loss

# nft list ruleset — table inet fw01 chargée avec toutes les règles

# wg show
interface: wg0
  public key: jWJ4zaX8uKX+JTFAv+CWPcn9qHotytubawTXwtIXW3g=
  listening port: 51820

# cat /etc/network/interfaces — eth1.10/.20/.30/.99 configurés

# VMs 201/202/203 : toujours running, pong 192.168.1.201 OK
```

## Contraintes respectées

- ✓ vmbr0 non modifié (192.168.1.100 intact)
- ✓ VMs 201/202/203 non migrées, toujours running
- ✓ VLAN-aware activé sur vmbr99 seulement
- ✓ SVI secours vmbr99.10=10.0.10.254/24 opérationnel
- ✓ VMID 208 (fw01) non conflictuel

## Accès SSH fw01

```bash
# Via Proxmox jump host
ssh -J root@192.168.1.100 root@192.168.1.208

# Ou directement depuis le LAN
ssh root@192.168.1.208
```

## Étapes suivantes (PHASE 2)

- Créer VMs 204 (FILE), 205 (MON), 206 (AD-REP), 207 (PBS)
- Connecter ces VMs sur vmbr99 avec tags VLAN appropriés
- Migration VMs 201/202/203 vers VLAN10 (PHASE 3, EN DERNIER)
