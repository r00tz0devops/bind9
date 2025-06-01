#!/bin/bash
set -e

# Usage: ./update_bind_zones.sh [-d|--dry-run] [-v|--verbose]

ZONES_SRC="/home/pablo/actions-runner/ns1Update/bind9/bind9/zones"
ZONES_DEST="/etc/bind/zones"
DATE=$(date +%Y%m%d)
USER=$(whoami)
LOG_FILE="/var/log/bind_serial_update.log"

DRY_RUN=0
VERBOSE=0

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dry-run)
      DRY_RUN=1
      shift
      ;;
    -v|--verbose)
      VERBOSE=1
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

log() {
  local msg="$1"
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $msg" >> "$LOG_FILE"
  if [[ $VERBOSE -eq 1 ]]; then
    echo "$msg"
  fi
}

run_cmd() {
  local cmd="$1"
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[DRY-RUN] $cmd"
  else
    log "[RUN] $cmd"
    eval "$cmd"
  fi
}

log "Starting BIND zone serial update by user: $USER"

for zone in "$ZONES_SRC"/*.db; do
  log "Processing $zone"

  current_serial=$(grep -oP '^\s*\d{10}(?=\s*;\s*Serial)' "$zone" || true)
  if [[ -z "$current_serial" ]]; then
    log "[WARN] No serial found in $zone, skipping."
    continue
  fi

  base_serial=${current_serial:0:8}
  revision=${current_serial:8:2}

  if [[ "$base_serial" == "$DATE" ]]; then
    revision=$((10#$revision + 1))
  else
    revision=1
  fi

  new_serial="${DATE}$(printf '%02d' "$revision")"

  if [[ $DRY_RUN -eq 0 ]]; then
    sed -i "s/$current_serial[[:space:]]*;[[:space:]]*Serial/$new_serial ; Serial/" "$zone"
  else
    log "[DRY-RUN] Would update serial $current_serial to $new_serial in $zone"
  fi

  log "Updated $zone: $current_serial -> $new_serial"

  zone_name=$(basename "$zone")
  zone_short=${zone_name%.db}

  # Validate zone
  if [[ $DRY_RUN -eq 0 ]]; then
    if ! named-checkzone "$zone_short" "$zone" >> "$LOG_FILE" 2>&1; then
      log "[ERROR] named-checkzone failed for $zone_short"
      exit 1
    fi
    log "named-checkzone passed for $zone_short"
  else
    log "[DRY-RUN] Would run named-checkzone for $zone_short"
  fi

  # Copy zone file to destination with correct ownership and permissions
  run_cmd "sudo cp \"$zone\" \"$ZONES_DEST/$zone_name\""
  run_cmd "sudo chown bind:bind \"$ZONES_DEST/$zone_name\""
  run_cmd "sudo chmod 644 \"$ZONES_DEST/$zone_name\""

  log "Synced $zone → $ZONES_DEST/$zone_name"
done

# Reload BIND
run_cmd "sudo systemctl reload bind9"
log "BIND reload complete."
