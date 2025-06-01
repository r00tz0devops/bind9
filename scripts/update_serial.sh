#!/bin/bash

ZONES_SRC="/home/pablo/actions-runner/ns1Update/bind9/bind9/zones"
ZONES_DEST="/etc/bind/zones"
DATE=$(date +%Y%m%d)
LOG_FILE="/var/log/bind_serial_update.log"
DOMAIN="r00tz0.xyz"

echo "[INFO] Starting zone sync and reload at $(date)" | tee -a "$LOG_FILE"

# Step 1: Update serials
for zone in "$ZONES_SRC"/*.db; do
  echo "[INFO] Checking $zone..." | tee -a "$LOG_FILE"

  current_serial=$(grep -oP '^\s*\d{10}(?=\s*;\s*Serial)' "$zone")
  if [[ -n "$current_serial" ]]; then
    base_serial=${current_serial:0:8}
    revision=${current_serial:8:2}
    if [[ "$base_serial" == "$DATE" ]]; then
      revision=$((revision + 1))
    else
      revision=01
    fi
    new_serial="${DATE}$(printf '%02d' $revision)"
    sed -i "s/$current_serial[[:space:]]*;[[:space:]]*Serial/$new_serial ; Serial/" "$zone"
    echo "[UPDATED] $zone: $current_serial -> $new_serial" | tee -a "$LOG_FILE"
  else
    echo "[SKIPPED] $zone: No serial found." | tee -a "$LOG_FILE"
  fi
done

# Step 2: Validate all zones
valid=true
for zonefile in "$ZONES_SRC"/*.db; do
  zonename=$(basename "$zonefile" .db)
  echo "[CHECK] Validating $zonename..."
  if ! sudo named-checkzone "$zonename" "$zonefile"; then
    echo "[ERROR] Zone validation failed for $zonename" | tee -a "$LOG_FILE"
    valid=false
  fi
done

if ! $valid; then
  echo "[FATAL] One or more zone files failed validation. Aborting sync and reload." | tee -a "$LOG_FILE"
  exit 1
fi

# Step 3: Sync zones
sudo rsync -av --delete "$ZONES_SRC/" "$ZONES_DEST/"
sudo chown bind:bind "$ZONES_DEST"/*.db
sudo chmod 644 "$ZONES_DEST"/*.db
echo "[INFO] Zone files copied to $ZONES_DEST" | tee -a "$LOG_FILE"

# Step 4: Reload bind9
echo "[INFO] Reloading bind9..." | tee -a "$LOG_FILE"
if sudo systemctl reload bind9; then
  echo "[SUCCESS] BIND reloaded successfully." | tee -a "$LOG_FILE"
else
  echo "[ERROR] Failed to reload BIND." | tee -a "$LOG_FILE"
  exit 2
fi

echo "[DONE] Zone update completed at $(date)" | tee -a "$LOG_FILE"
