<#
.SYNOPSIS
    Back up and restore a Windows user profile to a USB / external disk.

.DESCRIPTION
    Interactive PC-replacement toolkit. Copies user folders, browser data,
    Outlook signatures, OneNote, printers, mapped drives and Wi-Fi profiles
    with robocopy. Restore reads the same folder layout (and legacy
    drive:\PCNAME backups from earlier versions of this script).

.PARAMETER Mode
    Gui (default), Menu, Backup, or Restore.

.PARAMETER BackupDrive
    Drive letter of the USB / external disk (E, E:, E:\).

.PARAMETER ComputerName
    Folder name on the disk. Defaults to this PC. For restore, use the old PC name.

.PARAMETER ItemSet
    One or more of: UserData, Bookmarks, Browsers, Signatures, OneNote,
    StickyNotes, Printers, NetworkDrives, WiFi, Firefox, Full.

.PARAMETER Language
    en or fr. Defaults to the Windows UI language.

.PARAMETER Force
    Skip confirmation prompts (for unattended Backup/Restore).

.EXAMPLE
    .\UserBackup.ps1

.EXAMPLE
    .\UserBackup.ps1 -Mode Backup -BackupDrive E -ItemSet Full -Force

.EXAMPLE
    .\UserBackup.ps1 -Mode Restore -BackupDrive E -ComputerName OLDPC -ItemSet UserData
#>
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Gui', 'Menu', 'Backup', 'Restore')]
    [AllowEmptyString()]
    [string]$Mode = 'Gui',

    [string]$BackupDrive,

    [string]$ComputerName,

    [ValidateSet(
        'UserData', 'Bookmarks', 'Browsers', 'Signatures', 'OneNote',
        'StickyNotes', 'Printers', 'NetworkDrives', 'WiFi', 'Firefox', 'Full'
    )]
    [AllowEmptyCollection()]
    [AllowEmptyString()]
    [AllowNull()]
    [string[]]$ItemSet,

    # Do not use ValidateSet here: [string] defaults to "" in Windows PowerShell 5.1,
    # and ValidateSet rejects that empty value before the script can auto-detect.
    [AllowEmptyString()]
    [AllowNull()]
    [string]$Language,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -----------------------------------------------------------------------------
# Localization
# -----------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($Mode)) {
    $Mode = 'Gui'
}

if ($ItemSet) {
    $ItemSet = @($ItemSet | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($ItemSet.Count -eq 0) {
        $ItemSet = $null
    }
}

function Get-NormalizedLanguage {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        if ((Get-Culture).TwoLetterISOLanguageName -eq 'fr') {
            return 'fr'
        }
        return 'en'
    }
    $normalized = $Value.Trim().ToLowerInvariant()
    if ($normalized -match '^fr') { return 'fr' }
    if ($normalized -match '^en') { return 'en' }
    throw "Language must be en or fr. Got: $Value"
}

$script:Language = Get-NormalizedLanguage -Value $Language

