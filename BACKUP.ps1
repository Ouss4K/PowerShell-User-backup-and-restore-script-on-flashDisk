#Requires -Version 5.1
# Compatibility launcher (original filename). Prefer Start.cmd or UserBackup.ps1.
$forward = @($args | Where-Object { $null -ne $_ -and "$_".Trim() -ne '' })
if ($forward.Count -gt 0) {
    & (Join-Path $PSScriptRoot 'UserBackup.ps1') @forward
}
else {
    & (Join-Path $PSScriptRoot 'UserBackup.ps1')
}
