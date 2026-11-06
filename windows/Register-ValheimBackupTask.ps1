# Registers a daily Windows Scheduled Task that pulls Valheim backups from the VPS.
# Run once in PowerShell. Requires OpenSSH key auth to the VPS (no password prompt).

$Server   = "youruser@your.server.ip"
$Remote   = "valheim-backups/*.tar.gz"
$Local    = "C:\Backups\Valheim"
$TaskName = "Valheim Backup"

New-Item -ItemType Directory -Force -Path $Local | Out-Null

# -B = batch mode: fail instead of hanging if scp would need to prompt
$action   = New-ScheduledTaskAction -Execute "scp.exe" -Argument "-B `"$($Server):$Remote`" `"$Local\`""
$trigger  = New-ScheduledTaskTrigger -Daily -At 9pm
# Run a missed backup at next login if the PC was off
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings

# Test it right away:
# Start-ScheduledTask -TaskName "Valheim Backup"
