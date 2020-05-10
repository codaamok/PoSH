<#
.SYNOPSIS
    Add or remove key/value pairs to SetupConfig.ini for Windows 10 feature updates.
    Use in a ConfigMgr CI.
.NOTES
    Author: Adam Cook (@codaamok)
    A heavily modified version of https://github.com/AdamGrossTX/Windows10FeatureUpdates/blob/master/Admin/ComplianceScripts/FeatureUpdateCIScript.ps1
#>
[CmdletBinding()]
param (
    [Parameter()]
    [String]$ActualValue,

    [Parameter()]
    [Bool]$Remediate = $true,

    [Parameter()]
    [String]$FeatureUpdateTemp = "C:\~AdamCookFeatureUpdateTemp",

    [Parameter()]
    [System.Collections.Specialized.OrderedDictionary]$Config = [ordered]@{
        "SetupConfig" = [ordered]@{
            "BitLocker"             = "AlwaysSuspend"
            "Compat"                = "IgnoreWarning"
            "Priority"              = "Normal"
            "DynamicUpdate"         = "Enable"
            "ShowOOBE"              = "None"
            "Telemetry"             = "Enable"
            "DiagnosticPrompt"      = "Enable"
            #"PKey"                 = "NPPR9-FWDCX-D2C8J-H872K-2YT43"
            "PostOOBE"              = "{0}\Scripts\SetupComplete.cmd" -f $FeatureUpdateTemp
            #"PostRollBack"         = "{0}\Scripts\ErrorHandler.cmd" -f $FeatureUpdateTemp
            #"PostRollBackContext"  = "System"
            "CopyLogs"              = "\\sccm.acc.local\FeatureUpdateFailedLogs\$($ENV:COMPUTERNAME)"
            #"InstallDrivers"       = "C:\Windows\Temp\PathToDrivers" # Consider adding this if we need it in the future
            #"MigrateDrivers"       = "C:\Windows\Temp\PathToDrivers" # Consider adding this if we need it in the future
        }
    },

    [Parameter()]
    [String]$SourceIniFile = "$($env:SystemDrive)\Users\Default\AppData\Local\Microsoft\Windows\WSUS\SetupConfig.ini",

    [Parameter()]
    [String]$DestIniFile,

    [Parameter()]
    [switch]$AlwaysReWrite
)

function Compare-Hashtable {
    <#
    .SYNOPSIS
        Compares two hashtables, returns equal and different key pairs.
    .NOTES
        https://gist.github.com/dbroeglin/c6ce3e4639979fa250cf
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [Hashtable]$Left,

        [Parameter(Mandatory = $true)]
        [Hashtable]$Right		
    )
    
    function New-Result($Key, $LValue, $Side, $RValue) {
        [PSCustomObject]@{
            "Key"    = $Key
            "LValue" = $LValue
            "RValue" = $RValue
            "Side"   = $Side
        }
    }

    $Results = $Left.Keys | ForEach-Object {
        if ($Left.ContainsKey($_) -and -not $Right.ContainsKey($_)) {
            New-Result $_ $Left[$_] "<=" $Null
        } else {
            $LValue = $Left[$_]
            $RValue = $Right[$_]
            if ($LValue -ne $RValue) {
                New-Result $_ $LValue "!=" $RValue
            }
            else {
                New-Result $_ $LValue "==" $RValue
            }
        }
    }
    $Results += $Right.Keys | ForEach-Object {
        if (-not $Left.ContainsKey($_) -and $Right.ContainsKey($_)) {
            New-Result $_ $Null "=>" $Right[$_]
        } 
    }
    $Results 
}

