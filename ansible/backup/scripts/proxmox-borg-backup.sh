#!/bin/bash
# Backup orchestrator — runs on Proxmox host
# Backs up VM config + data to BorgBackup repo on VM203 (192.168.99.203)
# Called via cron on Proxmox host: 0 23 * * * /usr/local/bin/proxmox-borg-backup.sh
set -euo pipefail

BORG_REPO="borg@192.168.99.203:/var/backup/repos/proxmox-host"
BORG_RSH="ssh -i /root/.ssh/id_ed25519 -o StrictHostKeyChecking=yes"
LOG_FILE="/var/log/borg-backup-proxmox.log"
DATE="$(date '+%Y-%m-%dT%H:%M:%S')"
ARCHIVE="proxmox-host-${DATE}"

export BORG_RSH
# Passphrase: set in /etc/borg/passphrase or leave empty for unencrypted (lab)
export BORG_PASSPHRASE="${BORG_PASSPHRASE:-}"

echo "=== Backup Proxmox → VM203 ${DATE} ===" | tee -a "$LOG_FILE"

# Init repo if first run
if ! borg list "${BORG_REPO}" > /dev/null 2>&1; then
    echo "Initialisation du dépôt Borg..." | tee -a "$LOG_FILE"
    borg init --encryption=none "${BORG_REPO}" 2>&1 | tee -a "$LOG_FILE"
fi

# Backup Proxmox VM configs (VM201, VM202) and cluster config
echo "Sauvegarde des configs Proxmox (VM201, VM202)..." | tee -a "$LOG_FILE"
borg create \
    --verbose \
    --stats \
    --compression lz4 \
    "${BORG_REPO}::${ARCHIVE}" \
    /etc/pve/nodes/pve/qemu-server/201.conf \
    /etc/pve/nodes/pve/qemu-server/202.conf \
    /etc/pve/nodes/pve/qemu-server/203.conf \
    /etc/pve/storage.cfg \
    /etc/network/interfaces \
    /etc/pve/firewall/ \
    2>&1 | tee -a "$LOG_FILE"

# Prune: keep 7 daily, 4 weekly, 6 monthly
borg prune \
    --verbose \
    --stats \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 6 \
    --glob-archives "proxmox-host-*" \
    "${BORG_REPO}" 2>&1 | tee -a "$LOG_FILE"

echo "=== Backup terminé $(date '+%Y-%m-%dT%H:%M:%S') ===" | tee -a "$LOG_FILE"