$script:Messages = @{
    en = @{
        Title              = 'USB User Backup and Restore'
        Subtitle           = 'PowerShell toolkit for PC replacement'
        PickLanguage       = 'Language / Langue  [EN / FR]'
        DetectingDrives    = 'Looking for backup drives...'
        NoDrive            = 'No extra disk found. Plug in a USB drive and retry, or type a letter.'
        DrivePrompt        = 'Backup drive letter'
        DriveMissing       = 'That drive is not available.'
        DriveNotReady      = 'That drive is not ready. Plug it in or choose another disk.'
        SystemDriveWarn    = 'This is the Windows system drive. Use a USB or extra disk when possible.'
        ContinueAnyway     = 'Continue anyway?'
        Fat32Warn          = 'This disk is FAT32. Files larger than 4 GB cannot be copied. Prefer exFAT or NTFS.'
        PcPrompt           = 'Backup folder name (old or current PC name)'
        UsingRoot          = 'Backup folder'
        MenuHeader         = 'MENU'
        BackupHeader       = 'Backup'
        RestoreHeader      = 'Restore'
        M1                 = '1  User data (Desktop, Documents, Pictures, Downloads, Videos, Music, Favorites)'
        M2                 = '2  Browser bookmarks (Chrome, Edge, Firefox)'
        M3                 = '3  Full browsers + signatures + OneNote'
        M4                 = '4  Printers'
        M5                 = '5  Mapped network drives'
        M6                 = '6  OneNote only'
        M7                 = '7  Outlook signatures and Word templates'
        M8                 = '8  Firefox only'
        M9                 = '9  Full backup (recommended for a new PC)'
        MW                 = 'W  Wi-Fi profiles (includes saved keys)'
        MS                 = 'S  Sticky Notes'
        MR                 = 'R  Restore from this backup'
        MC                 = 'C  Checklist / verify backup'
        MQ                 = 'Q  Quit'
        Choice             = 'Your choice'
        InvalidChoice      = 'Invalid choice.'
        ConfirmBackup      = 'Start this backup?'
        ConfirmRestore     = 'Start this restore? Close browsers and Outlook first.'
        ConfirmPc          = 'Use this folder name'
        Done               = 'Finished.'
        Cancelled          = 'Cancelled.'
        MissingSource      = 'Skipped (not found)'
        RoboFail           = 'Robocopy failed'
        CloseBrowsers      = 'Close Chrome, Edge and Firefox so profile files are not locked.'
        RestoreMissing     = 'No backup found for that PC name on this drive.'
        LegacyFound        = 'Found a legacy backup at the disk root (older script layout).'
        PrintersSaved      = 'Printer list saved.'
        PrintersRestore    = 'Printer names were exported. Reinstall USB printers by vendor installer if Add-Printer fails.'
        NetSaved           = 'Mapped drives saved.'
        NetRestored        = 'Mapped drive restore attempted.'
        WifiSaved          = 'Wi-Fi profiles exported.'
        WifiRestored       = 'Wi-Fi profiles imported.'
        ChecklistTitle     = 'Backup contents and manual checklist'
        ManualTips         = @'
Manual items this script cannot fully restore:
  - Taskbar pins and Start menu layout
  - Browser passwords if the browser is open or uses OS encryption bound to this Windows account
  - Outlook PST/OST archives (copy them yourself if they live outside Documents)
  - Outlook From/Bcc signatures assignment (file signatures ARE copied)
  - Licensed apps and product keys
'@
        PressEnter         = 'Press ENTER to continue...'
        YesNo              = 'Please answer Y or N.'
        Estimating         = 'Estimating size of selected user folders...'
        SizeLine           = 'Selected user-folder size (approx.)'
        FreeSpace          = 'Free space on backup drive'
        LowSpace           = 'The backup drive may not have enough free space.'
        SessionLog         = 'Session log'
        BackupComplete     = 'Backup completed.'
        RestoreComplete    = 'Restore completed.'
        DryRun             = 'Dry run (no files copied).'
        ItemStart          = 'Starting'
        WifiWarn           = 'Wi-Fi export includes saved network keys. Keep this USB private.'
        GuiDrive           = 'Backup drive'
        GuiRefresh         = 'Refresh'
        GuiPcName          = 'PC folder name'
        GuiPath            = 'Backup folder'
        GuiItems           = 'Items to include'
        GuiRecommended     = 'Recommended'
        GuiSelectAll       = 'Select all'
        GuiSelectNone      = 'None'
        GuiDryRun          = 'Dry run (list files, do not copy)'
        GuiBackup          = 'Backup'
        GuiRestore         = 'Restore'
        GuiVerify          = 'Verify'
        GuiEstimate        = 'Estimate size'
        GuiLog             = 'Activity'
        GuiReady           = 'Ready'
        GuiWorking         = 'Working...'
        GuiPickItems       = 'Select at least one item.'
        GuiItemUserData    = 'User data (Desktop, Documents, Pictures, Downloads, Videos, Music, Favorites)'
        GuiItemBookmarks   = 'Browser bookmarks (Chrome, Edge, Firefox)'
        GuiItemBrowsers    = 'Full browser profiles (cache skipped)'
        GuiItemSignatures  = 'Outlook signatures and Word templates'
        GuiItemOneNote     = 'OneNote'
        GuiItemSticky      = 'Sticky Notes'
        GuiItemPrinters    = 'Printers'
        GuiItemNetwork     = 'Mapped network drives'
        GuiItemWifi        = 'Wi-Fi profiles (includes saved keys)'
        GuiItemFirefox     = 'Firefox profile only'
        GuiYes             = 'Yes'
        GuiNo              = 'No'
    }
    fr = @{
        Title              = 'Sauvegarde et restauration utilisateur (USB)'
        Subtitle           = 'Outil PowerShell pour remplacement de PC'
        PickLanguage       = 'Language / Langue  [EN / FR]'
        DetectingDrives    = 'Recherche des disques de sauvegarde...'
        NoDrive            = 'Aucun disque extra detecte. Branchez une cle USB ou saisissez une lettre.'
        DrivePrompt        = 'Lettre du lecteur de sauvegarde'
        DriveMissing       = 'Ce lecteur est indisponible.'
        DriveNotReady      = 'Ce lecteur n''est pas pret. Branchez-le ou choisissez un autre disque.'
        SystemDriveWarn    = 'C''est le disque systeme Windows. Preferez une cle USB.'
        ContinueAnyway     = 'Continuer quand meme ?'
        Fat32Warn          = 'Ce disque est en FAT32. Les fichiers de plus de 4 Go ne peuvent pas etre copies. Preferez exFAT ou NTFS.'
        PcPrompt           = 'Nom du dossier de sauvegarde (ancien ou PC actuel)'
        UsingRoot          = 'Dossier de sauvegarde'
        MenuHeader         = 'MENU'
        BackupHeader       = 'Sauvegarde'
        RestoreHeader      = 'Restauration'
        M1                 = '1  Donnees utilisateur (Bureau, Documents, Images, Telechargements, Videos, Musique, Favoris)'
        M2                 = '2  Favoris navigateurs (Chrome, Edge, Firefox)'
        M3                 = '3  Navigateurs complets + signatures + OneNote'
        M4                 = '4  Imprimantes'
        M5                 = '5  Lecteurs reseau'
        M6                 = '6  OneNote uniquement'
        M7                 = '7  Signatures Outlook et modeles Word'
        M8                 = '8  Firefox uniquement'
        M9                 = '9  Sauvegarde complete (recommande pour un nouveau PC)'
        MW                 = 'W  Profils Wi-Fi (inclut les cles)'
        MS                 = 'S  Notes rapides (Sticky Notes)'
        MR                 = 'R  Restaurer depuis cette sauvegarde'
        MC                 = 'C  Checklist / verifier la sauvegarde'
        MQ                 = 'Q  Quitter'
        Choice             = 'Votre choix'
        InvalidChoice      = 'Choix invalide.'
        ConfirmBackup      = 'Lancer cette sauvegarde ?'
        ConfirmRestore     = 'Lancer cette restauration ? Fermez les navigateurs et Outlook.'
        ConfirmPc          = 'Utiliser ce nom de dossier'
        Done               = 'Termine.'
        Cancelled          = 'Annule.'
        MissingSource      = 'Ignore (introuvable)'
        RoboFail           = 'Echec Robocopy'
        CloseBrowsers      = 'Fermez Chrome, Edge et Firefox pour eviter les fichiers verrouilles.'
        RestoreMissing     = 'Aucune sauvegarde trouvee pour ce nom de PC sur ce lecteur.'
        LegacyFound        = 'Sauvegarde ancienne detectee a la racine du disque.'
        PrintersSaved      = 'Liste des imprimantes enregistree.'
        PrintersRestore    = 'Les imprimantes USB devront souvent etre reinstallees avec le pilote du fabricant.'
        NetSaved           = 'Lecteurs reseau enregistres.'
        NetRestored        = 'Restauration des lecteurs reseau tentee.'
        WifiSaved          = 'Profils Wi-Fi exportes.'
        WifiRestored       = 'Profils Wi-Fi importes.'
        ChecklistTitle     = 'Contenu de la sauvegarde et checklist manuelle'
        ManualTips         = @'
Elements a retablir manuellement :
  - Epingles de la barre des taches et menu Demarrer
  - Mots de passe navigateurs si le navigateur est ouvert ou chiffres pour ce compte Windows
  - Archives Outlook PST/OST hors Documents
  - Affectation des signatures Outlook (les fichiers de signature SONT copies)
  - Logiciels licences et cles produits
'@
        PressEnter         = 'Appuyez sur ENTREE pour continuer...'
        YesNo              = 'Repondez par O / Y ou N.'
        Estimating         = 'Estimation de la taille des dossiers utilisateur...'
        SizeLine           = 'Taille approx. des dossiers utilisateur'
        FreeSpace          = 'Espace libre sur le disque de sauvegarde'
        LowSpace           = 'Le disque de sauvegarde n''a peut-etre pas assez d''espace.'
        SessionLog         = 'Journal de session'
        BackupComplete     = 'Sauvegarde terminee.'
        RestoreComplete    = 'Restauration terminee.'
        DryRun             = 'Simulation (aucun fichier copie).'
        ItemStart          = 'Demarrage'
        WifiWarn           = 'L''export Wi-Fi contient les cles des reseaux. Gardez cette cle USB en securite.'
        GuiDrive           = 'Lecteur de sauvegarde'
        GuiRefresh         = 'Actualiser'
        GuiPcName          = 'Nom du dossier PC'
        GuiPath            = 'Dossier de sauvegarde'
        GuiItems           = 'Elements a inclure'
        GuiRecommended     = 'Recommande'
        GuiSelectAll       = 'Tout'
        GuiSelectNone      = 'Aucun'
        GuiDryRun          = 'Simulation (lister sans copier)'
        GuiBackup          = 'Sauvegarder'
        GuiRestore         = 'Restaurer'
        GuiVerify          = 'Verifier'
        GuiEstimate        = 'Estimer la taille'
        GuiLog             = 'Journal'
        GuiReady           = 'Pret'
        GuiWorking         = 'Travail en cours...'
        GuiPickItems       = 'Selectionnez au moins un element.'
        GuiItemUserData    = 'Donnees utilisateur (Bureau, Documents, Images, Telechargements, Videos, Musique, Favoris)'
        GuiItemBookmarks   = 'Favoris navigateurs (Chrome, Edge, Firefox)'
        GuiItemBrowsers    = 'Profils navigateurs complets (cache ignore)'
        GuiItemSignatures  = 'Signatures Outlook et modeles Word'
        GuiItemOneNote     = 'OneNote'
        GuiItemSticky      = 'Notes rapides'
        GuiItemPrinters    = 'Imprimantes'
        GuiItemNetwork     = 'Lecteurs reseau'
        GuiItemWifi        = 'Profils Wi-Fi (inclut les cles)'
        GuiItemFirefox     = 'Profil Firefox uniquement'
        GuiYes             = 'Oui'
        GuiNo              = 'Non'
    }
}

function Get-Text {
    param([Parameter(Mandatory = $true)][string]$Key)
    $table = $script:Messages[$script:Language]
    if ($table.ContainsKey($Key)) {
        return [string]$table[$Key]
    }
    $fallback = $script:Messages['en']
    if ($fallback.ContainsKey($Key)) {
        return [string]$fallback[$Key]
    }
    return $Key
}

