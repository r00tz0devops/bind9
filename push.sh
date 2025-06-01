#!/bin/bash

# === Variables ===
BACKUP_DIR="/mnt/dsm-mount/bindbackup"           # Directory where backups will be saved
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")                # Current date and time (YYYYMMDD-HHMMSS)
USER=$(whoami)                                    # Current user running the script
BACKUP_NAME="bind_backup_${USER}_${TIMESTAMP}.tar.gz"  # Backup filename with user and timestamp

# === Step 1: Create a backup of /etc/bind ===
# Using tar to archive and gzip compress the /etc/bind directory
tar czf "${BACKUP_DIR}/${BACKUP_NAME}" -C /etc bind
echo "Backup created at ${BACKUP_DIR}/${BACKUP_NAME}"

# === Step 2: Stage all changes in the Git repository ===
git add .
echo "Staged all changes for commit."

# === Step 3: Commit the staged changes ===
# Commit message lists all files that are staged for commit, separated by commas
git commit -m "Update: $(git diff --cached --name-only | paste -sd ',' -)"
echo "Committed changes with message describing updated files."

# === Step 4: Rename the current branch to 'main' ===
# This ensures the branch is named 'main' (optional if already on main)
git branch -M main
echo "Renamed branch to 'main' if it was not already."

# === Step 5: Push the changes to the remote repository ===
git push -u origin main
echo "Pushed commits to remote 'origin' on branch 'main'."
