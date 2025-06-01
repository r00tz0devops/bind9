#!/bin/bash

ZONES_SRC="/home/pablo/actions-runner/ns1Update/bind9/bind9/zones"
ZONES_DEST="/etc/bind/zones"
DATE=$(date +%Y%m%d)
USER=$(whoami)
LOG_FILE="/var/log/bind_serial_update.log"

echo "[INFO] Syncing fresh Git zone files to BIND zone directory..." >> "$LOG_FILE"
sudo cp "$ZONES_SRC"/*.db "$ZONES_DEST"/
sudo chown bind:bind "$ZONES_DEST"/*.db
sudo chmod 644 "$ZONES_DEST"/*.db

echo "[INFO] Updating serials on: $(date) by user: $USER" >> "$LOG_FILE"

# Update serials directly in the destination directory
for zone in "$ZONES_DEST"/*.db; do
  echo "[INFO] Checking $zone..." >> "$LOG_FILE"

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
    echo "[UPDATED] $zone: $current_serial -> $new_serial" >> "$LOG_FILE"
  else
    echo "[SKIPPED] $zone: No serial found." >> "$LOG_FILE"
  fi
done

echo "[INFO] Validating updated zones..." >> "$LOG_FILE"
for zone_file in "$ZONES_DEST"/*.db; do
  zone_name=$(basename "$zone_file" .db)
  if sudo named-checkzone "$zone_name" "$zone_file"; then
    echo "[VALID] $zone_name" >> "$LOG_FILE"
  else
    echo "[ERROR] Zone validation failed: $zone_name" >> "$LOG_FILE"
  fi
done

echo "[INFO] Reloading BIND..." >> "$LOG_FILE"
if sudo systemctl reload bind9; then
  echo "[SUCCESS] BIND reloaded." >> "$LOG_FILE"
else
  echo "[ERROR] Failed to reload BIND." >> "$LOG_FILE"
fi
