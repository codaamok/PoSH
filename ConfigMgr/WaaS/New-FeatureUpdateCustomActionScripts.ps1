<#
.SYNOPSIS
    Generate custom action scripts for Windows 10 Feature Updates.
    Use in a ConfigMgr CI, although this always "remediates", i.e. it overwrites the generated files with each invocation.
.NOTES
    Author: Adam Cook (@codaamok)
#>
[CmdletBinding()]
param (
    [Parameter()]
    [String]$FeatureUpdateTemp = "C:\~AdamCookFeatureUpdateTemp",

    [Parameter()]
    [String[]]$Scripts = @(
        "failure.cmd",
        "precommit.cmd",
        "preinstall.cmd",
        "setupcomplete.cmd"
    ),

    [Parameter()]
    [String]$GUID = "fdc3f7c8-a0ce-40c2-9e6c-a0669eb7e054"
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

$LogPath = "{0}\Logs" -f $FeatureUpdateTemp
$CustomActionScriptsFolder = "{0}\System32\update\run\{1}" -f $env:windir, $GUID

@(
    $CustomActionScriptsFolder
    "{0}\Scripts" -f $FeatureUpdateTemp
    "{0}\Logs" -f $FeatureUpdateTemp
) | ForEach-Object {
    if (-not (Test-Path $_)) {
        $null = New-Item -Path $_ -ItemType "Directory" -Force -ErrorAction "Stop"
    }
}

Remove-NTFSInheritance -Path $FeatureUpdateTemp
Remove-NTFSIdentity -Path $FeatureUpdateTemp -Identity "NT AUTHORITY\Authenticated Users"

$Folder = Get-Item -Path $FeatureUpdateTemp -Force -ErrorAction "SilentlyContinue"
$Folder.Attributes = $Folder.Attributes -bor "Hidden"

$CommonLines = {
    param (
        [String]$Action,
        [String[]]$Lines,
        [String]$LogPath
    )
    '@ECHO ON'
    'echo %DATE% %TIME% - Started {0} >> {1}\FeatureUpdate.log' -f $Action, $LogPath
    $Lines
    'echo %DATE% %TIME% - Finished {0} >> {1}\FeatureUpdate.log' -f $Action, $LogPath
}

switch ($Scripts) {
    "failure.cmd" {
        $FailureLines = @(
            'echo %DATE% %TIME% - Running SetupDiag.exe >> {0}\FeatureUpdate.log' -f $LogPath
            '{0}\SetupDiag.exe /AddReg /Output:{1}\SetupDiag.xml /Format:XML /Verbose' -f $FeatureUpdateTemp, $LogPath
        )
        $File = "{0}\{1}" -f $CustomActionScriptsFolder, $_
        & $CommonLines -Action ($_ -replace "\.cmd") -Lines $FailureLines -LogPath $LogPath | Set-Content -Path $File -Force -ErrorAction "Stop"
    }
    "precommit.cmd" {
        $PreCommitLines = @(

        )
        $File = "{0}\{1}" -f $CustomActionScriptsFolder, $_
        & $CommonLines -Action ($_ -replace "\.cmd") -Lines $PreCommitLines -LogPath $LogPath | Set-Content -Path $File -Force -ErrorAction "Stop"
    }
    "preinstall.cmd" {
        $PreInstallLines = @(

        )
        $File = "{0}\{1}" -f $CustomActionScriptsFolder, $_
        & $CommonLines -Action ($_ -replace "\.cmd") -Lines $PreInstallLines -LogPath $LogPath | Set-Content -Path $File -Force -ErrorAction "Stop"
    }
    "setupcomplete.cmd" {
        $SetupCompleteLines = @(
            'echo %DATE% %TIME% - Running SetupDiag.exe >> {0}\FeatureUpdate.log' -f $LogPath
            '{0}\SetupDiag.exe /AddReg /Output:{1}\SetupDiag.xml /Format:XML /Verbose' -f $FeatureUpdateTemp, $LogPath
        )
        $File = "{0}\Scripts\{1}" -f $FeatureUpdateTemp, $_
        & $CommonLines -Action ($_ -replace "\.cmd") -Lines $SetupCompleteLines -LogPath $LogPath | Set-Content -Path $File -Force -ErrorAction "Stop"
    }
}

$true
