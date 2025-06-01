#!/bin/bash

ZONES_DIR="/etc/bind/zones"
DATE=$(date +%Y%m%d)
USER=$(whoami)
LOGFILE="/var/log/bind_serial_update.log"

echo "[INFO] Updating serials on: $(date) by user: $USER" >> "$LOGFILE"

for zone in $(find "$ZONES_DIR" -type f -name "*.db"); do
  echo "[INFO] Checking $zone..." >> "$LOGFILE"

  # Extract current serial number from zone file
  current_serial=$(grep -oP '^\s*\d{10}(?=\s*;\s*Serial)' "$zone")

  if [[ -n "$current_serial" ]]; then
    base_serial=${current_serial:0:8}
    revision=${current_serial:8:2}

    if [[ "$base_serial" == "$DATE" ]]; then
      revision=$((10#$revision + 1))   # Use 10# to force decimal interpretation
    else
      revision=1
    fi

    new_serial="${DATE}$(printf '%02d' $revision)"

    # Update serial in zone file
    sed -i "s/$current_serial[[:space:]]*;[[:space:]]*Serial/$new_serial ; Serial/" "$zone"
    echo "[UPDATED] $zone: $current_serial -> $new_serial" >> "$LOGFILE"

    # Run named-checkzone on the zone
    zone_name=$(basename "$zone" .db)
    if sudo named-checkzone "$zone_name" "$zone" >> "$LOGFILE" 2>&1; then
      echo "[CHECKZONE] $zone_name: syntax OK" >> "$LOGFILE"
    else
      echo "[CHECKZONE] $zone_name: syntax ERROR - skipping reload" >> "$LOGFILE"
      echo "[ERROR] Serial update script aborted due to syntax error in $zone" >> "$LOGFILE"
      exit 1
    fi

  else
    echo "[SKIPPED] $zone: No serial found." >> "$LOGFILE"
  fi
done

# Reload BIND service only if all zones passed checks
echo "[INFO] Reloading BIND service..." >> "$LOGFILE"
if sudo systemctl reload bind9 >> "$LOGFILE" 2>&1; then
  echo "[INFO] BIND reloaded successfully" >> "$LOGFILE"
else
  echo "[ERROR] Failed to reload BIND service" >> "$LOGFILE"
  exit 1
fi
