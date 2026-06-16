#!/bin/bash
# Backup orchestrator — runs on Proxmox host (root cron)
# Backs up VM201/VM202/VM203 Proxmox configs to BorgBackup repo on VM203
# Deployed: crontab -e → 5 23 * * * /usr/local/bin/proxmox-borg-backup.sh
# First execution: 2026-06-16T21:29:35 — archive proxmox-config-2026-06-16T212934
set -euo pipefail

BORG_REPO="borg@192.168.99.203:/var/backup/repos/proxmox-host"
LOG_FILE="/var/log/borg-backup-proxmox.log"
DATE="$(date '+%Y-%m-%dT%H%M%S')"
ARCHIVE="proxmox-config-${DATE}"

# Unencrypted repo (lab environment — enable repokey encryption for production)
export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes

echo "=== Backup Proxmox → VM203 ${DATE} ===" | tee -a "$LOG_FILE"

# Init repo on first run
if ! borg list "${BORG_REPO}" > /dev/null 2>&1; then
    echo "Initialisation du dépôt Borg..." | tee -a "$LOG_FILE"
    borg init --encryption=none "${BORG_REPO}" 2>&1 | tee -a "$LOG_FILE"
fi

# Backup VM201 and VM202 Proxmox configs + cluster essentials
echo "Sauvegarde des configs VM201/VM202 + infrastructure..." | tee -a "$LOG_FILE"
borg create \
    --compression lz4 \
    "${BORG_REPO}::${ARCHIVE}" \
    /etc/pve/nodes/pve/qemu-server/201.conf \
    /etc/pve/nodes/pve/qemu-server/202.conf \
    /etc/pve/nodes/pve/qemu-server/203.conf \
    /etc/pve/storage.cfg \
    /etc/network/interfaces \
    2>&1 | tee -a "$LOG_FILE"

BACKUP_EXIT=$?

# Prune: rétention 7j / 4sem / 6mois
borg prune \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 6 \
    --glob-archives "proxmox-config-*" \
    "${BORG_REPO}" 2>&1 | tee -a "$LOG_FILE"

echo "=== Terminé (exit: ${BACKUP_EXIT}) ===" | tee -a "$LOG_FILE"
exit $BACKUP_EXIT
