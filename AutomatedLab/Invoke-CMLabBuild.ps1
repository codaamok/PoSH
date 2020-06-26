#Requires -Version 5.1 -Modules "AutomatedLab"
Param (
    [Parameter(Mandatory)]
    [ValidateSet("CM-1902", "CM-2002")]
    [String]$CustomRoleVersion,
    [Parameter(Mandatory)]
    [ValidateSet("TP", "CB")]
    [String]$Branch,
    [Switch]$ExcludePostInstall,
    [Switch]$PostInstallOnly,
    [Switch]$DoNotCopyFiles
)

if ($ExcludePostInstall.IsPresent -and $PostInstallOnly.IsPresent) {
    throw
}

if (-not $DoNotCopyFiles.IsPresent) {
    $Source = "{0}\CustomRoles\{1}\*" -f $PSScriptRoot, $CustomRoleVersion
    $Destination = "{0}\CustomRoles\{1}\" -f $global:labSources, $CustomRoleVersion
    foreach ($folder in @($Source, $Destination)) {
        if (-not (Test-Path $folder)) {
            New-Item -Path $folder -ItemType Directory -Force -ErrorAction "Stop"
        }
    }
    Copy-Item -Path $Source -Destination $Destination -Recurse -Force -ErrorAction "Stop"
}

$Arguments = @{}

if ($ExcludePostInstall.IsPresent) {
    $Arguments["AutoLogon"] = $true
    $Arguments["ExcludePostInstallations"] = $true
}
elseif ($PostInstallOnly.IsPresent) {
    $Arguments["SkipDomainCheck"]   = $true
    $Arguments["SkipLabNameCheck"]  = $true
    $Arguments["SkipHostnameCheck"] = $true
    $Arguments["PostInstallations"] = $true
}
else {
    $Arguments["AutoLogon"] = $true
}

& .\$CustomRoleVersion.ps1 @Arguments -Branch $Branch