# -----------------------------------------------------------------------------
# State
# -----------------------------------------------------------------------------
$script:BackupDriveLetter = $null
$script:BackupRoot = $null
$script:PcName = $null
$script:TranscriptPath = $null
$script:CompletedItems = New-Object System.Collections.Generic.List[string]
$script:DryRun = [bool]$WhatIfPreference
$script:IsGui = $false
$script:LogBox = $null

$script:BrowserExclude = @(
    'Cache', 'Code Cache', 'GPUCache', 'ShaderCache', 'GrShaderCache',
    'Service Worker', 'Crashpad', 'Temp', 'OptimizationGuidePredictionModels',
    'JumpListIconsMostVisited', 'JumpListIconsRecentClosed', 'File System',
    'SmartScreen', 'OnDeviceHeadSuggestModel'
)

$script:FirefoxExclude = @(
    'cache2', 'OfflineCache', 'startupCache', 'datareporting', 'safebrowsing'
)

# -----------------------------------------------------------------------------
# UI helpers
# -----------------------------------------------------------------------------
function Write-Title {
    Clear-Host
    Write-Host ''
    Write-Host ('=' * 64) -ForegroundColor Cyan
    Write-Host ('  ' + (Get-Text 'Title')) -ForegroundColor Cyan
    Write-Host ('  ' + (Get-Text 'Subtitle')) -ForegroundColor DarkCyan
    Write-Host ('=' * 64) -ForegroundColor Cyan
    Write-Host ''
}

function Write-LogLine {
    param(
        [string]$Message,
        [string]$Level = 'info'
    )
    if ([string]::IsNullOrWhiteSpace($Level)) {
        $Level = 'info'
    }
    $Level = $Level.ToLowerInvariant()
    try {
        if ($script:LogBox -and -not $script:LogBox.IsDisposed) {
            $color = [System.Drawing.Color]::FromArgb(180, 190, 205)
            switch ($Level) {
                'ok' { $color = [System.Drawing.Color]::FromArgb(90, 210, 140) }
                'warn' { $color = [System.Drawing.Color]::FromArgb(240, 185, 70) }
                'error' { $color = [System.Drawing.Color]::FromArgb(245, 95, 95) }
            }
            $script:LogBox.SelectionStart = $script:LogBox.TextLength
            $script:LogBox.SelectionLength = 0
            $script:LogBox.SelectionColor = $color
            $stamp = Get-Date -Format 'HH:mm:ss'
            $script:LogBox.AppendText($stamp + '  ' + $Message + [Environment]::NewLine)
            $script:LogBox.ScrollToCaret()
            [System.Windows.Forms.Application]::DoEvents()
        }
    }
    catch {
        # Never let logging crash the GUI.
    }
    if (-not $script:IsGui) {
        $hostColor = 'Gray'
        switch ($Level) {
            'ok' { $hostColor = 'Green' }
            'warn' { $hostColor = 'Yellow' }
            'error' { $hostColor = 'Red' }
        }
        Write-Host $Message -ForegroundColor $hostColor
    }
}

function Write-Info {
    param([string]$Message)
    Write-LogLine -Message $Message -Level info
}

function Write-Ok {
    param([string]$Message)
    Write-LogLine -Message $Message -Level ok
}

function Write-WarnLine {
    param([string]$Message)
    Write-LogLine -Message $Message -Level warn
}

function Write-ErrLine {
    param([string]$Message)
    Write-LogLine -Message $Message -Level error
}

function Get-ObjectProperty {
    param(
        $Object,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if ($null -eq $Object) {
        return $null
    }
    $prop = $Object.PSObject.Properties[$Name]
    if ($prop) {
        return $prop.Value
    }
    return $null
}

function Get-SafeFolderName {
    param([string]$Name)
    if ($null -eq $Name) {
        $Name = ''
    }
    $safe = $Name.Trim()
    foreach ($ch in [IO.Path]::GetInvalidFileNameChars()) {
        $safe = $safe.Replace([string]$ch, '_')
    }
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return $env:COMPUTERNAME
    }
    return $safe
}

function Read-YesNo {
    param(
        [Parameter(Mandatory = $true)][string]$Question,
        [bool]$DefaultYes = $true
    )
    if ($Force) {
        return $true
    }
    if ($DefaultYes) {
        $hint = '[Y/n]'
    }
    else {
        $hint = '[y/N]'
    }
    while ($true) {
        $answer = Read-Host "$Question $hint"
        if ([string]::IsNullOrWhiteSpace($answer)) {
            return $DefaultYes
        }
        switch -Regex ($answer.Trim()) {
            '^(y|yes|o|oui)$' { return $true }
            '^(n|no|non)$' { return $false }
            default { Write-WarnLine (Get-Text 'YesNo') }
        }
    }
}

function Wait-Continue {
    if ($Mode -eq 'Menu' -and -not $Force) {
        [void](Read-Host (Get-Text 'PressEnter'))
    }
}

# -----------------------------------------------------------------------------
# Paths and drives
# -----------------------------------------------------------------------------
function Get-NormalizedDriveLetter {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }
    $letter = $Value.Trim().TrimEnd('\').TrimEnd(':')
    if ($letter -notmatch '^[A-Za-z]$') {
        return $null
    }
    return $letter.ToUpperInvariant()
}

function Test-DriveReady {
    param([string]$Letter)
    $normalized = Get-NormalizedDriveLetter $Letter
    if (-not $normalized) {
        return $false
    }
    try {
        $info = New-Object System.IO.DriveInfo("${normalized}:")
        return [bool]($info.IsReady -and $info.DriveFormat -and $info.TotalSize -gt 0)
    }
    catch {
        return $false
    }
}

function Get-CandidateBackupDrives {
    $system = $env:SystemDrive.TrimEnd(':').ToUpperInvariant()
    Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction SilentlyContinue |
        Where-Object { $_.DeviceID -and $_.DriveType -in 2, 3 } |
        ForEach-Object {
            $letter = $_.DeviceID.TrimEnd(':')
            if (-not (Test-DriveReady $letter)) {
                # skip empty card readers / DVD trays
            }
            else {
                $free = 0.0
                $size = 0.0
                if ($_.FreeSpace) { $free = [math]::Round(($_.FreeSpace / 1GB), 2) }
                if ($_.Size) { $size = [math]::Round(($_.Size / 1GB), 2) }
                $label = $_.VolumeName
                if ([string]::IsNullOrWhiteSpace($label)) { $label = '-' }
                [pscustomobject]@{
                    Letter     = $letter
                    DeviceID   = $_.DeviceID
                    DriveType  = $_.DriveType
                    Kind       = $(if ($_.DriveType -eq 2) { 'USB/Removable' } else { 'Local' })
                    Label      = $label
                    FileSystem = $_.FileSystem
                    FreeGB     = $free
                    SizeGB     = $size
                    IsSystem   = ($letter.ToUpperInvariant() -eq $system)
                }
            }
        }
}

function Get-KnownUserPath {
    param([Parameter(Mandatory = $true)][string]$ShellName)
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
    try {
        $item = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
        $prop = $item.PSObject.Properties[$ShellName]
        if ($prop -and $prop.Value) {
            return [Environment]::ExpandEnvironmentVariables([string]$prop.Value)
        }
    }
    catch {
        # fall through to Environment.GetFolderPath
    }
    switch ($ShellName) {
        'Desktop' { return [Environment]::GetFolderPath('Desktop') }
        'Personal' { return [Environment]::GetFolderPath('MyDocuments') }
        'My Pictures' { return [Environment]::GetFolderPath('MyPictures') }
        'My Video' { return [Environment]::GetFolderPath('MyVideos') }
        'My Music' { return [Environment]::GetFolderPath('MyMusic') }
        'Favorites' { return [Environment]::GetFolderPath('Favorites') }
        '{374DE290-123F-4565-9164-39C4925E467B}' {
            return (Join-Path $env:USERPROFILE 'Downloads')
        }
        default { return $null }
    }
}

