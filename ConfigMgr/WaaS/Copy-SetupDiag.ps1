<#
.SYNOPSIS
    Copy SetupDiag.exe to somewhere on disk.
    Use in a ConfigMgr application.
#>
[CmdletBinding()]
param (
    [Parameter()]
    [String]$FeatureUpdateTemp = "C:\~AdamCookFeatureUpdateTemp"
)

if (-not(Test-Path $CustomActionScriptsFolder)) {
    $null = New-Item -Path @(
        $CustomActionScriptsFolder
        "{0}\Scripts" -f $FeatureUpdateTemp
        "{0}\Logs" -f $FeatureUpdateTemp
    ) -ItemType "Directory" -Force -ErrorAction "Stop"
    $Folder = Get-Item -Path $FeatureUpdateTemp -Force -ErrorAction "SilentlyContinue"
    $Folder.Attributes = $Folder.Attributes -bor "Hidden"
}

Copy-Item -Path .\SetupDiag.exe -Destination $FeatureUpdateTemp -Force -ErrorAction "Stop"
