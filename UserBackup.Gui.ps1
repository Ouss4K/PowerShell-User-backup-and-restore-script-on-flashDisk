function Hide-HostConsoleWindow {
    try {
        if (-not ('UserBackup.NativeConsole' -as [type])) {
            Add-Type -Name NativeConsole -Namespace UserBackup -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@
        }
        $hwnd = [UserBackup.NativeConsole]::GetConsoleWindow()
        if ($hwnd -ne [IntPtr]::Zero) {
            [void][UserBackup.NativeConsole]::ShowWindow($hwnd, 0)
        }
    }
    catch {
        # Console may already be hidden.
    }
}

function Restart-GuiInSta {
    $state = [System.Threading.Thread]::CurrentThread.GetApartmentState()
    if ($state -eq 'STA') {
        return $false
    }
    $main = Join-Path $PSScriptRoot 'UserBackup.ps1'
    $argList = @(
        '-STA', '-NoLogo', '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-WindowStyle', 'Hidden',
        '-File', $main,
        '-Mode', 'Gui'
    )
    if ($script:Language) {
        $argList += @('-Language', $script:Language)
    }
    Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $argList
    return $true
}

function Show-GuiMessage {
    param(
        [string]$Text,
        [ValidateSet('Info', 'Warning', 'Error', 'Question')]
        [string]$Kind = 'Info'
    )
    if ([string]::IsNullOrWhiteSpace($Text)) {
        $Text = '(no details)'
    }
    $caption = 'USB User Backup'
    try {
        $caption = [string](Get-Text 'Title')
    }
    catch { }
    $icon = [System.Windows.Forms.MessageBoxIcon]::Information
    switch ($Kind) {
        'Warning'  { $icon = [System.Windows.Forms.MessageBoxIcon]::Warning }
        'Error'    { $icon = [System.Windows.Forms.MessageBoxIcon]::Stop }
        'Question' { $icon = [System.Windows.Forms.MessageBoxIcon]::Question }
    }
    [void][System.Windows.Forms.MessageBox]::Show(
        [string]$Text,
        [string]$caption,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        $icon
    )
}

function New-GuiFont {
    param(
        [string]$Family = 'Segoe UI',
        [double]$Size = 9,
        [string]$Style = 'Regular'
    )
    $styleVal = [System.Drawing.FontStyle]::Regular
    if ($Style -eq 'Bold') {
        $styleVal = [System.Drawing.FontStyle]::Bold
    }
    return New-Object System.Drawing.Font($Family, [float]$Size, $styleVal)
}

function New-GuiButton {
    param(
        [string]$Text,
        $BackColor,
        [int]$Width = 140,
        [int]$Height = 40
    )
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Width = $Width
    $button.Height = $Height
    $button.FlatStyle = 'Flat'
    $button.FlatAppearance.BorderSize = 0
    $button.BackColor = $BackColor
    $button.ForeColor = [System.Drawing.Color]::White
    $button.Font = New-GuiFont -Family 'Segoe UI' -Size 10 -Style Bold
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    return $button
}

