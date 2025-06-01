#!/bin/bash

ZONES_DIR="/etc/bind/zones"
DATE=$(date +%Y%m%d)
USER=$(whoami)

echo "[INFO] Updating serials on: $(date) by user: $USER" >> /var/log/bind_serial_update.log

for zone in $(find $ZONES_DIR -type f -name "*.db"); do
  echo "[INFO] Checking $zone..." >> /var/log/bind_serial_update.log

  # Get current serial line
  ccurrent_serial=$(grep -oP '^\s*\d{10}(?=\s*;\s*Serial)' "$zone")

  if [[ -n "$current_serial" ]]; then
    base_serial=${current_serial:0:8}
    revision=${current_serial:8:2}

    if [[ "$base_serial" == "$DATE" ]]; then
      revision=$((revision + 1))
    else
      revision=01
    fi

    new_serial="${DATE}$(printf '%02d' $revision)"

    # Update file
    sed -i "s/$current_serial[[:space:]]*;[[:space:]]*Serial/$new_serial ; Serial/" "$zone"
    echo "[UPDATED] $zone: $current_serial -> $new_serial" >> /var/log/bind_serial_update.log
  else
    echo "[SKIPPED] $zone: No serial found." >> /var/log/bind_serial_update.log
  fi
done
