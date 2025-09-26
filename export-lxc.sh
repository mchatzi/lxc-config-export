#!/bin/bash
# export-lxc.sh
# Usage: ./export-lxc.sh <backup-dir> [yaml-conf-file]

set -euo pipefail

# --- 1. Arguments & defaults ---
SCRIPT_DIR=$(dirname "$0")
BACKUP_DIR=${1:-""}
YAML_FILE=${2:-"$SCRIPT_DIR/conf.yml"}

if [[ -z "$BACKUP_DIR" ]]; then
    echo "Error: Backup directory must be provided as first argument."
    exit 1
fi

# --- 2. Check backup dir ---
if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "Backup directory does not exist"
    exit 1
fi

if [[ ! -w "$BACKUP_DIR" ]]; then
    echo "Error: Backup directory is not writable."
    exit 1
fi

# --- 1. Read YAML using Python ---
# Output format: lxc_id|path (lxc_id empty for local paths)
readarray -t BACKUP_ENTRIES < <(python3 - <<EOF
import yaml
with open("$YAML_FILE") as f:
    data = yaml.safe_load(f)
for entry in data.get('backups', []):
    lxc = str(entry.get('lxc', ''))
    path = entry.get('path')
    if path:
        print(f"{lxc}|{path}")
EOF 
)

if [[ ${#BACKUP_ENTRIES[@]} -eq 0 ]]; then
    echo "No backup entries found in $YAML_FILE"
    exit 1
fi

# --- 2. Perform backups ---
for entry in "${BACKUP_ENTRIES[@]}"; do
    IFS="|" read -r LXC_ID PATH_VAL <<< "$entry"

    DEST_NAME="$([[ -z "$LXC_ID" ]] && echo "local" || echo "$LXC_ID")"
    DEST_DIR="$BACKUP_DIR/$DEST_NAME"
    if [[ ! -d "$DEST_DIR" ]]; then``
        mkdir "$DEST_DIR"
    fi

    echo "Backing up $([[ -z "$LXC_ID" ]] && echo "local path" || echo "LXC $LXC_ID"), path '$PATH_VAL' → $DEST_DIR"

    if [[ -z "$LXC_ID" ]]; then
        # Local path
        tar czf - "$PATH_VAL" | tar xzf - -C "$DEST_DIR" --no-same-owner
    else
        # LXC path
        pct exec "$LXC_ID" -- tar czf - "$PATH_VAL" | tar xzf - -C "$DEST_DIR" --no-same-owner
    fi

    echo "Backup completed for $([[ -z "$LXC_ID" ]] && echo "local path" || echo "LXC $LXC_ID")"
done

echo "All backups done."
