#!/bin/bash

# === Variables ===
BACKUP_DIR="/mnt/dsm-mount/bindbackup"           
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")             # More readable timestamp for log
USER=$(whoami)                                    
BACKUP_NAME="bind_backup_${USER}_$(date +%Y%m%d-%H%M%S).tar.gz"
LOG_FILE="/etc/bind/backup_log.txt"                # File to append backup notes

# === Step 1: Create a backup of /etc/bind ===
tar czf "${BACKUP_DIR}/${BACKUP_NAME}" -C /etc bind
echo "Backup created at ${BACKUP_DIR}/${BACKUP_NAME}"

# === Step 1a: Append backup info as comment to backup_log.txt ===
echo "# Backup created on ${TIMESTAMP} by user ${USER}" >> "${LOG_FILE}"
echo "# Backup file location: ${BACKUP_DIR}/${BACKUP_NAME}" >> "${LOG_FILE}"
echo "" >> "${LOG_FILE}"

echo "Backup note appended to ${LOG_FILE}"

# === Step 2: Stage all changes in the Git repository ===
git add .
echo "Staged all changes for commit."

# === Step 3: Commit the staged changes ===
git commit -m "Update: $(git diff --cached --name-only | paste -sd ',' -)"
echo "Committed changes with message describing updated files."

# === Step 4: Rename the current branch to 'main' ===
git branch -M main
echo "Renamed branch to 'main' if it was not already."

# === Step 5: Push the changes to the remote repository ===
git push -u origin main
echo "Pushed commits to remote 'origin' on branch 'main'."
