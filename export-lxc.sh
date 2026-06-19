#!/bin/bash
# export-lxc.sh
# Usage: ./export-lxc.sh <backup-dir> [yaml-conf-file]

set -euo pipefail

# --- 1. Arguments & defaults ---
SCRIPT_DIR=$(dirname "$0")
BACKUP_DIR=${1:-""}
YAML_FILE=${2:-"$SCRIPT_DIR/conf.yml"}

#YOU NEED ONE PER PROXMOX HOST
UPTIMEKUMA_PUSH_URL="http://uptimekuma-mnx.home:3001/api/push/USxWhT3CZk"


fatal() {
    local msg="$1"
    echo "ERROR: $msg" >&2  #Log to stderr
    notify_uptimekuma "down" "[$(hostname)] $msg"
    exit 1
}

notify_uptimekuma() {
    local status="$1"
    local msg="$2"

    # Notify Uptime Kuma (don't let notification failure stop the script)
    curl -fsS -G \
        --data-urlencode "status=$status" \
        --data-urlencode "msg=$msg" \
        "$UPTIMEKUMA_PUSH_URL" \
        >/dev/null 2>&1 || true
}

if [[ -z "$BACKUP_DIR" ]]; then
    fatal "Backup directory must be provided as first argument."
fi

# --- 2. Check backup dir ---
if [[ ! -d "$BACKUP_DIR" ]]; then
    fatal "Backup directory does not exist"
fi

if [[ ! -w "$BACKUP_DIR" ]]; then
    fatal "Backup directory is not writable."
fi

# --- 1. Read YAML using Python ---
# Output format: lxc_id|path (lxc_id empty for local paths)
PYTHON_OUTPUT=$(
python3 - <<EOF
import sys,yaml
try:
    with open("$YAML_FILE") as f:
        data = yaml.safe_load(f) or {}
except Exception as e:
    print(f"YAML error: {e}", file=sys.stderr)
    sys.exit(1)

for entry in data.get('backups', []):
    lxc = str(entry.get('lxc', ''))
    path = entry.get('path')
    if path:
        print(f"{lxc}|{path}")
EOF
) || fatal "Failed to parse $YAML_FILE"

readarray -t BACKUP_ENTRIES <<< "$PYTHON_OUTPUT"

if [[ ${#BACKUP_ENTRIES[@]} -eq 0 ]]; then
    fatal "No backup entries found in $YAML_FILE"
fi

# --- 2. Perform backups ---
set +e
for entry in "${BACKUP_ENTRIES[@]}"; do
    IFS="|" read -r LXC_ID PATH_VAL <<< "$entry"

    DEST_NAME="$([[ -z "$LXC_ID" ]] && echo "local" || echo "$LXC_ID")"
    DEST_DIR="$BACKUP_DIR/$DEST_NAME"
    if [[ ! -d "$DEST_DIR" ]]; then
        mkdir "$DEST_DIR"
    fi

    echo "Backing up $([[ -z "$LXC_ID" ]] && echo "local path" || echo "LXC $LXC_ID"), path '$PATH_VAL' → $DEST_DIR"

    if [[ -z "$LXC_ID" ]]; then
        # Local path
        tar czf - "$PATH_VAL" | tar xzf - -C "$DEST_DIR" --no-same-owner
    else
        # LXC path
        if ! pct status "$LXC_ID" | grep -q "status: running"; then
            echo -e "❌ Container $LXC_ID is not running, skipping...\n"
            continue
        fi
        pct exec "$LXC_ID" -- tar czf - "$PATH_VAL" | tar xzf - -C "$DEST_DIR" --no-same-owner
    fi

    chmod -R u=rwX,g=rX,o=rX "$DEST_DIR"

    echo -e "✔️ Backup completed for $([[ -z "$LXC_ID" ]] && echo "local path" || echo "LXC $LXC_ID")\n"
done

echo "LXC configs export finished"
notify_uptimekuma "up" "LXC configs ($(hostname)) export finished"

