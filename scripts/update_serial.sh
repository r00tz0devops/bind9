#!/bin/bash
set -xe  # Debug: show commands and exit on error

ZONES_SRC="/home/pablo/actions-runner/ns1Update/bind9/bind9/zones"
ZONES_DEST="/etc/bind/zones"
DATE=$(date +%Y%m%d)
USER=$(whoami)
LOG_FILE="/var/log/bind_serial_update.log"

echo "[INFO] Starting BIND zone serial update on $(date) by user: $USER" >> "$LOG_FILE"
echo "[INFO] Source zone path: $ZONES_SRC" >> "$LOG_FILE"
echo "[INFO] Destination zone path: $ZONES_DEST" >> "$LOG_FILE"
ls -l "$ZONES_SRC" >> "$LOG_FILE"

# Update serial numbers in zone files
for zone in "$ZONES_SRC"/*.db; do
  echo "[INFO] Checking $zone..." >> "$LOG_FILE"
  
  current_serial=$(grep -oP '^\s*\d{10}(?=\s*;\s*Serial)' "$zone")

  if [[ -n "$current_serial" ]]; then
    base_serial=${current_serial:0:8}
    revision=${current_serial:8:2}

    if [[ "$base_serial" == "$DATE" ]]; then
      revision=$((10#$revision + 1))  # handle leading zeros properly
    else
      revision=1
    fi

    new_serial="${DATE}$(printf '%02d' "$revision")"
    sed -i "s/$current_serial[[:space:]]*;[[:space:]]*Serial/$new_serial ; Serial/" "$zone"
    echo "[UPDATED] $zone: $current_serial -> $new_serial" >> "$LOG_FILE"
  else
    echo "[SKIPPED] $zone: No serial found." >> "$LOG_FILE"
  fi
done

# Ensure all zone files end with a newline
for zone_file in "$ZONES_SRC"/*.db; do
  if [[ -f "$zone_file" ]] && [[ $(tail -c1 "$zone_file" | wc -l) -eq 0 ]]; then
    echo >> "$zone_file"
    echo "[FIXED] Added newline to end of $zone_file" >> "$LOG_FILE"
  fi
done

# Validate zone files and copy to destination
echo "[INFO] Validating and syncing zones..." >> "$LOG_FILE"
validation_failed=0

for zone_file in "$ZONES_SRC"/*.db; do
  zone_name=$(basename "$zone_file")
  zone_short=${zone_name%.db}

  echo "[VALIDATING] Zone file: $zone_name as $zone_short" >> "$LOG_FILE"
  if named-checkzone "$zone_short" "$zone_file" >> "$LOG_FILE" 2>&1; then
    echo "[VALID] $zone_name" >> "$LOG_FILE"
    cp "$zone_file" "$ZONES_DEST/$zone_name"
    chown bind:bind "$ZONES_DEST/$zone_name"
    chmod 644 "$ZONES_DEST/$zone_name"
    echo "[SYNCED] $zone_file → $ZONES_DEST/$zone_name" >> "$LOG_FILE"
  else
    echo "[ERROR] Zone validation failed: $zone_name" >> "$LOG_FILE"
    validation_failed=1
  fi
done

# Reload BIND only if all validations passed
if [[ $validation_failed -eq 0 ]]; then
  echo "[INFO] Reloading BIND..." >> "$LOG_FILE"
  if systemctl reload bind9 >> "$LOG_FILE" 2>&1; then
    echo "[SUCCESS] BIND reloaded." >> "$LOG_FILE"
  else
    echo "[ERROR] Failed to reload BIND." >> "$LOG_FILE"
  fi
else
  echo "[ERROR] Not reloading BIND due to validation failures." >> "$LOG_FILE"
fi
