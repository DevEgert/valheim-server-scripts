#!/bin/bash
# Daily Valheim world backup.
# Archives the world folder to a tar.gz and keeps the last 7 days.
# Run as root (via /etc/cron.d/valheim-backup).

set -euo pipefail

WORLD_NAME="MyWorld"                                                   # folder name under worlds_local
SRC="/home/steam/.config/unity3d/IronGate/Valheim/worlds_local"        # Valheim 1.0+ save location
DEST="/home/youruser/valheim-backups"                                  # where archives go
OWNER="youruser"                                                       # user that pulls backups via scp
KEEP_DAYS=7

mkdir -p "$DEST"

tar -czf "$DEST/valheim-$(date +%F).tar.gz" -C "$SRC" "$WORLD_NAME"

# Let the non-root user read the archives so the PC can pull them over scp
chown -R "$OWNER:$OWNER" "$DEST"

# Rotate: delete archives older than KEEP_DAYS
find "$DEST" -name 'valheim-*.tar.gz' -mtime +"$KEEP_DAYS" -delete