function Test-BackupLooksValid {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        return $false
    }
    $markers = @(
        'manifest.json', 'Desktop', 'Documents', 'Pictures', 'Signatures',
        'Browsers', 'Printers', 'NetworkDrives', 'OneNote', 'WiFi'
    )
    foreach ($name in $markers) {
        if (Test-Path -LiteralPath (Join-Path $Path $name)) {
            return $true
        }
    }
    return $false
}

function Resolve-BackupRoot {
    param(
        [Parameter(Mandatory = $true)][string]$DriveLetter,
        [Parameter(Mandatory = $true)][string]$PcName,
        [switch]$ForRestore
    )
    $driveRoot = "${DriveLetter}:\"
    $modern = Join-Path (Join-Path $driveRoot 'UserBackup') $PcName
    $legacy = Join-Path $driveRoot $PcName

    if ($ForRestore) {
        if (Test-BackupLooksValid $modern) { return $modern }
        if (Test-BackupLooksValid $legacy) {
            Write-WarnLine (Get-Text 'LegacyFound')
            return $legacy
        }
        if (Test-Path -LiteralPath $modern) { return $modern }
        if (Test-Path -LiteralPath $legacy) { return $legacy }
        return $null
    }

    return $modern
}

function Initialize-BackupLocation {
    param(
        [switch]$ForRestore,
        [string]$DriveLetter,
        [string]$PcName
    )

    $letter = Get-NormalizedDriveLetter $DriveLetter
    if (-not $letter) {
        $letter = Get-NormalizedDriveLetter $BackupDrive
    }
    if (-not $letter) {
        if ($script:IsGui) {
            throw (Get-Text 'DriveMissing')
        }
        Write-Info (Get-Text 'DetectingDrives')
        $drives = @(Get-CandidateBackupDrives)
        if ($drives.Count -gt 0) {
            $drives | Format-Table Letter, Kind, Label, FileSystem, FreeGB, SizeGB, IsSystem -AutoSize | Out-Host
        }
        else {
            Write-WarnLine (Get-Text 'NoDrive')
        }
        $letter = Get-NormalizedDriveLetter (Read-Host (Get-Text 'DrivePrompt'))
    }

    if (-not $letter) {
        throw (Get-Text 'DriveMissing')
    }
    if (-not (Test-Path -LiteralPath "${letter}:\")) {
        throw (Get-Text 'DriveMissing')
    }
    if (-not (Test-DriveReady $letter)) {
        throw (Get-Text 'DriveNotReady')
    }

    $systemLetter = $env:SystemDrive.TrimEnd(':').ToUpperInvariant()
    if ($letter -eq $systemLetter) {
        Write-WarnLine (Get-Text 'SystemDriveWarn')
        $continueSystem = $false
        if ($script:IsGui) {
            $answer = [System.Windows.Forms.MessageBox]::Show(
                ((Get-Text 'SystemDriveWarn') + [Environment]::NewLine + [Environment]::NewLine + (Get-Text 'ContinueAnyway')),
                (Get-Text 'Title'),
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            $continueSystem = ($answer -eq [System.Windows.Forms.DialogResult]::Yes)
        }
        else {
            $continueSystem = Read-YesNo (Get-Text 'ContinueAnyway') $false
        }
        if (-not $continueSystem) {
            throw (Get-Text 'Cancelled')
        }
    }

    $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='${letter}:'" -ErrorAction SilentlyContinue
    if ($disk -and $disk.FileSystem -eq 'FAT32') {
        Write-WarnLine (Get-Text 'Fat32Warn')
    }

    $name = $PcName
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = $ComputerName
    }
    if ([string]::IsNullOrWhiteSpace($name)) {
        if ($script:IsGui) {
            $name = $env:COMPUTERNAME
        }
        else {
            $defaultName = $env:COMPUTERNAME
            $entered = Read-Host "$(Get-Text 'PcPrompt') [$defaultName]"
            if ([string]::IsNullOrWhiteSpace($entered)) {
                $name = $defaultName
            }
            else {
                $name = $entered.Trim()
            }
        }
    }
    $name = Get-SafeFolderName $name

    $root = Resolve-BackupRoot -DriveLetter $letter -PcName $name -ForRestore:$ForRestore
    if ($ForRestore -and -not $root) {
        throw (Get-Text 'RestoreMissing')
    }
    if (-not $root) {
        $root = Join-Path (Join-Path "${letter}:\" 'UserBackup') $name
    }

    $script:BackupDriveLetter = $letter
    $script:PcName = $name
    $script:BackupRoot = $root
    Write-Ok "$(Get-Text 'UsingRoot'): $($script:BackupRoot)"
}

function Start-BackupTranscript {
    $logDir = Join-Path $script:BackupRoot 'Logs'
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $script:TranscriptPath = Join-Path $logDir "session-$stamp.log"
    try {
        Start-Transcript -Path $script:TranscriptPath -Append | Out-Null
        Write-Info "$(Get-Text 'SessionLog'): $($script:TranscriptPath)"
    }
    catch {
        Write-WarnLine "Transcript: $($_.Exception.Message)"
    }
}

function Stop-BackupTranscript {
    if ($script:TranscriptPath) {
        try { Stop-Transcript | Out-Null } catch { }
    }
}

# -----------------------------------------------------------------------------
# Copy engine
# -----------------------------------------------------------------------------
function Invoke-RoboCopySafe {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [string[]]$ExcludeDirs,
        [string[]]$ExtraArgs
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        Write-WarnLine "$(Get-Text 'MissingSource'): $Source"
        return $false
    }

    Write-Info "  $($Source) -> $Destination"
    if ($script:DryRun -or $WhatIfPreference) {
        Write-Info (Get-Text 'DryRun')
    }

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null

    $roboArgs = @(
        $Source,
        $Destination,
        '/E', '/XJ', '/R:2', '/W:2', '/MT:8',
        '/COPY:DAT', '/DCOPY:DAT', '/FFT',
        '/NDL', '/NFL', '/NP'
    )
    if ($script:DryRun -or $WhatIfPreference) {
        $roboArgs += '/L'
    }
    if ($ExcludeDirs -and $ExcludeDirs.Count -gt 0) {
        $roboArgs += '/XD'
        $roboArgs += $ExcludeDirs
    }
    if ($ExtraArgs) {
        $roboArgs += $ExtraArgs
    }

    $logDir = Join-Path $script:BackupRoot 'Logs'
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    }
    $logFile = Join-Path $logDir 'robocopy.log'
    $roboArgs += "/LOG+:$logFile"

    & robocopy.exe @roboArgs | Out-Null
    $code = $LASTEXITCODE
    $global:LASTEXITCODE = 0

    # robocopy: 0-7 = success with extra info; 8+ = failure
    if ($code -ge 8) {
        throw "$(Get-Text 'RoboFail') ($code): $Source -> $Destination"
    }
    return $true
}

function Copy-BackupFile {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )
    if (-not (Test-Path -LiteralPath $Source)) {
        Write-WarnLine "$(Get-Text 'MissingSource'): $Source"
        return $false
    }
    $destDir = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    Write-Info "  $Source -> $Destination"
    if ($script:DryRun -or $WhatIfPreference) {
        Write-Info (Get-Text 'DryRun')
        return $true
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    return $true
}

function Get-FolderBytes {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        return [int64]0
    }
    $sum = [int64]0
    Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
        ForEach-Object { $sum += $_.Length }
    return $sum
}

# -----------------------------------------------------------------------------
# Manifest
# -----------------------------------------------------------------------------
function Get-ManifestPath {
    return (Join-Path $script:BackupRoot 'manifest.json')
}

