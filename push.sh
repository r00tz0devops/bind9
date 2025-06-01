#!/bin/bash

# Variables
BACKUP_DIR="/mnt/dsm-mount/bindbackup"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
USER=$(whoami)
BACKUP_NAME="bind_backup_${USER}_${TIMESTAMP}.tar.gz"

# Create backup (tarball of current /etc/bind)
tar czf "${BACKUP_DIR}/${BACKUP_NAME}" -C /etc bind

echo "Backup created at ${BACKUP_DIR}/${BACKUP_NAME}"

# Stage all changes
git add .

# Commit with message listing changed files
git commit -m "Update: $(git diff --cached --name-only | paste -sd ',' -)"

# Rename branch to main if needed (optional, can be removed if already on main)
git branch -M main

# Push changes
git push -u origin main


#git add  .
#git commit -m "add Howto Folder"
#git commit -m "Update: $(git diff --cached --name-only | paste -sd ',' -)"
#git branch -M  main
#git push -u origin main


