#!/bin/bash

# === Configuration ===
SOURCE="/path/to/source"
DESTINATION="/path/to/destination"
S3_BUCKET="s3://your-bucket-name"
EMAIL="luabikoye@yahoo.com"

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FOLDER="$DESTINATION/Backup_$TIMESTAMP"
LOG_FILE="/tmp/backup_log_$TIMESTAMP.txt"
START_TIME=$(date +%s)

# === Start Backup ===
{
    echo "Backup started at $(date)"
    mkdir -p "$BACKUP_FOLDER"

    if cp -r "$SOURCE"/* "$BACKUP_FOLDER"; then
        echo "Local backup completed successfully at $BACKUP_FOLDER"
    else
        echo "ERROR: Local backup failed."
        mail -s "Backup FAILED" "$EMAIL" < "$LOG_FILE"
        exit 1
    fi

    # Calculate backup stats
    BACKUP_SIZE=$(du -sh "$BACKUP_FOLDER" | cut -f1)
    FILE_COUNT=$(find "$BACKUP_FOLDER" -type f | wc -l)

    # === Push to S3 ===
    if aws s3 cp --recursive "$BACKUP_FOLDER" "$S3_BUCKET/Backup_$TIMESTAMP"; then
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        echo "Backup successfully uploaded to S3: $S3_BUCKET/Backup_$TIMESTAMP"
        echo ""
        echo "=== Backup Report ==="
        echo "Backup Size: $BACKUP_SIZE"
        echo "Number of Files: $FILE_COUNT"
        echo "Duration: ${DURATION}s"
        echo "Timestamp: $TIMESTAMP"
        mail -s "Backup SUCCESS - $TIMESTAMP" "$EMAIL" < "$LOG_FILE"
    else
        echo "ERROR: Upload to S3 failed."
        mail -s "Backup FAILED - S3 Upload" "$EMAIL" < "$LOG_FILE"
        exit 1
    fi

    echo "Backup finished at $(date)"
} | tee "$LOG_FILE"
§