function Read-BackupManifest {
    $path = Get-ManifestPath
    if (-not (Test-Path -LiteralPath $path)) {
        return $null
    }
    try {
        return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Save-BackupManifest {
    param([string[]]$Items)

    $existing = Read-BackupManifest
    $allItems = New-Object System.Collections.Generic.List[string]
    if ($existing -and $existing.Items) {
        foreach ($i in @($existing.Items)) {
            if ($i -and -not $allItems.Contains([string]$i)) {
                [void]$allItems.Add([string]$i)
            }
        }
    }
    foreach ($i in @($Items)) {
        if ($i -and -not $allItems.Contains($i)) {
            [void]$allItems.Add($i)
        }
    }

    $created = [datetime]::UtcNow.ToString('o')
    if ($existing -and $existing.CreatedUtc) {
        $created = [string]$existing.CreatedUtc
    }

    $manifest = [ordered]@{
        SchemaVersion  = 1
        Tool           = 'USB User Backup'
        CreatedUtc     = $created
        UpdatedUtc     = [datetime]::UtcNow.ToString('o')
        SourceComputer = $env:COMPUTERNAME
        SourceUser     = $env:USERNAME
        WindowsVersion = [Environment]::OSVersion.VersionString
        BackupRoot     = $script:BackupRoot
        Items          = @($allItems)
    }

    $json = $manifest | ConvertTo-Json -Depth 6
    $utf8 = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText((Get-ManifestPath), $json, $utf8)
}

# -----------------------------------------------------------------------------
# Backup / restore operations
# -----------------------------------------------------------------------------
function Get-UserDataSources {
    return @(
        @{ Id = 'Desktop';   Source = (Get-KnownUserPath 'Desktop'); Rel = 'Desktop' }
        @{ Id = 'Documents'; Source = (Get-KnownUserPath 'Personal'); Rel = 'Documents' }
        @{ Id = 'Pictures';  Source = (Get-KnownUserPath 'My Pictures'); Rel = 'Pictures' }
        @{ Id = 'Downloads'; Source = (Get-KnownUserPath '{374DE290-123F-4565-9164-39C4925E467B}'); Rel = 'Downloads' }
        @{ Id = 'Videos';    Source = (Get-KnownUserPath 'My Video'); Rel = 'Videos' }
        @{ Id = 'Music';     Source = (Get-KnownUserPath 'My Music'); Rel = 'Music' }
        @{ Id = 'Favorites'; Source = (Get-KnownUserPath 'Favorites'); Rel = 'Favorites' }
    )
}

function Backup-UserData {
    Write-Ok "$(Get-Text 'ItemStart'): UserData"
    foreach ($item in (Get-UserDataSources)) {
        if ($item.Source) {
            Invoke-RoboCopySafe -Source $item.Source -Destination (Join-Path $script:BackupRoot $item.Rel) | Out-Null
        }
    }
    [void]$script:CompletedItems.Add('UserData')
}

function Restore-UserData {
    Write-Ok "$(Get-Text 'ItemStart'): UserData"
    foreach ($item in (Get-UserDataSources)) {
        $src = Join-Path $script:BackupRoot $item.Rel
        if ($item.Source) {
            Invoke-RoboCopySafe -Source $src -Destination $item.Source | Out-Null
        }
    }
}

function Backup-Bookmarks {
    Write-Ok "$(Get-Text 'ItemStart'): Bookmarks"
    Write-WarnLine (Get-Text 'CloseBrowsers')

    $chromeSrc = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data\Default'
    $edgeSrc = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Default'
    $chromeDst = Join-Path $script:BackupRoot 'Browsers\Chrome'
    $edgeDst = Join-Path $script:BackupRoot 'Browsers\Edge'

    foreach ($name in @('Bookmarks', 'Bookmarks.bak')) {
        Copy-BackupFile -Source (Join-Path $chromeSrc $name) -Destination (Join-Path $chromeDst $name) | Out-Null
        Copy-BackupFile -Source (Join-Path $edgeSrc $name) -Destination (Join-Path $edgeDst $name) | Out-Null
    }

    $ffProfiles = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles'
    if (Test-Path -LiteralPath $ffProfiles) {
        Get-ChildItem -LiteralPath $ffProfiles -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            foreach ($name in @('places.sqlite', 'favicons.sqlite', 'prefs.js')) {
                $src = Join-Path $_.FullName $name
                $dst = Join-Path (Join-Path $script:BackupRoot "Browsers\Firefox\Profiles\$($_.Name)") $name
                Copy-BackupFile -Source $src -Destination $dst | Out-Null
            }
        }
        $ini = Join-Path $env:APPDATA 'Mozilla\Firefox\profiles.ini'
        Copy-BackupFile -Source $ini -Destination (Join-Path $script:BackupRoot 'Browsers\Firefox\profiles.ini') | Out-Null
    }

    [void]$script:CompletedItems.Add('Bookmarks')
}

function Restore-Bookmarks {
    Write-Ok "$(Get-Text 'ItemStart'): Bookmarks"
    Write-WarnLine (Get-Text 'CloseBrowsers')

    $chromeDst = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data\Default'
    $edgeDst = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Default'
    $chromeSrc = Join-Path $script:BackupRoot 'Browsers\Chrome'
    $edgeSrc = Join-Path $script:BackupRoot 'Browsers\Edge'

    foreach ($name in @('Bookmarks', 'Bookmarks.bak')) {
        Copy-BackupFile -Source (Join-Path $chromeSrc $name) -Destination (Join-Path $chromeDst $name) | Out-Null
        Copy-BackupFile -Source (Join-Path $edgeSrc $name) -Destination (Join-Path $edgeDst $name) | Out-Null
    }

    $ffBackup = Join-Path $script:BackupRoot 'Browsers\Firefox\Profiles'
    $ffLive = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles'
    if (Test-Path -LiteralPath $ffBackup) {
        Get-ChildItem -LiteralPath $ffBackup -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $target = Join-Path $ffLive $_.Name
            Invoke-RoboCopySafe -Source $_.FullName -Destination $target | Out-Null
        }
    }
}

function Backup-Browsers {
    Write-Ok "$(Get-Text 'ItemStart'): Browsers"
    Write-WarnLine (Get-Text 'CloseBrowsers')

    $chrome = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data'
    $edge = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data'
    $firefox = Join-Path $env:APPDATA 'Mozilla\Firefox'

    Invoke-RoboCopySafe -Source $chrome -Destination (Join-Path $script:BackupRoot 'Browsers\Chrome\User Data') -ExcludeDirs $script:BrowserExclude | Out-Null
    Invoke-RoboCopySafe -Source $edge -Destination (Join-Path $script:BackupRoot 'Browsers\Edge\User Data') -ExcludeDirs $script:BrowserExclude | Out-Null
    Invoke-RoboCopySafe -Source $firefox -Destination (Join-Path $script:BackupRoot 'Browsers\Firefox') -ExcludeDirs $script:FirefoxExclude | Out-Null
    [void]$script:CompletedItems.Add('Browsers')
}

