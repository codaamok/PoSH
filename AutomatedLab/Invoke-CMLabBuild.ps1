#Requires -Version 5.1 -Modules "AutomatedLab"
Param (
    [Switch]$ExcludePostInstall,
    [Switch]$PostInstallOnly,
    [Switch]$DoNotCopyFiles
)

if ($ExcludePostInstall.IsPresent -and $PostInstallOnly.IsPresent) {
    throw
}

if (-not $DoNotCopyFiles.IsPresent) {
    $Source = "{0}\CustomRoles\CM-1902\*" -f $PSScriptRoot
    $Destination = "{0}\CustomRoles\CM-1902\" -f $global:labSources
    Copy-Item -Path $Source -Destination $Destination -Recurse -Force -ErrorAction "Stop"
}

if ($ExcludePostInstall.IsPresent) {
    .\CM-1902.ps1 -AutoLogon -ExcludePostInstallations
}
elseif ($PostInstallOnly.IsPresent) {
    .\CM-1902.ps1 -SkipDomainCheck -SkipLabNameCheck -SkipHostnameCheck -PostInstallations
}
else {
    .\CM-1902.ps1 -AutoLogon -ExternalVMSwitchName "Internet2"
}