<#
.SYNOPSIS
    Copy SetupDiag.exe to somewhere on disk.
    Use in a ConfigMgr application.
.NOTES
    Author: Adam Cook (@codaamok)
#>
[CmdletBinding()]
param (
    [Parameter()]
    [String]$FeatureUpdateTemp = "C:\~AdamCookFeatureUpdateTemp"
)

if (-not(Test-Path $FeatureUpdateTemp)) {
    $null = New-Item -Path @(
        "{0}\Scripts" -f $FeatureUpdateTemp
        "{0}\Logs" -f $FeatureUpdateTemp
    ) -ItemType "Directory" -Force -ErrorAction "Stop"
    $Folder = Get-Item -Path $FeatureUpdateTemp -Force -ErrorAction "SilentlyContinue"
    $Folder.Attributes = $Folder.Attributes -bor "Hidden"
}

Copy-Item -Path .\SetupDiag.exe -Destination $FeatureUpdateTemp\SetupDiag.exe -Force -ErrorAction "Stop"