function Restore-Browsers {
    Write-Ok "$(Get-Text 'ItemStart'): Browsers"
    Write-WarnLine (Get-Text 'CloseBrowsers')

    $chromeSrc = Join-Path $script:BackupRoot 'Browsers\Chrome\User Data'
    $edgeSrc = Join-Path $script:BackupRoot 'Browsers\Edge\User Data'
    $ffSrc = Join-Path $script:BackupRoot 'Browsers\Firefox'

    Invoke-RoboCopySafe -Source $chromeSrc -Destination (Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data') -ExcludeDirs $script:BrowserExclude | Out-Null
    Invoke-RoboCopySafe -Source $edgeSrc -Destination (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data') -ExcludeDirs $script:BrowserExclude | Out-Null
    Invoke-RoboCopySafe -Source $ffSrc -Destination (Join-Path $env:APPDATA 'Mozilla\Firefox') -ExcludeDirs $script:FirefoxExclude | Out-Null
}

function Backup-Firefox {
    Write-Ok "$(Get-Text 'ItemStart'): Firefox"
    $firefox = Join-Path $env:APPDATA 'Mozilla\Firefox'
    Invoke-RoboCopySafe -Source $firefox -Destination (Join-Path $script:BackupRoot 'Browsers\Firefox') -ExcludeDirs $script:FirefoxExclude | Out-Null
    [void]$script:CompletedItems.Add('Firefox')
}

function Restore-Firefox {
    Write-Ok "$(Get-Text 'ItemStart'): Firefox"
    $src = Join-Path $script:BackupRoot 'Browsers\Firefox'
    Invoke-RoboCopySafe -Source $src -Destination (Join-Path $env:APPDATA 'Mozilla\Firefox') -ExcludeDirs $script:FirefoxExclude | Out-Null
}

function Backup-Signatures {
    Write-Ok "$(Get-Text 'ItemStart'): Signatures"
    $sig = Join-Path $env:APPDATA 'Microsoft\Signatures'
    $tpl = Join-Path $env:APPDATA 'Microsoft\Templates'
    Invoke-RoboCopySafe -Source $sig -Destination (Join-Path $script:BackupRoot 'Signatures') | Out-Null
    Invoke-RoboCopySafe -Source $tpl -Destination (Join-Path $script:BackupRoot 'Templates') | Out-Null
    [void]$script:CompletedItems.Add('Signatures')
}

function Restore-Signatures {
    Write-Ok "$(Get-Text 'ItemStart'): Signatures"
    Invoke-RoboCopySafe -Source (Join-Path $script:BackupRoot 'Signatures') -Destination (Join-Path $env:APPDATA 'Microsoft\Signatures') | Out-Null
    Invoke-RoboCopySafe -Source (Join-Path $script:BackupRoot 'Templates') -Destination (Join-Path $env:APPDATA 'Microsoft\Templates') | Out-Null
}

function Backup-OneNote {
    Write-Ok "$(Get-Text 'ItemStart'): OneNote"
    $one = Join-Path $env:LOCALAPPDATA 'Microsoft\OneNote'
    Invoke-RoboCopySafe -Source $one -Destination (Join-Path $script:BackupRoot 'OneNote') | Out-Null
    [void]$script:CompletedItems.Add('OneNote')
}

function Restore-OneNote {
    Write-Ok "$(Get-Text 'ItemStart'): OneNote"
    Invoke-RoboCopySafe -Source (Join-Path $script:BackupRoot 'OneNote') -Destination (Join-Path $env:LOCALAPPDATA 'Microsoft\OneNote') | Out-Null
}

function Backup-StickyNotes {
    Write-Ok "$(Get-Text 'ItemStart'): StickyNotes"
    $sticky = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe\LocalState'
    Invoke-RoboCopySafe -Source $sticky -Destination (Join-Path $script:BackupRoot 'StickyNotes') | Out-Null
    [void]$script:CompletedItems.Add('StickyNotes')
}

function Restore-StickyNotes {
    Write-Ok "$(Get-Text 'ItemStart'): StickyNotes"
    $sticky = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe\LocalState'
    Invoke-RoboCopySafe -Source (Join-Path $script:BackupRoot 'StickyNotes') -Destination $sticky | Out-Null
}

function Backup-Printers {
    Write-Ok "$(Get-Text 'ItemStart'): Printers"
    $dir = Join-Path $script:BackupRoot 'Printers'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    $printers = @(Get-Printer -ErrorAction SilentlyContinue | Select-Object Name, DriverName, PortName, Type, Shared, Published)
    $ports = @(Get-PrinterPort -ErrorAction SilentlyContinue | Select-Object Name, Description, PrinterHostAddress)

    $utf8 = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText(
        (Join-Path $dir 'printers.json'),
        (@{ Printers = $printers; Ports = $ports } | ConvertTo-Json -Depth 6),
        $utf8
    )
    $printers | Format-Table -AutoSize | Out-String | Set-Content -LiteralPath (Join-Path $dir 'printers.txt') -Encoding UTF8
    Write-Ok (Get-Text 'PrintersSaved')
    [void]$script:CompletedItems.Add('Printers')
}

function Restore-Printers {
    Write-Ok "$(Get-Text 'ItemStart'): Printers"
    $jsonPath = Join-Path $script:BackupRoot 'Printers\printers.json'
    if (-not (Test-Path -LiteralPath $jsonPath)) {
        Write-WarnLine "$(Get-Text 'MissingSource'): $jsonPath"
        return
    }
    Write-WarnLine (Get-Text 'PrintersRestore')
    $data = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $printerRows = @()
    $printerProp = $data.PSObject.Properties['Printers']
    if ($printerProp -and $printerProp.Value) {
        $printerRows = @($printerProp.Value)
    }
    foreach ($p in $printerRows) {
        $printerName = Get-ObjectProperty $p 'Name'
        $driverName = Get-ObjectProperty $p 'DriverName'
        $portName = Get-ObjectProperty $p 'PortName'
        if (-not $printerName) { continue }
        $exists = Get-Printer -Name $printerName -ErrorAction SilentlyContinue
        if ($exists) {
            Write-Info "  Already installed: $printerName"
            continue
        }
        try {
            if ($portName -and $driverName) {
                Add-Printer -Name $printerName -DriverName $driverName -PortName $portName -ErrorAction Stop
                Write-Ok "  Added printer: $printerName"
            }
            else {
                Write-WarnLine "  Cannot auto-add: $printerName"
            }
        }
        catch {
            Write-WarnLine "  ${printerName}: $($_.Exception.Message)"
        }
    }
}

function Backup-NetworkDrives {
    Write-Ok "$(Get-Text 'ItemStart'): NetworkDrives"
    $dir = Join-Path $script:BackupRoot 'NetworkDrives'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    $maps = New-Object System.Collections.Generic.List[object]
    if (Test-Path -LiteralPath 'HKCU:\Network') {
        Get-ChildItem -LiteralPath 'HKCU:\Network' -ErrorAction SilentlyContinue | ForEach-Object {
            $letter = $_.PSChildName
            $props = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
            if (-not $props) { return }
            $remoteProp = $props.PSObject.Properties['RemotePath']
            $providerProp = $props.PSObject.Properties['ProviderName']
            $remote = $null
            $provider = $null
            if ($remoteProp) { $remote = $remoteProp.Value }
            if ($providerProp) { $provider = $providerProp.Value }
            $maps.Add([pscustomobject]@{
                Letter     = $letter
                RemotePath = $remote
                Provider   = $provider
            }) | Out-Null
        }
    }

    $live = Get-CimInstance -ClassName Win32_NetworkConnection -ErrorAction SilentlyContinue |
        Select-Object LocalName, RemotePath, ConnectionState, Persistent

    $utf8 = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText(
        (Join-Path $dir 'mapped-drives.json'),
        (@{ Persistent = @($maps); Live = @($live) } | ConvertTo-Json -Depth 6),
        $utf8
    )

    $lines = foreach ($m in $maps) {
        "Drive: $($m.Letter):  Path: $($m.RemotePath)"
    }
    $lines | Set-Content -LiteralPath (Join-Path $dir 'mapped-drives.txt') -Encoding UTF8
    Write-Ok (Get-Text 'NetSaved')
    [void]$script:CompletedItems.Add('NetworkDrives')
}

function Restore-NetworkDrives {
    Write-Ok "$(Get-Text 'ItemStart'): NetworkDrives"
    $jsonPath = Join-Path $script:BackupRoot 'NetworkDrives\mapped-drives.json'
    if (-not (Test-Path -LiteralPath $jsonPath)) {
        Write-WarnLine "$(Get-Text 'MissingSource'): $jsonPath"
        return
    }
    $data = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $rows = @()
    $persistentProp = $data.PSObject.Properties['Persistent']
    if ($persistentProp -and $persistentProp.Value) {
        $rows = @($persistentProp.Value)
    }
    foreach ($m in $rows) {
        $mapLetter = Get-ObjectProperty $m 'Letter'
        $remotePath = Get-ObjectProperty $m 'RemotePath'
        if (-not $mapLetter -or -not $remotePath) { continue }
        $drive = "${mapLetter}:"
        try {
            if (Test-Path -LiteralPath $drive) {
                Write-Info "  Already mapped: $drive"
                continue
            }
            & net.exe use $drive $remotePath /persistent:yes | Out-Null
            Write-Ok "  Mapped $drive -> $remotePath"
        }
        catch {
            Write-WarnLine "  $drive : $($_.Exception.Message)"
        }
    }
    Write-Ok (Get-Text 'NetRestored')
}

function Backup-WiFi {
    Write-Ok "$(Get-Text 'ItemStart'): WiFi"
    Write-WarnLine (Get-Text 'WifiWarn')
    $dir = Join-Path $script:BackupRoot 'WiFi'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    if ($script:DryRun -or $WhatIfPreference) {
        Write-Info (Get-Text 'DryRun')
        return
    }
    & netsh.exe wlan export profile folder=$dir key=clear | Out-Null
    Write-Ok (Get-Text 'WifiSaved')
    [void]$script:CompletedItems.Add('WiFi')
}

function Restore-WiFi {
    Write-Ok "$(Get-Text 'ItemStart'): WiFi"
    $dir = Join-Path $script:BackupRoot 'WiFi'
    if (-not (Test-Path -LiteralPath $dir)) {
        Write-WarnLine "$(Get-Text 'MissingSource'): $dir"
        return
    }
    Get-ChildItem -LiteralPath $dir -Filter '*.xml' -ErrorAction SilentlyContinue | ForEach-Object {
        & netsh.exe wlan add profile filename="$($_.FullName)" user=current | Out-Null
        Write-Info "  $($_.Name)"
    }
    Write-Ok (Get-Text 'WifiRestored')
}

function Invoke-BackupSet {
    param([Parameter(Mandatory = $true)][string[]]$Sets)

    $script:CompletedItems.Clear()
    $unique = New-Object System.Collections.Generic.List[string]
    foreach ($s in $Sets) {
        if (-not $unique.Contains($s)) { [void]$unique.Add($s) }
    }
    if ($unique.Contains('Full')) {
        $unique.Clear()
        foreach ($s in @('UserData', 'Browsers', 'Signatures', 'OneNote', 'StickyNotes', 'Printers', 'NetworkDrives', 'WiFi')) {
            [void]$unique.Add($s)
        }
    }

    foreach ($s in $unique) {
        switch ($s) {
            'UserData' { Backup-UserData }
            'Bookmarks' { Backup-Bookmarks }
            'Browsers' { Backup-Browsers }
            'Signatures' { Backup-Signatures }
            'OneNote' { Backup-OneNote }
            'StickyNotes' { Backup-StickyNotes }
            'Printers' { Backup-Printers }
            'NetworkDrives' { Backup-NetworkDrives }
            'WiFi' { Backup-WiFi }
            'Firefox' { Backup-Firefox }
            default { Write-WarnLine "$(Get-Text 'InvalidChoice'): $s" }
        }
    }

    Save-BackupManifest -Items @($script:CompletedItems)
    Write-Ok (Get-Text 'BackupComplete')
}

function Invoke-RestoreSet {
    param([Parameter(Mandatory = $true)][string[]]$Sets)

    $unique = New-Object System.Collections.Generic.List[string]
    foreach ($s in $Sets) {
        if (-not $unique.Contains($s)) { [void]$unique.Add($s) }
    }
    if ($unique.Contains('Full')) {
        $unique.Clear()
        foreach ($s in @('UserData', 'Browsers', 'Signatures', 'OneNote', 'StickyNotes', 'Printers', 'NetworkDrives', 'WiFi')) {
            [void]$unique.Add($s)
        }
    }

    foreach ($s in $unique) {
        switch ($s) {
            'UserData' { Restore-UserData }
            'Bookmarks' { Restore-Bookmarks }
            'Browsers' { Restore-Browsers }
            'Signatures' { Restore-Signatures }
            'OneNote' { Restore-OneNote }
            'StickyNotes' { Restore-StickyNotes }
            'Printers' { Restore-Printers }
            'NetworkDrives' { Restore-NetworkDrives }
            'WiFi' { Restore-WiFi }
            'Firefox' { Restore-Firefox }
            default { Write-WarnLine "$(Get-Text 'InvalidChoice'): $s" }
        }
    }

    Write-Ok (Get-Text 'RestoreComplete')
}

function Show-BackupChecklist {
    Write-Info (Get-Text 'ChecklistTitle')
    Write-Info "Root: $($script:BackupRoot)"
    $manifest = Read-BackupManifest
    if ($manifest) {
        $srcPc = Get-ObjectProperty $manifest 'SourceComputer'
        $srcUser = Get-ObjectProperty $manifest 'SourceUser'
        $updated = Get-ObjectProperty $manifest 'UpdatedUtc'
        $items = Get-ObjectProperty $manifest 'Items'
        if ($srcPc) { Write-Info "Source PC : $srcPc" }
        if ($srcUser) { Write-Info "Source user: $srcUser" }
        if ($updated) { Write-Info "Updated    : $updated" }
        if ($items) { Write-Info "Items      : $($items -join ', ')" }
    }
    $expected = @(
        'Desktop', 'Documents', 'Pictures', 'Downloads', 'Videos', 'Music', 'Favorites',
        'Signatures', 'Templates', 'OneNote', 'StickyNotes',
        'Printers', 'NetworkDrives', 'WiFi',
        'Browsers\Chrome', 'Browsers\Edge', 'Browsers\Firefox',
        'manifest.json'
    )
    foreach ($rel in $expected) {
        $path = Join-Path $script:BackupRoot $rel
        if (Test-Path -LiteralPath $path) {
            Write-Ok ("  [OK]  {0}" -f $rel)
        }
        else {
            Write-Info ("  [  ]  {0}" -f $rel)
        }
    }
    Write-WarnLine (Get-Text 'ManualTips')
}

function Show-SizeEstimate {
    Write-Info (Get-Text 'Estimating')
    $bytes = [int64]0
    foreach ($item in (Get-UserDataSources)) {
        if ($item.Source) {
            $bytes += Get-FolderBytes -Path $item.Source
        }
    }
    $gb = [math]::Round(($bytes / 1GB), 2)
    Write-Ok "$(Get-Text 'SizeLine'): $gb GB"

    if ($script:BackupDriveLetter) {
        $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($script:BackupDriveLetter):'" -ErrorAction SilentlyContinue
        if ($disk) {
            $free = [math]::Round(($disk.FreeSpace / 1GB), 2)
            Write-Ok "$(Get-Text 'FreeSpace'): $free GB"
            if ($disk.FreeSpace -lt $bytes) {
                Write-WarnLine (Get-Text 'LowSpace')
            }
        }
    }
}

function Confirm-Action {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('Backup', 'Restore')]$Kind
    )
    if ($Force) { return $true }
    $q = Get-Text 'ConfirmBackup'
    if ($Kind -eq 'Restore') {
        $q = Get-Text 'ConfirmRestore'
    }
    if ($script:IsGui) {
        $detail = $q + [Environment]::NewLine + [Environment]::NewLine + "$(Get-Text 'ConfirmPc') '$($script:PcName)' ?"
        $answer = [System.Windows.Forms.MessageBox]::Show(
            $detail,
            (Get-Text 'Title'),
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
            Write-WarnLine (Get-Text 'Cancelled')
            return $false
        }
        return $true
    }
    if (-not (Read-YesNo $q $true)) {
        Write-WarnLine (Get-Text 'Cancelled')
        return $false
    }
    if (-not (Read-YesNo "$(Get-Text 'ConfirmPc') '$($script:PcName)' ?" $true)) {
        Write-WarnLine (Get-Text 'Cancelled')
        return $false
    }
    return $true
}

