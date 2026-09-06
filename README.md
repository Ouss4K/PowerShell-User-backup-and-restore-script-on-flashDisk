# USB User Backup and Restore (PowerShell)

Copy a Windows user profile onto a USB stick (or any extra disk) and restore it on a replacement PC. The toolkit stays in **PowerShell 5.1+** so it runs on Windows 10/11 without extra installs.

Copy the whole folder to the flash drive, then double-click `Start.cmd`. A window opens: pick the USB drive, tick what to copy, then click **Backup** or **Restore**.

## What it backs up

| Item | Contents |
| --- | --- |
| User data | Desktop, Documents, Pictures, Downloads, Videos, Music, Favorites (uses the real known-folder paths, including OneDrive redirects) |
| Browser bookmarks | Chrome, Edge, Firefox |
| Full browsers | Chrome / Edge / Firefox profiles (cache folders skipped) |
| Outlook / Word | Signatures and Word templates |
| OneNote | Local OneNote app data |
| Sticky Notes | Windows Sticky Notes local state |
| Printers | Name, driver, port (JSON + text) |
| Mapped drives | Persistent `HKCU\Network` mappings |
| Wi-Fi | `netsh` profiles, including saved keys |

Each backup lives under:

`X:\UserBackup\<PC-NAME>\`

and writes `manifest.json` plus `Logs\`. Older backups that used `X:\<PC-NAME>\` are still detected when you restore.

## How to run

**USB / double-click:** `Start.cmd` opens the GUI (hidden console).

**GUI from PowerShell:**

```powershell
Set-Location -Path 'E:\path\to\this-folder'
Set-ExecutionPolicy -Scope Process Bypass
.\UserBackup.ps1
```

**Console menu** (old interactive mode):

```powershell
.\UserBackup.ps1 -Mode Menu
```

`BACKUP.ps1` still works; it launches the GUI.

### Unattended

```powershell
.\UserBackup.ps1 -Mode Backup  -BackupDrive E -ItemSet Full -Force
.\UserBackup.ps1 -Mode Restore -BackupDrive E -ComputerName OLDPC -ItemSet UserData -Force
.\UserBackup.ps1 -WhatIf -Mode Backup -BackupDrive E -ItemSet UserData
```

`-ItemSet` values: `UserData`, `Bookmarks`, `Browsers`, `Signatures`, `OneNote`, `StickyNotes`, `Printers`, `NetworkDrives`, `WiFi`, `Firefox`, `Full`.

Language follows Windows (`en` / `fr`). Override with `-Language en` or `-Language fr`.

## Requirements

- Windows 10 or 11, PowerShell 5.1 or later
- USB / external disk formatted **NTFS** or **exFAT** (FAT32 cannot store files over 4 GB)
- Close Chrome, Edge, Firefox, and Outlook before a full browser or signature copy
- Restoring printers and Wi-Fi may need an elevated prompt, depending on policy

## GUI

The window lets you:

- Pick the backup drive and refresh the list
- Set the PC folder name (use the **old** PC name when restoring)
- Tick user data, browsers, signatures, printers, mapped drives, Wi-Fi, and more
- Run **Backup**, **Restore**, **Verify**, or **Estimate size**
- Use **Dry run** to list copies without writing files
- Switch EN / FR

Logs appear in the right-hand activity pane.

## Console menu

Use `-Mode Menu` if you need the original text menu:

1. User data  
2. Browser bookmarks  
3. Full browsers + signatures + OneNote  
4. Printers  
5. Mapped network drives  
6. OneNote only  
7. Signatures and Word templates  
8. Firefox only  
9. Full backup (best for a new PC)  
W. Wi-Fi profiles  
S. Sticky Notes  
R. Restore  
C. Checklist / verify  
Q. Quit  

## Safety notes

- Destination paths are always `drive:\UserBackup\PCNAME\...` — the old script could write to the wrong folder because the drive letter was dropped.
- Robocopy uses `/XJ` so OneDrive junction points do not recurse forever.
- Robocopy exit codes 0–7 are treated as success.
- Wi-Fi export includes network keys. Keep the USB private.
- Browser passwords may not survive a copy onto another Windows account (they are often encrypted for the original user).
- Taskbar pins, Start layout, and licensed apps still need a manual pass — option **C** prints that checklist.

## Restore on the new PC

1. Plug in the same USB stick.  
2. Run `Start.cmd`.  
3. Enter the **old** PC name in **PC folder name**.  
4. Tick the same items you backed up (or **Select all**).  
5. Click **Restore**.  
6. Sign out / reopen browsers and Outlook after restore.
