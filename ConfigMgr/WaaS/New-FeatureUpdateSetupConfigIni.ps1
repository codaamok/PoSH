<#
.SYNOPSIS
    Add or remove key/value pairs to SetupConfig.ini for Windows 10 feature updates.
    Use in a ConfigMgr CI.
.NOTES
    A lightly modified version of https://github.com/AdamGrossTX/Windows10FeatureUpdates/blob/master/Admin/ComplianceScripts/FeatureUpdateCIScript.ps1
#>
param (
    [Parameter()]
    [Bool]$Remediate = $false,

    [Parameter()]
    [System.Collections.Specialized.OrderedDictionary]$AddSettings = [ordered]@{
        "SetupConfig" = [ordered]@{
            "BitLocker"             = "AlwaysSuspend";
            "Compat"                = "IgnoreWarning";
            "Priority"              = "Normal"
            "DynamicUpdate"         = "Enable"
            "ShowOOBE"              = "None"
            "Telemetry"             = "Enable"
            "DiagnosticPrompt"      = "Enable"
            #"PKey"                 = "NPPR9-FWDCX-D2C8J-H872K-2YT43"
            "PostOOBE"              = "C:\~AdamCookFeatureUpdateTemp\Scripts\SetupComplete.cmd"
            #"PostRollBack"         = "C:\~AdamCookFeatureUpdateTemp\Scripts\ErrorHandler.cmd"
            #"PostRollBackContext"  = "System"
            "CopyLogs"              = "\\sccm.acc.local\FeatureUpdateFailedLogs\$($ENV:COMPUTERNAME)"
            #"InstallDrivers"       = "C:\Windows\Temp\PathToDrivers" # Consider adding this if we need it in the future
            #"MigrateDrivers"       = "C:\Windows\Temp\PathToDrivers" # Consider adding this if we need it in the future
        }
    },

    [Parameter()]
    [System.Collections.Specialized.OrderedDictionary]$RemoveSettings = [ordered]@{
        "SetupConfig" = [ordered]@{
            "PostOOBE"              = "C:\~AdamCookFeatureUpdateTemp\Scripts\SetupComplete.cmd"
            "PostRollBack"          = "C:\~AdamCookFeatureUpdateTemp\Scripts\ErrorHandler.cmd"
            "PostRollBackContext"   = "System"
            "InstallDrivers"        = "C:\Windows\Temp\PathToDrivers"
        }
    },

    [Parameter()]
    [String]$SourceIniFile = "$($env:SystemDrive)\Users\Default\AppData\Local\Microsoft\Windows\WSUS\SetupConfig.ini",

    [Parameter()]
    [String]$DestIniFile,

    [Parameter()]
    [switch]$AlwaysReWrite
)