function Read-RestoreItemSet {
    Write-Host ''
    Write-Host '  1 UserData   2 Bookmarks   3 Browsers   4 Printers' -ForegroundColor Cyan
    Write-Host '  5 Network    6 OneNote     7 Signatures 8 Firefox' -ForegroundColor Cyan
    Write-Host '  9 Full       W WiFi        S StickyNotes' -ForegroundColor Cyan
    $choice = Read-Host (Get-Text 'Choice')
    switch -Regex ($choice.Trim()) {
        '^1$' { return @('UserData') }
        '^2$' { return @('Bookmarks') }
        '^3$' { return @('Browsers', 'Signatures', 'OneNote') }
        '^4$' { return @('Printers') }
        '^5$' { return @('NetworkDrives') }
        '^6$' { return @('OneNote') }
        '^7$' { return @('Signatures') }
        '^8$' { return @('Firefox') }
        '^9$' { return @('Full') }
        '^(w|W)$' { return @('WiFi') }
        '^(s|S)$' { return @('StickyNotes') }
        default { return $null }
    }
}

function Show-MainMenu {
    Write-Host (Get-Text 'MenuHeader') -ForegroundColor White
    Write-Host ("-" * 64)
    Write-Host "  Drive: $($script:BackupDriveLetter):   PC folder: $($script:PcName)" -ForegroundColor DarkCyan
    Write-Host ''
    Write-Host (Get-Text 'BackupHeader') -ForegroundColor Green
    Write-Host (Get-Text 'M1') -ForegroundColor Green
    Write-Host (Get-Text 'M2') -ForegroundColor Green
    Write-Host (Get-Text 'M3') -ForegroundColor Green
    Write-Host (Get-Text 'M4') -ForegroundColor Cyan
    Write-Host (Get-Text 'M5') -ForegroundColor Cyan
    Write-Host (Get-Text 'M6') -ForegroundColor Yellow
    Write-Host (Get-Text 'M7') -ForegroundColor Yellow
    Write-Host (Get-Text 'M8') -ForegroundColor Yellow
    Write-Host (Get-Text 'M9') -ForegroundColor Red
    Write-Host (Get-Text 'MW') -ForegroundColor Magenta
    Write-Host (Get-Text 'MS') -ForegroundColor Yellow
    Write-Host ''
    Write-Host (Get-Text 'RestoreHeader') -ForegroundColor Blue
    Write-Host (Get-Text 'MR') -ForegroundColor Blue
    Write-Host (Get-Text 'MC') -ForegroundColor Blue
    Write-Host ''
    Write-Host (Get-Text 'MQ')
    Write-Host ("-" * 64)
}