function Show-UserBackupGui {
    if (Restart-GuiInSta) {
        return
    }

    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        [System.Windows.Forms.Application]::EnableVisualStyles()
    }
    catch {
        Write-ErrLine $_.Exception.Message
        Write-WarnLine 'GUI is not available. Starting console menu.'
        Start-InteractiveSession
        return
    }

    $script:IsGui = $true
    Hide-HostConsoleWindow

    $colorBg = [System.Drawing.Color]::FromArgb(18, 24, 33)
    $colorPanel = [System.Drawing.Color]::FromArgb(27, 36, 49)
    $colorHeader = [System.Drawing.Color]::FromArgb(12, 17, 24)
    $colorInput = [System.Drawing.Color]::FromArgb(36, 48, 66)
    $colorText = [System.Drawing.Color]::FromArgb(232, 238, 244)
    $colorMuted = [System.Drawing.Color]::FromArgb(150, 164, 184)
    $colorBackup = [System.Drawing.Color]::FromArgb(31, 140, 90)
    $colorRestore = [System.Drawing.Color]::FromArgb(37, 99, 175)
    $colorVerify = [System.Drawing.Color]::FromArgb(90, 70, 160)
    $colorMutedBtn = [System.Drawing.Color]::FromArgb(58, 72, 92)

    $form = New-Object System.Windows.Forms.Form
    $form.Text = Get-Text 'Title'
    $form.StartPosition = 'CenterScreen'
    $form.Size = New-Object System.Drawing.Size(1000, 740)
    $form.MinimumSize = New-Object System.Drawing.Size(880, 640)
    $form.BackColor = $colorBg
    $form.ForeColor = $colorText
    $form.Font = New-GuiFont -Family 'Segoe UI' -Size 9
    $form.KeyPreview = $true

    $header = New-Object System.Windows.Forms.Panel
    $header.Dock = 'Top'
    $header.Height = 78
    $header.BackColor = $colorHeader

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.AutoSize = $true
    $titleLabel.Location = New-Object System.Drawing.Point(22, 14)
    $titleLabel.Font = New-GuiFont -Family 'Segoe UI' -Size 16 -Style Bold
    $titleLabel.ForeColor = $colorText
    $header.Controls.Add($titleLabel)

    $subtitleLabel = New-Object System.Windows.Forms.Label
    $subtitleLabel.AutoSize = $true
    $subtitleLabel.Location = New-Object System.Drawing.Point(24, 46)
    $subtitleLabel.ForeColor = $colorMuted
    $header.Controls.Add($subtitleLabel)

    $langEn = New-Object System.Windows.Forms.RadioButton
    $langEn.Text = 'EN'
    $langEn.AutoSize = $true
    $langEn.ForeColor = $colorText
    $langEn.Anchor = 'Top, Right'
    $header.Controls.Add($langEn)

    $langFr = New-Object System.Windows.Forms.RadioButton
    $langFr.Text = 'FR'
    $langFr.AutoSize = $true
    $langFr.ForeColor = $colorText
    $langFr.Anchor = 'Top, Right'
    $header.Controls.Add($langFr)

    $footer = New-Object System.Windows.Forms.Panel
    $footer.Dock = 'Bottom'
    $footer.Height = 70
    $footer.BackColor = $colorHeader

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.AutoSize = $false
    $statusLabel.Location = New-Object System.Drawing.Point(20, 24)
    $statusLabel.Size = New-Object System.Drawing.Size(360, 24)
    $statusLabel.ForeColor = $colorMuted
    $footer.Controls.Add($statusLabel)

    $btnEstimate = New-GuiButton -Text '' -BackColor $colorMutedBtn -Width 130
    $btnVerify = New-GuiButton -Text '' -BackColor $colorVerify -Width 120
    $btnRestore = New-GuiButton -Text '' -BackColor $colorRestore -Width 140
    $btnBackup = New-GuiButton -Text '' -BackColor $colorBackup -Width 150
    foreach ($b in @($btnEstimate, $btnVerify, $btnRestore, $btnBackup)) {
        $b.Anchor = 'Top, Right'
        $footer.Controls.Add($b)
    }

    $left = New-Object System.Windows.Forms.Panel
    $left.Dock = 'Left'
    $left.Width = 420
    $left.BackColor = $colorPanel
    $left.Padding = New-Object System.Windows.Forms.Padding(18)
    $left.AutoScroll = $true

    $driveLabel = New-Object System.Windows.Forms.Label
    $driveLabel.AutoSize = $true
    $driveLabel.Location = New-Object System.Drawing.Point(20, 18)
    $driveLabel.ForeColor = $colorMuted
    $left.Controls.Add($driveLabel)

    $driveBox = New-Object System.Windows.Forms.ComboBox
    $driveBox.DropDownStyle = 'DropDownList'
    $driveBox.Location = New-Object System.Drawing.Point(20, 40)
    $driveBox.Size = New-Object System.Drawing.Size(270, 28)
    try {
        $driveBox.BackColor = $colorInput
        $driveBox.ForeColor = $colorText
        $driveBox.FlatStyle = 'Flat'
    }
    catch {
        $driveBox.FlatStyle = 'Standard'
    }
    $left.Controls.Add($driveBox)

    $btnRefresh = New-GuiButton -Text '' -BackColor $colorMutedBtn -Width 90 -Height 28
    $btnRefresh.Location = New-Object System.Drawing.Point(300, 39)
    $btnRefresh.Height = 28
    $btnRefresh.Font = New-GuiFont -Family 'Segoe UI' -Size 9
    $left.Controls.Add($btnRefresh)

    $pcLabel = New-Object System.Windows.Forms.Label
    $pcLabel.AutoSize = $true
    $pcLabel.Location = New-Object System.Drawing.Point(20, 80)
    $pcLabel.ForeColor = $colorMuted
    $left.Controls.Add($pcLabel)

    $pcBox = New-Object System.Windows.Forms.TextBox
    $pcBox.Location = New-Object System.Drawing.Point(20, 102)
    $pcBox.Size = New-Object System.Drawing.Size(370, 28)
    $pcBox.BackColor = $colorInput
    $pcBox.ForeColor = $colorText
    $pcBox.BorderStyle = 'FixedSingle'
    if ($ComputerName) {
        $pcBox.Text = $ComputerName
    }
    else {
        $pcBox.Text = $env:COMPUTERNAME
    }
    $left.Controls.Add($pcBox)

    $pathLabel = New-Object System.Windows.Forms.Label
    $pathLabel.AutoSize = $true
    $pathLabel.Location = New-Object System.Drawing.Point(20, 142)
    $pathLabel.ForeColor = $colorMuted
    $left.Controls.Add($pathLabel)

    $pathValue = New-Object System.Windows.Forms.Label
    $pathValue.Location = New-Object System.Drawing.Point(20, 164)
    $pathValue.Size = New-Object System.Drawing.Size(370, 40)
    $pathValue.ForeColor = [System.Drawing.Color]::FromArgb(110, 210, 255)
    $left.Controls.Add($pathValue)

    $itemsLabel = New-Object System.Windows.Forms.Label
    $itemsLabel.AutoSize = $true
    $itemsLabel.Location = New-Object System.Drawing.Point(20, 210)
    $itemsLabel.ForeColor = $colorMuted
    $left.Controls.Add($itemsLabel)

    $itemIds = @(
        @{ Id = 'UserData'; Key = 'GuiItemUserData' }
        @{ Id = 'Bookmarks'; Key = 'GuiItemBookmarks' }
        @{ Id = 'Browsers'; Key = 'GuiItemBrowsers' }
        @{ Id = 'Signatures'; Key = 'GuiItemSignatures' }
        @{ Id = 'OneNote'; Key = 'GuiItemOneNote' }
        @{ Id = 'StickyNotes'; Key = 'GuiItemSticky' }
        @{ Id = 'Printers'; Key = 'GuiItemPrinters' }
        @{ Id = 'NetworkDrives'; Key = 'GuiItemNetwork' }
        @{ Id = 'WiFi'; Key = 'GuiItemWifi' }
        @{ Id = 'Firefox'; Key = 'GuiItemFirefox' }
    )
    $checks = @{}
    $y = 232
    foreach ($item in $itemIds) {
        $box = New-Object System.Windows.Forms.CheckBox
        $box.Tag = $item.Id
        $box.AutoSize = $true
        $box.Location = New-Object System.Drawing.Point(22, $y)
        $box.ForeColor = $colorText
        $box.BackColor = $colorPanel
        $left.Controls.Add($box)
        $checks[$item.Id] = $box
        $y += 26
    }

    $btnRecommended = New-GuiButton -Text '' -BackColor $colorMutedBtn -Width 118 -Height 30
    $btnAll = New-GuiButton -Text '' -BackColor $colorMutedBtn -Width 90 -Height 30
    $btnNone = New-GuiButton -Text '' -BackColor $colorMutedBtn -Width 90 -Height 30
    $btnRecommended.Location = New-Object System.Drawing.Point(20, ($y + 8))
    $btnAll.Location = New-Object System.Drawing.Point(146, ($y + 8))
    $btnNone.Location = New-Object System.Drawing.Point(244, ($y + 8))
    foreach ($b in @($btnRecommended, $btnAll, $btnNone)) {
        $b.Font = New-GuiFont -Family 'Segoe UI' -Size 9
        $left.Controls.Add($b)
    }

    $dryRunBox = New-Object System.Windows.Forms.CheckBox
    $dryRunBox.AutoSize = $true
    $dryRunBox.Location = New-Object System.Drawing.Point(22, ($y + 48))
    $dryRunBox.ForeColor = $colorText
    $dryRunBox.BackColor = $colorPanel
    $dryRunBox.Checked = [bool]$WhatIfPreference
    $left.Controls.Add($dryRunBox)

    $logPanel = New-Object System.Windows.Forms.Panel
    $logPanel.Dock = 'Fill'
    $logPanel.BackColor = $colorBg
    $logPanel.Padding = New-Object System.Windows.Forms.Padding(16)
    $form.Controls.Add($logPanel)
    $form.Controls.Add($left)
    $form.Controls.Add($footer)
    $form.Controls.Add($header)

    $logLabel = New-Object System.Windows.Forms.Label
    $logLabel.AutoSize = $true
    $logLabel.Location = New-Object System.Drawing.Point(16, 12)
    $logLabel.ForeColor = $colorMuted
    $logPanel.Controls.Add($logLabel)

    $logBox = New-Object System.Windows.Forms.RichTextBox
    $logBox.Location = New-Object System.Drawing.Point(16, 36)
    $logBox.Anchor = 'Top, Bottom, Left, Right'
    $logBox.ReadOnly = $true
    $logBox.BackColor = [System.Drawing.Color]::FromArgb(10, 14, 20)
    $logBox.ForeColor = $colorText
    $logBox.BorderStyle = 'None'
    $logBox.Font = New-GuiFont -Family 'Consolas' -Size 9
    $logBox.DetectUrls = $false
    $logPanel.Controls.Add($logBox)
    $script:LogBox = $logBox

    $actionButtons = @($btnBackup, $btnRestore, $btnVerify, $btnEstimate, $btnRefresh, $btnRecommended, $btnAll, $btnNone)

    function Get-SelectedDriveLetter {
        if (-not $driveBox.SelectedItem) {
            return $null
        }
        $text = [string]$driveBox.SelectedItem
        if ($text.Length -lt 1) {
            return $null
        }
        return $text.Substring(0, 1)
    }

    function Update-PathPreview {
        $letter = Get-SelectedDriveLetter
        $name = Get-SafeFolderName $pcBox.Text
        if ($letter) {
            $pathValue.Text = "${letter}:\UserBackup\$name"
        }
        else {
            $pathValue.Text = (Get-Text 'NoDrive')
        }
    }

    function Apply-GuiLanguage {
        $form.Text = Get-Text 'Title'
        $titleLabel.Text = Get-Text 'Title'
        $subtitleLabel.Text = Get-Text 'Subtitle'
        $driveLabel.Text = Get-Text 'GuiDrive'
        $btnRefresh.Text = Get-Text 'GuiRefresh'
        $pcLabel.Text = Get-Text 'GuiPcName'
        $pathLabel.Text = Get-Text 'GuiPath'
        $itemsLabel.Text = Get-Text 'GuiItems'
        $btnRecommended.Text = Get-Text 'GuiRecommended'
        $btnAll.Text = Get-Text 'GuiSelectAll'
        $btnNone.Text = Get-Text 'GuiSelectNone'
        $dryRunBox.Text = Get-Text 'GuiDryRun'
        $btnBackup.Text = Get-Text 'GuiBackup'
        $btnRestore.Text = Get-Text 'GuiRestore'
        $btnVerify.Text = Get-Text 'GuiVerify'
        $btnEstimate.Text = Get-Text 'GuiEstimate'
        $logLabel.Text = Get-Text 'GuiLog'
        if ([string]::IsNullOrWhiteSpace($statusLabel.Text) -or $statusLabel.Text -eq 'Ready' -or $statusLabel.Text -eq 'Pret' -or $statusLabel.Text -eq (Get-Text 'GuiReady')) {
            $statusLabel.Text = Get-Text 'GuiReady'
        }
        foreach ($item in $itemIds) {
            $checks[$item.Id].Text = Get-Text $item.Key
        }
        Update-PathPreview
        $form.PerformLayout()
    }

    function Set-CheckSelection {
        param([string[]]$Ids)
        if (-not $Ids) {
            $Ids = @()
        }
        foreach ($item in $itemIds) {
            $checks[$item.Id].Checked = ($Ids -contains $item.Id)
        }
    }

    function Get-CheckedSets {
        foreach ($item in $itemIds) {
            if ($checks[$item.Id].Checked) {
                $item.Id
            }
        }
    }

    function Refresh-DriveList {
        $previous = Get-SelectedDriveLetter
        $driveBox.Items.Clear()
        $drives = @(Get-CandidateBackupDrives)
        $drives = @($drives | Sort-Object @{
                Expression = { if ($_.DriveType -eq 2) { 0 } else { 1 } }
            }, @{
                Expression = { $_.FreeGB }
                Descending = $true
            }, Letter)
        foreach ($d in $drives) {
            $line = '{0}:  {1}  {2} GB free  {3}' -f $d.Letter, $d.Kind, $d.FreeGB, $d.Label
            [void]$driveBox.Items.Add($line)
        }

        $index = -1
        if ($previous) {
            for ($i = 0; $i -lt $driveBox.Items.Count; $i++) {
                if (([string]$driveBox.Items[$i]).StartsWith($previous, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $index = $i
                    break
                }
            }
        }
        if ($index -lt 0) {
            $preferred = @($drives | Where-Object { -not $_.IsSystem })
            if ($preferred.Count -eq 0) {
                $preferred = $drives
            }
            if ($preferred.Count -gt 0) {
                $want = [string]$preferred[0].Letter
                for ($i = 0; $i -lt $driveBox.Items.Count; $i++) {
                    if (([string]$driveBox.Items[$i]).StartsWith($want, [System.StringComparison]::OrdinalIgnoreCase)) {
                        $index = $i
                        break
                    }
                }
            }
        }
        if ($index -lt 0 -and $driveBox.Items.Count -gt 0) {
            $index = 0
        }
        if ($index -ge 0) {
            $driveBox.SelectedIndex = $index
        }
        Update-PathPreview
        if ($driveBox.Items.Count -eq 0) {
            Write-WarnLine (Get-Text 'NoDrive')
        }
    }

    function Set-GuiBusy {
        param([bool]$Busy)
        $form.UseWaitCursor = $Busy
        foreach ($b in $actionButtons) {
            $b.Enabled = -not $Busy
        }
        $driveBox.Enabled = -not $Busy
        $pcBox.Enabled = -not $Busy
        $dryRunBox.Enabled = -not $Busy
        if ($Busy) {
            $statusLabel.Text = Get-Text 'GuiWorking'
        }
        else {
            $statusLabel.Text = Get-Text 'GuiReady'
        }
        [System.Windows.Forms.Application]::DoEvents()
    }

    function Initialize-GuiJob {
        param([switch]$ForRestore)
        $letter = Get-SelectedDriveLetter
        if (-not $letter) {
            throw (Get-Text 'DriveMissing')
        }
        $script:DryRun = [bool]$dryRunBox.Checked
        Initialize-BackupLocation -ForRestore:$ForRestore -DriveLetter $letter -PcName $pcBox.Text
        Update-PathPreview
        Start-BackupTranscript
    }

    $layoutFooter = {
        try {
            $right = $footer.ClientSize.Width - 20
            if ($right -lt 200) { return }
            foreach ($b in @($btnBackup, $btnRestore, $btnVerify, $btnEstimate)) {
                $x = $right - $b.Width
                if ($x -lt 8) { $x = 8 }
                $b.Location = New-Object System.Drawing.Point([int]$x, 15)
                $right = $b.Location.X - 12
            }
            $hw = $header.ClientSize.Width
            if ($hw -gt 130) {
                $langFr.Location = New-Object System.Drawing.Point(($hw - 58), 28)
                $langEn.Location = New-Object System.Drawing.Point(($hw - 108), 28)
            }
            $lw = [Math]::Max(80, $logPanel.ClientSize.Width - 32)
            $lh = [Math]::Max(80, $logPanel.ClientSize.Height - 52)
            $logBox.Size = New-Object System.Drawing.Size([int]$lw, [int]$lh)
        }
        catch {
            # Layout can run before handles exist.
        }
    }

    $form.Add_Resize({
        try { & $layoutFooter } catch { }
    })
    $driveBox.Add_SelectedIndexChanged({ Update-PathPreview })
    $pcBox.Add_TextChanged({ Update-PathPreview })
    $btnRefresh.Add_Click({
        try { Refresh-DriveList } catch { Write-ErrLine $_.Exception.Message }
    })
    $btnRecommended.Add_Click({ Set-CheckSelection @('UserData', 'Bookmarks', 'Signatures', 'Printers', 'NetworkDrives') })
    $btnAll.Add_Click({ Set-CheckSelection @('UserData', 'Browsers', 'Signatures', 'OneNote', 'StickyNotes', 'Printers', 'NetworkDrives', 'WiFi') })
    $btnNone.Add_Click({ Set-CheckSelection @() })

    $langEn.Add_CheckedChanged({
        if ($langEn.Checked) {
            try {
                $script:Language = 'en'
                Apply-GuiLanguage
            }
            catch {
                Write-ErrLine $_.Exception.Message
            }
        }
    })
    $langFr.Add_CheckedChanged({
        if ($langFr.Checked) {
            try {
                $script:Language = 'fr'
                Apply-GuiLanguage
            }
            catch {
                Write-ErrLine $_.Exception.Message
            }
        }
    })

    $btnBackup.Add_Click({
        $sets = @(Get-CheckedSets | Where-Object { $_ })
        if ($sets.Count -eq 0) {
            Show-GuiMessage -Text (Get-Text 'GuiPickItems') -Kind Info
            return
        }
        Set-GuiBusy $true
        try {
            Initialize-GuiJob
            if (Confirm-Action Backup) {
                Invoke-BackupSet -Sets ([string[]]$sets)
                Show-GuiMessage -Text (Get-Text 'BackupComplete') -Kind Info
            }
        }
        catch {
            Write-ErrLine $_.Exception.Message
            Show-GuiMessage -Text $_.Exception.Message -Kind Error
        }
        finally {
            Stop-BackupTranscript
            Set-GuiBusy $false
        }
    })

    $btnRestore.Add_Click({
        $sets = @(Get-CheckedSets | Where-Object { $_ })
        if ($sets.Count -eq 0) {
            Show-GuiMessage -Text (Get-Text 'GuiPickItems') -Kind Info
            return
        }
        Set-GuiBusy $true
        try {
            Initialize-GuiJob -ForRestore
            if (Confirm-Action Restore) {
                Invoke-RestoreSet -Sets ([string[]]$sets)
                Show-GuiMessage -Text (Get-Text 'RestoreComplete') -Kind Info
            }
        }
        catch {
            Write-ErrLine $_.Exception.Message
            Show-GuiMessage -Text $_.Exception.Message -Kind Error
        }
        finally {
            Stop-BackupTranscript
            Set-GuiBusy $false
        }
    })

    $btnVerify.Add_Click({
        Set-GuiBusy $true
        try {
            Initialize-GuiJob -ForRestore
            Show-BackupChecklist
        }
        catch {
            Write-ErrLine $_.Exception.Message
            Show-GuiMessage -Text $_.Exception.Message -Kind Error
        }
        finally {
            Stop-BackupTranscript
            Set-GuiBusy $false
        }
    })

    $btnEstimate.Add_Click({
        Set-GuiBusy $true
        try {
            Initialize-GuiJob
            Show-SizeEstimate
        }
        catch {
            Write-ErrLine $_.Exception.Message
            Show-GuiMessage -Text $_.Exception.Message -Kind Error
        }
        finally {
            Stop-BackupTranscript
            Set-GuiBusy $false
        }
    })

    $form.Add_Shown({
        try {
            if ($script:Language -eq 'fr') { $langFr.Checked = $true } else { $langEn.Checked = $true }
            Apply-GuiLanguage
            Refresh-DriveList
            Set-CheckSelection @('UserData', 'Bookmarks', 'Signatures', 'Printers', 'NetworkDrives')
            & $layoutFooter
            Write-Ok (Get-Text 'GuiReady')
            if ($env:USERBACKUP_GUI_TEST -eq '1') {
                $testOut = Join-Path $env:TEMP 'UserBackup-gui-test.txt'
                $letter = Get-SelectedDriveLetter
                $sets = @(Get-CheckedSets | Where-Object { $_ })
                $report = @(
                    'OK'
                    "letter=$letter"
                    "path=$($pathValue.Text)"
                    "sets=$($sets -join ',')"
                    "drives=$($driveBox.Items.Count)"
                ) -join [Environment]::NewLine
                [System.IO.File]::WriteAllText($testOut, $report)
                $form.Close()
            }
        }
        catch {
            Write-ErrLine $_.Exception.Message
            if ($env:USERBACKUP_GUI_TEST -eq '1') {
                [System.IO.File]::WriteAllText((Join-Path $env:TEMP 'UserBackup-gui-test.txt'), $_.Exception.ToString())
                try { $form.Close() } catch { }
            }
            try {
                Show-GuiMessage -Text $_.Exception.Message -Kind Error
            }
            catch { }
        }
    })

    $form.Add_FormClosed({
        $script:LogBox = $null
        $script:IsGui = $false
        Stop-BackupTranscript
    })

    [void]$form.ShowDialog()
}
