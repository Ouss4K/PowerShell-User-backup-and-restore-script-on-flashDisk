#Requires -Version 5.1
# Opens the same toolkit; choose R in the menu, or pass -Mode Restore.
$forward = @($args | Where-Object { $null -ne $_ -and "$_".Trim() -ne '' })
if ($forward.Count -gt 0) {
    & (Join-Path $PSScriptRoot 'UserBackup.ps1') @forward
}
else {
    & (Join-Path $PSScriptRoot 'UserBackup.ps1')
}