function Start-InteractiveSession {
    Write-Title
    if (-not $Language) {
        $pick = Read-Host (Get-Text 'PickLanguage')
        if ($pick -match '^(fr|f|francais)$') {
            $script:Language = 'fr'
        }
        elseif ($pick -match '^(en|e|english)$') {
            $script:Language = 'en'
        }
        Write-Title
    }

    Initialize-BackupLocation
    Start-BackupTranscript
    try {
        Show-SizeEstimate
        $loop = $true
        while ($loop) {
            Write-Host ''
            Show-MainMenu
            $choice = Read-Host (Get-Text 'Choice')
            if ([string]::IsNullOrWhiteSpace($choice)) {
                continue
            }
            $choice = $choice.Trim()
            try {
                switch -Regex ($choice) {
                    '^1$' {
                        if (Confirm-Action Backup) { Invoke-BackupSet -Sets @('UserData') }
                    }
                    '^2$' {
                        if (Confirm-Action Backup) { Invoke-BackupSet -Sets @('Bookmarks') }
                    }
                    '^3$' {
                        if (Confirm-Action Backup) { Invoke-BackupSet -Sets @('Browsers', 'Signatures', 'OneNote') }
                    }
                    '^4$' {
                        if (Confirm-Action Backup) { Invoke-BackupSet -Sets @('Printers') }
                    }
                    '^5$' {
                        if (Confirm-Action Backup) { Invoke-BackupSet -Sets @('NetworkDrives') }
                    }
                    '^6$' {
                        if (Confirm-Action Backup) { Invoke-BackupSet -Sets @('OneNote') }
                    }
                    '^7$' {
                        if (Confirm-Action Backup) { Invoke-BackupSet -Sets @('Signatures') }
                    }
                    '^8$' {
                        if (Confirm-Action Backup) { Invoke-BackupSet -Sets @('Firefox') }
                    }
                    '^9$' {
                        if (Confirm-Action Backup) { Invoke-BackupSet -Sets @('Full') }
                    }
                    '^(w|W)$' {
                        if (Confirm-Action Backup) { Invoke-BackupSet -Sets @('WiFi') }
                    }
                    '^(s|S)$' {
                        if (Confirm-Action Backup) { Invoke-BackupSet -Sets @('StickyNotes') }
                    }
                    '^(r|R)$' {
                        $sets = Read-RestoreItemSet
                        if (-not $sets) {
                            Write-WarnLine (Get-Text 'InvalidChoice')
                        }
                        elseif (Confirm-Action Restore) {
                            $restoreRoot = Resolve-BackupRoot -DriveLetter $script:BackupDriveLetter -PcName $script:PcName -ForRestore
                            if (-not $restoreRoot) {
                                throw (Get-Text 'RestoreMissing')
                            }
                            $script:BackupRoot = $restoreRoot
                            Invoke-RestoreSet -Sets $sets
                        }
                    }
                    '^(c|C)$' {
                        Show-BackupChecklist
                    }
                    '^(q|Q|11)$' {
                        $loop = $false
                    }
                    default {
                        Write-WarnLine (Get-Text 'InvalidChoice')
                    }
                }
            }
            catch {
                Write-ErrLine $_.Exception.Message
            }
            if ($loop) {
                Wait-Continue
            }
        }
    }
    finally {
        Stop-BackupTranscript
    }
    Write-Ok (Get-Text 'Done')
}

# -----------------------------------------------------------------------------
# Entry
# -----------------------------------------------------------------------------
try {
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    }
    catch { }

    if ($Mode -eq 'Gui') {
        $guiFile = Join-Path $PSScriptRoot 'UserBackup.Gui.ps1'
        if (-not (Test-Path -LiteralPath $guiFile)) {
            throw "GUI file not found: $guiFile"
        }
        . $guiFile
        Show-UserBackupGui
        exit 0
    }

    if ($Mode -eq 'Menu') {
        Start-InteractiveSession
        exit 0
    }

    Write-Title
    $forRestore = $Mode -eq 'Restore'
    Initialize-BackupLocation -ForRestore:$forRestore
    Start-BackupTranscript
    try {
        if (-not $ItemSet -or $ItemSet.Count -eq 0) {
            $ItemSet = @('Full')
        }
        if ($Mode -eq 'Backup') {
            Show-SizeEstimate
            if (-not (Confirm-Action Backup)) { exit 2 }
            Invoke-BackupSet -Sets $ItemSet
        }
        else {
            if (-not (Confirm-Action Restore)) { exit 2 }
            Invoke-RestoreSet -Sets $ItemSet
        }
    }
    finally {
        Stop-BackupTranscript
    }
    exit 0
}
catch {
    Write-ErrLine $_.Exception.Message
    Stop-BackupTranscript
    exit 1
}