function Get-IniContent {
    <#
    .SYNOPSIS
        Parses an INI file content into ordered dictionaries
    .NOTES
        #https://github.com/hsmalley/Powershell/blob/master/Parse-IniFile.ps1
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
                if (!($section))  
                {  
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
                if (!($section))  
                {  
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
        $ReturnValue = $ini
    }
    catch {
        $ReturnValue = $Error[0]
    }
    $ReturnValue
    
  }
function Set-IniContent {
    [CmdletBinding()]
    param (
        [Parameter()]
        [System.Collections.Specialized.OrderedDictionary]$OrigContent,

        [Parameter()]
        [System.Collections.Specialized.OrderedDictionary]$NewContent,

        [Parameter()]
        [System.Collections.Specialized.OrderedDictionary]$RemoveContent
    )
    
    $ReturnValue = $null
    # Create clones of hashtables so originals are not modified
    $Primary = $OrigContent
    $Secondary = $NewContent
    $Compliance = $null
    $NonCompliantCount = 0

    try  {
        # If specified, we will remove these keys from the source if they exist
        foreach ($Key in $RemoveContent.Keys)
        {
            if ($RemoveContent[$key] -is [System.Collections.Specialized.OrderedDictionary]) {
                foreach ($ChildKey in $RemoveContent[$key].keys) {
                    if ($Primary[$key][$ChildKey]) {
                        $Primary[$key].Remove($ChildKey)
                        $NonCompliantCount++
                    }
                }
            }
            else {
                if ($Primary[$key]) {
                    $Primary.Remove($Key)
                    $NonCompliantCount++
                }
            }
        }

        foreach ($Key in $Primary.keys) {
            if ($Primary[$key] -is [System.Collections.Specialized.OrderedDictionary]) {

                #I'm so done writing this code. This basically checks to see if you have an exact number of records in the source and new
                #If you don't do this, then compliance will be incorrect.
                if ($Primary[$key].Count -lt $Secondary[$key].Count) {
                    $NonCompliantCount++
                }

                if ($Secondary[$key]) {

                    #Find all duplicate keys in the source
                    $Duplicates = $Primary[$key].keys | where-object {$Secondary[$key].Contains($_)}
                    if ($Duplicates) {
                        foreach ($item in $Duplicates) {

                            #Test for compliance. If the values don't match, then this item should be remediated
                            if ($Primary[$key][$item] -ne $Secondary[$key][$item]) {
                                $NonCompliantCount ++
                            }

                            $Primary[$key].Remove($item)
                        }
                    }

                    #Adds remaining items from the source to the output since these weren't duplicates.
                    #These don't impact compliance since we don't care if they exist
                    foreach ($ChildKey in $Primary[$key].keys) {

                        if ($Secondary[$key]) {
                            $Secondary[$key][$childKey] = $Primary[$key][$ChildKey]
                        }
                        else {
                            $Secondary[$key] = $Primary[$key]
                        }

                    }
                }
                else {
                    $Secondary[$key] = $Primary[$key]
                }
            }
            else {
                $duplicates = $Primary.keys | where-object {$Secondary.Contains($_)}

                if ($duplicates) {
                    foreach ($item in $duplicates) {
                        #Test for compliance. If the values don't match, then this item should be remediated

                        if ($Primary[$item] -ne $Secondary[$item])
                        {
                            $NonCompliantCount ++
                        }

                        $Primary.Remove($item)
                    }
                }
            }
        }

        #If No Mismatched values are found, $Compliance is set to Compliance
        $Compliance = switch ($NonCompliantCount) {
            0 {
                "Compliant"
                break
            }
            default {
                "NonCompliant"
                break
            }
        }

        $Secondary["Compliance"] = $Compliance

        $ReturnValue = $Secondary
    }

    catch {
        $ReturnValue = $error[0]
    }
        $ReturnValue
}

function Export-IniFile {
    [CmdletBinding()]
    param (
        [Parameter()]
        [System.Collections.Specialized.OrderedDictionary]$Content,

        [Parameter()]
        [String]$NewFile
    )
    
    $ReturnValue = $null
    try {
        #This array will be the final ini output
        $NewIniContent = @()

        $KeyCount = 0
        #Convert the dictionary into ini file format
        foreach ($sectionHash in $Content.Keys)
        {
            $KeyCount++
            #Create section headers
            $NewIniContent += "[{0}]" -f $sectionHash

            #Create all section content. Items with a Name and Value in the dictionary will be formatted as Name=Value. 
            #Any items with no value will be formatted as Name only.
            foreach ($key in $Content[$sectionHash].keys) {
                $NewIniContent += 
                if ($Key -like "Comment*"){
                    #Comment
                    $Content[$sectionHash][$key]
                }    
                elseif ($NewIniDictionary[$sectionHash][$key]) {
                    #Name=Value format
                    ($key, $Content[$sectionHash][$key]) -join "="
                }
                else {
                    #Name only format
                    $key
                }
            }
            #Add a blank line after each section if there is more than one, but don't add one after the last section
            if ($KeyCount -lt $Content.Keys.Count) {
                $NewIniContent += ""
            }
        }
        #Write $Content to the SetupConfig.ini file

        $null = New-Item -Path $NewFile -ItemType File -Force
        $null = $NewIniContent -join "`r`n" | Out-File -FilePath $NewFile -Force -NoNewline
        $ReturnValue = $NewIniContent
    }
    catch {
        $ReturnValue = $Error[0]
    }
    $ReturnValue
}

try {
    if (Test-Path -Path $SourceIniFile) {
        $CurrentIniFileContent = Get-IniContent -IniFile $SourceIniFile
    }

    if ((!($AlwaysReWrite.IsPresent)) -and ($CurrentIniFileContent -is [System.Collections.Specialized.OrderedDictionary])) {
        $SetIniContentSplat = @{
            OrigContent = $CurrentIniFileContent
            NewContent  = $AddSettings
        }

        if ($PSBoundParameters.ContainsKey("RemoveSettings")) {
            $SetIniContentSplat["RemoveContent"] = $RemoveSettings
        }

        $NewIniDictionary = Set-IniContent @SetIniContentSplat
    }
    else {
        #If the ini file doesn't exist or has no content, then just set $NewIniDictionary to the $Settings parameter
        $NewIniDictionary = $AddSettings
        $NewIniDictionary["Compliance"] = "NonCompliant"
    }

    if ($Remediate) {
        #If no destination is specified, the source path is used
        if (!($DestIniFile)) { $DestIniFile = $SourceIniFile }
        $ComplianceValue =  $NewIniDictionary["Compliance"]
        #Remove the compliance key so it doesn't get added to the final INI file.
        $NewIniDictionary.Remove("Compliance")
        $null = Export-IniFile -Content $NewIniDictionary -NewFile $DestIniFile
    }
    else {
        $ComplianceValue =  $NewIniDictionary["Compliance"]
    }
    $ReturnValue = $ComplianceValue
}
catch {
    $ReturnValue = $Error[0]
}

$ReturnValue
