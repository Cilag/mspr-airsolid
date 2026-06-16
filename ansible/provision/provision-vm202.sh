#!/usr/bin/env bash
# [GUI-235] Provision VM202 airsolid-erp on Proxmox with Debian 12 via cloud-init
# Usage: ./provision-vm202.sh
# Run from the Proxmox node OR with PROXMOX_HOST env var set (executes via SSH)
set -euo pipefail

VMID=202
VM_NAME="airsolid-erp"
RAM_MB=4096
DISK_SIZE="50G"
BRIDGE="vmbr99"
IP="192.168.99.202/24"
HOSTNAME="airsolid-erp"
ANSIBLE_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBfGH/3jWeB2ZsuDAeLUjGVO4lvwy1PdsyMJ57dJ8Sa7 paperclip-agents@homeassistant"

CLOUD_IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
CLOUD_IMAGE_LOCAL="/var/lib/vz/template/iso/debian-12-genericcloud-amd64.qcow2"
STORAGE="local-lvm"

log() { echo "[$(date -u '+%H:%M:%S')] $*"; }

# ── 1. Download cloud image if not present ────────────────────────────────────
if [[ ! -f "$CLOUD_IMAGE_LOCAL" ]]; then
    log "Downloading Debian 12 genericcloud image..."
    wget -q --show-progress -O "$CLOUD_IMAGE_LOCAL" "$CLOUD_IMAGE_URL"
    log "Download complete: $(du -sh "$CLOUD_IMAGE_LOCAL" | cut -f1)"
else
    log "Cloud image already present: $CLOUD_IMAGE_LOCAL"
fi

# ── 2. Stop VM if running ─────────────────────────────────────────────────────
VM_STATUS=$(pvesh get /nodes/pve/qemu/${VMID}/status/current --output-format json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])' 2>/dev/null || echo "unknown")
if [[ "$VM_STATUS" == "running" ]]; then
    log "Stopping VM${VMID}..."
    qm stop "$VMID" --timeout 30
fi

# ── 3. Detach and remove the existing empty disk ──────────────────────────────
log "Detaching existing disk scsi0 from VM${VMID}..."
pvesh set /nodes/pve/qemu/${VMID}/config --delete scsi0 2>/dev/null || true
pvesh set /nodes/pve/qemu/${VMID}/config --delete ide2 2>/dev/null || true
# Remove old LV if it still exists
lvremove -f pve/vm-${VMID}-disk-0 2>/dev/null && log "Removed old vm-${VMID}-disk-0 LV" || true

# ── 4. Import cloud image as scsi0 ───────────────────────────────────────────
log "Importing cloud image into ${STORAGE} as VM${VMID} disk..."
IMPORT_OUT=$(qm importdisk "$VMID" "$CLOUD_IMAGE_LOCAL" "$STORAGE" --format raw 2>&1)
log "$IMPORT_OUT"
# The imported disk will be unused0 or similar; detect it
UNUSED=$(pvesh get /nodes/pve/qemu/${VMID}/config --output-format json | python3 -c 'import json,sys; cfg=json.load(sys.stdin); keys=[k for k in cfg if k.startswith("unused")]; print(keys[0] if keys else "")' 2>/dev/null)
if [[ -z "$UNUSED" ]]; then
    log "ERROR: Could not find imported disk. Aborting."
    exit 1
fi
DISK_VOL=$(pvesh get /nodes/pve/qemu/${VMID}/config --output-format json | python3 -c "import json,sys; print(json.load(sys.stdin).get('${UNUSED}',''))")
log "Imported disk: $UNUSED => $DISK_VOL"

# ── 5. Attach disk as scsi0, add cloud-init drive, configure ─────────────────
log "Attaching disk as scsi0..."
pvesh set /nodes/pve/qemu/${VMID}/config \
    --scsi0 "${DISK_VOL},aio=io_uring,cache=none,discard=on" \
    --ide2 "${STORAGE}:cloudinit" \
    --boot "order=scsi0" \
    --ostype l26 \
    --agent enabled=1,fstrim_cloned_disks=1

# ── 6. Resize disk to 50G ─────────────────────────────────────────────────────
log "Resizing disk to ${DISK_SIZE}..."
pvesh set /nodes/pve/qemu/${VMID}/resize --disk scsi0 --size "$DISK_SIZE"

# ── 7. Configure cloud-init ───────────────────────────────────────────────────
log "Configuring cloud-init (IP: ${IP}, user: ansible)..."
pvesh set /nodes/pve/qemu/${VMID}/config \
    --ciuser ansible \
    --sshkeys "$(python3 -c "import urllib.parse; print(urllib.parse.quote('${ANSIBLE_PUBKEY}', safe=''))")" \
    --ipconfig0 "ip=${IP}" \
    --nameserver "192.168.99.1" \
    --searchdomain "airsolid.local" \
    --citype nocloud

# Also set hostname via cicustom if supported, or rely on default (VM name)
pvesh set /nodes/pve/qemu/${VMID}/config \
    --name "$HOSTNAME"

# ── 8. Start VM ───────────────────────────────────────────────────────────────
log "Starting VM${VMID}..."
qm start "$VMID"

# ── 9. Wait for SSH ───────────────────────────────────────────────────────────
TARGET_IP="${IP%%/*}"
log "Waiting for SSH on ${TARGET_IP}:22 (timeout 3 min)..."
for i in $(seq 1 36); do
    if nc -z -w2 "$TARGET_IP" 22 2>/dev/null; then
        log "SSH is up on ${TARGET_IP}!"
        break
    fi
    if [[ "$i" -eq 36 ]]; then
        log "WARNING: SSH not yet reachable after 3 minutes — VM may still be booting."
        exit 0
    fi
    sleep 5
done

log "VM${VMID} provisioning complete. SSH: ansible@${TARGET_IP}"