function Get-IniContent {
    <#
    .SYNOPSIS
        Parses an INI file content into ordered dictionaries
    .NOTES
        https://github.com/hsmalley/Powershell/blob/master/Parse-IniFile.ps1
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]$IniFile
    )

    try {
        $ini = [ordered]@{}
        switch -regex -file $IniFile {
            #Section
            "^\[(.+)\]$" {
                $section = $matches[1].Trim()
                $ini[$section] = [ordered]@{}
                continue
            }
            # Comment  
            "^(;.*)$" {  
                if (-not $section) {  
                    $section = "No-Section"  
                    $ini[$section] = [ordered]@{}  
                }  
                $value = $matches[1]  
                $CommentCount = $CommentCount + 1  
                $name = "Comment" + $CommentCount  
                $ini[$section][$name] = $value  
                continue
            }
            # Key/Value Pair
            "(.+?)\s*=\s*(.*)"  
            {  
                if (-not $section) {  
                    $section = "No-Section"  
                    $ini[$section] = @{}  
                }  
                $name,$value = $matches[1..2]  
                $ini[$section][$name] = $value  
                continue
            }
            # Key Only
            "^\s*([^#].+?)\s*" {
                $ini[$section][$_] = $null
                continue
            }
        }
        $ini
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Set-IniContent {
    [CmdletBinding()]
    param (
        [Parameter()]
        [System.Collections.Specialized.OrderedDictionary]$CurrentConfig,

        [Parameter()]
        [System.Collections.Specialized.OrderedDictionary]$DesiredConfig
    )

    $Config = [ordered]@{
        "SetupConfig" = [ordered]@{}
        "Compliance"  = "Compliant"
    }

    try {
        $CompareResult = Compare-Hashtable -Left $CurrentConfig.SetupConfig -Right $DesiredConfig.SetupConfig

        foreach ($Result in $CompareResult) {
            switch ($Result.Side) {
                "==" {
                    # Exists in both, so keep
                    $Config["SetupConfig"][$Result.Key] = $Result.LValue
                }
                "<=" {
                    # Exists in current, but not desired, so don't change
                    $Config["SetupConfig"][$Result.Key] = $Result.LValue
                }
                "=>" {
                    # Exists in desired, but not current, so insert
                    $Config["Compliance"] = "NonCompliant"
                    $Config["SetupConfig"][$Result.Key] = $Result.RValue
                }
                "!=" {
                    # Exists in both, but current value doesn't match desired, so correct
                    $Config["Compliance"] = "NonCompliant"
                    $Config["SetupConfig"][$Result.Key] = $Result.RValue
                }
            }
        }

        $Config
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Export-IniFile {
    [CmdletBinding()]
    param (
        [Parameter()]
        [System.Collections.Specialized.OrderedDictionary]$Content,

        [Parameter()]
        [String]$File
    )

    try {
        $NewContent = $Content.GetEnumerator() | ForEach-Object -Begin {
            "[SetupConfig]"
        } -Process {
            "{0}={1}" -f $_.Key, $_.Value
        }

        #Write $Content to the SetupConfig.ini file
        $NewContent | Set-Content -Path $File -Force -ErrorAction "Stop"
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

try {
    if (Test-Path -Path $SourceIniFile) {
        $CurrentIniFileContent = Get-IniContent -IniFile $SourceIniFile
    }

    if (-not $AlwaysReWrite.IsPresent -And ($CurrentIniFileContent -is [System.Collections.Specialized.OrderedDictionary])) {
        $NewIniDictionary = Set-IniContent -CurrentConfig $CurrentIniFileContent -DesiredConfig $Config
        $ComplianceValue = $NewIniDictionary["Compliance"]
    }
    else {
        #If the ini file doesn't exist or has no content, then just set $NewIniDictionary to the $Config parameter
        $NewIniDictionary = $Config
        $NewIniDictionary["Compliance"] = "NonCompliant"
    }

    if ($Remediate) {
        #If no destination is specified, the source path is used
        if (-not $DestIniFile) { 
            $DestIniFile = $SourceIniFile
        }

        Export-IniFile -Content $NewIniDictionary["SetupConfig"] -File $DestIniFile

        $ComplianceValue = $NewIniDictionary["Compliance"]
    }
    else {
        $ComplianceValue = $NewIniDictionary["Compliance"]
    }

    $ComplianceValue
}
catch {
    Write-Error -ErrorRecord $_
}
