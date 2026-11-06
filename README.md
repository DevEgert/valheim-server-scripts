# Valheim Server Scripts

Backup and restart automation for a self-hosted Valheim dedicated server on Ubuntu 24.04 (SteamCMD + BepInEx), with off-site copies pulled to a Windows PC.

I run a modded Valheim server for friends on a VPS. These are the scripts and systemd units that keep it running without babysitting: a clean daily restart, a daily world backup on the server, and a nightly pull of those backups to my home PC.

## What it does

| Job | Where | When | How |
|---|---|---|---|
| World backup | VPS | 05:00 daily | cron → `valheim-backup.sh` → `tar.gz`, keeps 7 days |
| Server restart | VPS | 08:00 daily | systemd timer → `systemctl restart valheim` |
| Off-site copy | Windows PC | 21:00 daily | Task Scheduler → `scp` from VPS, keeps everything |
| Crash recovery | VPS | on failure | `Restart=on-failure` in `valheim.service` |

```
VPS (Ubuntu)                                       Home PC (Windows)
┌──────────────────────────────────────────┐       ┌──────────────────────────┐
│ valheim.service  (steam user, BepInEx)   │       │                          │
│   ▲ restart 08:00                        │       │  Task Scheduler 21:00    │
│ valheim-restart.timer                    │       │   scp -B ...             │
│                                          │  scp  │   ▼                      │
│ cron 05:00 → valheim-backup.sh ──────────┼──────►│  C:\Backups\Valheim\     │
│   ~/valheim-backups/valheim-DATE.tar.gz  │       │  (full history)          │
│   (last 7 days)                          │       │                          │
└──────────────────────────────────────────┘       └──────────────────────────┘
```

## Repository layout

```
scripts/valheim-backup.sh              world backup + 7-day rotation
cron/valheim-backup                    cron.d entry for the backup
systemd/valheim.service                the game server itself
systemd/valheim-restart.service        one-shot restart unit
systemd/valheim-restart.timer          daily 08:00 trigger
windows/Register-ValheimBackupTask.ps1 PC-side scheduled pull
```

## Design notes

- **Clean shutdowns.** Valheim writes the world to disk when it receives `SIGINT`. `valheim.service` sets `KillSignal=SIGINT` and `TimeoutStopSec=90`, so every stop or restart saves first instead of being killed mid-write.
- **Correct save path.** Since Valheim 1.0 each world is a folder (`_main.N.db2`, `.fwl2`, `.chunks`, `.ok`) under the **steam user's** home, not root's:
  `/home/steam/.config/unity3d/IronGate/Valheim/worlds_local/<WorldName>/`.
  My first backups pointed at `/root/...` and silently archived an empty world. Worth checking yours.
- **Two-tier retention.** The VPS keeps only 7 days to save disk; the PC keeps everything. If the VPS dies, the world survives.
- **Least privilege.** Root login over SSH is disabled. The backup script `chown`s archives to a normal user, which is the only account the PC connects as.
- **Missed runs.** `Persistent=true` on the timer and `-StartWhenAvailable` on the Windows task both catch up on runs missed while the machine was off.

## Install (VPS)

```bash
# Backup
sudo cp scripts/valheim-backup.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/valheim-backup.sh
sudo cp cron/valheim-backup /etc/cron.d/

# Server + restart timer
sudo cp systemd/*.service systemd/*.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now valheim.service valheim-restart.timer
```

Edit `WORLD_NAME`, `DEST` and `OWNER` at the top of `valheim-backup.sh` first.

Test:

```bash
sudo /usr/local/bin/valheim-backup.sh
tar -tzf ~/valheim-backups/valheim-*.tar.gz      # should list .db2 / .fwl2 files
systemctl list-timers | grep valheim             # next restart time
```

## Install (Windows PC)

Requires SSH key auth to the VPS. Edit `$Server` in the script, then in PowerShell:

```powershell
.\windows\Register-ValheimBackupTask.ps1
Start-ScheduledTask -TaskName "Valheim Backup"
```

If your key has a passphrase, enable `ssh-agent` once (admin PowerShell: `Set-Service ssh-agent -StartupType Automatic; Start-Service ssh-agent`), then `ssh-add`.

## Useful commands

**Skip one scheduled restart** (e.g. people are playing at 08:00):

```bash
systemctl stop valheim-restart.timer
systemd-run --on-calendar="YYYY-MM-DD 08:05:00" sh -c \
  'touch /var/lib/systemd/timers/stamp-valheim-restart.timer; systemctl start valheim-restart.timer'
```

The `touch` stops `Persistent=true` from treating 08:00 as a missed run and restarting immediately when the timer comes back.

**Restore a backup:**

```bash
sudo systemctl stop valheim
cd /home/steam/.config/unity3d/IronGate/Valheim/worlds_local
sudo mv MyWorld MyWorld.old
sudo tar -xzf /home/youruser/valheim-backups/valheim-YYYY-MM-DD.tar.gz
sudo chown -R steam:steam MyWorld
sudo systemctl start valheim
```

## Stack

Ubuntu 24.04 · SteamCMD · BepInEx · systemd · cron · bash · PowerShell · OpenSSH

## License

MIT
