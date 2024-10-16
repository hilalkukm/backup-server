#!/bin/bash

# A function to handle errors
handle_error() {
    echo "An error occurred. Exiting..."
    exit 1
}

# Trap any error
trap 'handle_error' ERR

# Ask what content/directory to back up
echo "Enter the full path of the directory you want to back up (e.g., $HOME/myfolder):"
read DIRECTORY_TO_BACKUP

# Check if the user input is empty
if [ -z "$DIRECTORY_TO_BACKUP" ]; then
    echo "No directory selected. Exiting."
    exit 1
fi

# Confirm the directory selection
echo "You have selected to backup: $DIRECTORY_TO_BACKUP. Proceed? (yes/no)"
read CONFIRMATION

if [ "$CONFIRMATION" != "yes" ]; then
    echo "Backup operation cancelled."
    exit 0
fi

# Step execution: Backup the directory
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
HOSTNAME=$(hostname)
BACKUP_FILE="$(basename "$DIRECTORY_TO_BACKUP")_${HOSTNAME}_$TIMESTAMP.tar.gz"

# Perform the backup in the current working directory
tar -czvf "$PWD/$BACKUP_FILE" -C "$(dirname "$DIRECTORY_TO_BACKUP")" "$(basename "$DIRECTORY_TO_BACKUP")"

# Notify the user of successful backup
echo "Backup completed successfully. File saved as $PWD/$BACKUP_FILE."
