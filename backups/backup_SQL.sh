#!/bin/bash

# === Configuration ===
DB_USER="garesplace"
DB_PASS="Garesplace@1972!"
DB_NAME="garesplace"
DESTINATION="/var/www/db_backups"
S3_BUCKET="s3://aledoy-backups"
EMAIL="luabikoye@yahoo.com"

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="$DESTINATION/${DB_NAME}_Backup_$TIMESTAMP.sql.gz"
LOG_FILE="/tmp/db_backup_log_$TIMESTAMP.txt"
START_TIME=$(date +%s)

# === Start Backup ===
{
    echo "MySQL Backup started at $(date)"

    mkdir -p "$DESTINATION"

    # Dump and compress the database
    if sudo mysqldump -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" | gzip > "$BACKUP_FILE"; then
        echo "Local DB backup completed successfully: $BACKUP_FILE"
    else
        echo "ERROR: Local DB backup failed."
        mail -s "MySQL Backup FAILED" "$EMAIL" < "$LOG_FILE"
        exit 1
    fi

    # Calculate backup stats
    BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    # === Push to S3 ===
    if aws s3 cp "$BACKUP_FILE" "$S3_BUCKET/${DB_NAME}_Backup_$TIMESTAMP.sql.gz"; then
        echo ""
        echo "=== MySQL Backup Report ==="
        echo "Database: $DB_NAME"
        echo "Backup File: $BACKUP_FILE"
        echo "Backup Size: $BACKUP_SIZE"
        echo "Duration: ${DURATION}s"
        echo "Timestamp: $TIMESTAMP"
        mail -s "MySQL Backup SUCCESS - $TIMESTAMP" "$EMAIL" < "$LOG_FILE"
    else
        echo "ERROR: Upload to S3 failed."
        mail -s "MySQL Backup FAILED - S3 Upload" "$EMAIL" < "$LOG_FILE"
        exit 1
    fi

    #Remove backup file to free space from server
    rm -rf $BACKUP_FILE
    echo "MySQL Backup finished at $(date)"
} | tee "$LOG_FILE"
