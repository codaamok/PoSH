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

function Remove-NTFSInheritance {
    param (
        [Parameter(Mandatory)]
        [String]$Path
    )
    $isProtected = $true
    $preserveInheritance = $true
    $DirectorySecurity = Get-ACL $Path
    $DirectorySecurity.SetAccessRuleProtection($isProtected, $preserveInheritance)
    Set-ACL $Path -AclObject $DirectorySecurity
}

function Remove-NTFSIdentity {
    param (
        [Parameter(Mandatory)]
        [String]$Path,

        [Parameter(Mandatory)]
        [String[]]$Identity
    )
    $ACL = Get-ACL -Path $Path -ErrorAction "Stop"
    $Rules = foreach ($id in $identity) {
        $ACL.Access | Where-Object { -not $_.IsInherited -and $_.IdentityReference -eq $id }
    }
    foreach ($Rule in $Rules) {
        $null = $ACL.RemoveAccessRuleAll($Rule)
    }
    Set-ACL -Path $Path -AclObject $ACL
}

Remove-NTFSInheritance -Path $FeatureUpdateTemp
Remove-NTFSIdentity -Path $FeatureUpdateTemp -Identity "NT AUTHORITY\Authenticated Users"

if (-not(Test-Path $FeatureUpdateTemp)) {
    $null = New-Item -Path @(
        "{0}\Scripts" -f $FeatureUpdateTemp
        "{0}\Logs" -f $FeatureUpdateTemp
    ) -ItemType "Directory" -Force -ErrorAction "Stop"
    $Folder = Get-Item -Path $FeatureUpdateTemp -Force -ErrorAction "SilentlyContinue"
    $Folder.Attributes = $Folder.Attributes -bor "Hidden"
}

Copy-Item -Path .\SetupDiag.exe -Destination $FeatureUpdateTemp\SetupDiag.exe -Force -ErrorAction "Stop"
