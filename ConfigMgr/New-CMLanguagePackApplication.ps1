# TODO: Add LXP detection
# TODO: import CM module and set ps drive
function New-CMLanguagePackApplication {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({
            if (-not ([System.Uri]$_).IsUnc) {
                throw "-SourcePath must be a UNC path"
            }
            elseif (-not ([System.IO.Directory]::Exists($_))) {
                throw "Invalid path or access denied"
            }
            elseif (-not ($_ | Test-Path -PathType Container)) {
                throw "-SourcePath must be a directory, not a file"
            }
            else {
                return $true
            }
        })]
        [String]$SourcePath,

        [Parameter()]
        [String[]]$Languages = @(
            "fr-FR",
            "de-DE"
        ),

        [Parameter()]
        [ValidateScript({
            if (-not ($_.ContainsKey("Version"))) {
                throw "Please supply a Version key in the hashtable, e.g. Version = 1909"
            }
            elseif (-not ($_.ContainsKey("Build"))) {
                throw "Please supply a Build key in the hashtable, e.g. Build = 18363"
            }
            else {
                $true
            }
        })]
        [Hashtable]$WindowsVersion = @{
            "Version" = "1909"
            "Build" = "18363" 
        },

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$GlobalConditionName = "Operating System build",

        [Parameter()]
        [Switch]$CreateAppIfMissing,

        [ParameteR()]
        [Switch]$CreateGlobalConditionIfMissing
    )

    $GlobalCondition = Get-CMGlobalCondition -Name $GlobalConditionName

    if ($null -eq $GlobalCondition) {
        if ($CreateGlobalConditionIfMissing.IsPresent) {
            Write-Warning -Message "Global Condition missing, creating"
            $GlobalCondition = New-CMGlobalConditionWqlQuery -Name "Operating System build" -Namespace "root\cimv2" -Class "Win32_OperatingSystem" -Property "BuildNumber" -DataType "String"
        }
        else {
            Write-Error -Message ("Cannot find Global Condition '{0}', consider using -CreateGlobalConditionIfMissing" -f $GlobalConditionName) -Category "ObjectNotFound" -ErrorAction "Stop"
        }
    }
    else {
        if (-not ($GlobalCondition.SDMPackageXML | Select-String -SimpleMatch "<WqlQueryDiscoverySource><Namespace>root\cimv2</Namespace><Class>Win32_OperatingSystem</Class><Property>BuildNumber</Property></WqlQueryDiscoverySource>")) {
            Write-Error -Message ("Global Condition '{0}' found, but does not use WQL query with class Win32_OperatingSystem property BuildNumber" -f $GlobalCondition.LocalizedDisplayName) -Category "ObjectNotFound" -ErrorAction "Stop"
        }
    }

    $WindowsVersion = @{
        "Version" = "1909"
        "Build" = "18363" 
    }

    :outer foreach ($Language in $Languages) {
        $ContentLocation = "{0}\{1}" -f $SourcePath, $Language
        $AppName = "Windows 10 x64 Language Pack - {0}" -f $Language
        $InstallDTName = "{0} ({1}) - Install language items (SYSTEM)" -f $WindowsVersion["Version"], $WindowsVersion["Build"]
        $SetLanguageListDTName = "{0} ({1}) - Configure language list (USER)" -f $WindowsVersion["Version"], $WindowsVersion["Build"]

        if (-not (Test-Path $ContentLocation)) {
            Write-Error -Message ("Path '{0}' does not exist, skipping application '{1}'" -f $ContentLocation, $AppName) -Category "ObjectNotFound"
            continue
        }

        $AppObj = Get-CMApplication -Name $AppName

        if ($null -eq $AppObj) {
            if ($CreateAppIfMissing.IsPresent) {
                Write-Warning -Message ("Application '{0}' missing, creating" -f $AppName)
                $AppObj = New-CMApplication -Name $AppName
            }
            else {
                Write-Error -Message ("Cannot find application '{0}', consider using -CreateAppIfMissing" -f $AppName) -Category "ObjectNotFound"
                continue
            }
        }

        # Check if deployment types already exist, skip language / application if it does
        foreach ($DeploymentType in @($InstallDTName, $SetLanguageListDTName)) {
            $Obj = Get-CMDeploymentType -DeploymentTypeName $DeploymentType -ApplicationName $AppObj.LocalizedDisplayName
            if ($Obj) {
                Write-Warning -Message ("Deployment type '{0}' already exists for application '{1}', skipping application" -f $dt, $AppName)
                continue outer
            }
        }

        # Build install string for the SYSTEM deployment type
        $InstallCommands = @(
            '$cabs = Get-ChildItem -Path ".\LP\",".\FoD" -Filter "*.cab"'
            'foreach ($cab in $cabs) { dism.exe /Online /Add-Package /PackagePath:$cab /Quiet /NoRestart'
            '$appx = Get-ChildItem -Filter "*.appx" | Select-Object -First 1'
            'Add-AppxProvisionedPackage -Online -PackagePath $appx -LicensePath ".\License.xml"'
            '$p = (Get-AppxPackage | Where-Object {{ $_.Name -like "*LanguageExperiencePack{0}*" }}).InstallLocation' -f $Language
            'Add-AppxPackage -Register -Path $p\AppxManifest.xml -DisableDevelopmentMode'
        )

        $InstallCommandStr = 'powershell.exe -executionpolicy bypass -noprofile -Command {{ {0} }}' -f ($InstallCommands -join "; ")

        # Get FoDs so we can start building detection method
        $FoDs = Get-ChildItem -Path $SourcePath\FoD\$Language -Filter "*.cab"

        # Build detection method
        $DetectionMethod =  $FoDs | ForEach-Object -Begin {
            # TODO This appears for both LPs and LXPs, which isn't ideal, just haven't looked to see if registry changes when install LXP. Probably does.
            New-CMDetectionClauseRegistryKey -Hive "LocalMachine" -KeyName ("SYSTEM\CurrentControlSet\Control\MUI\UILanguages\{0}" -f $Language) -Existence
        } -Process {
            New-CMDetectionClauseRegistryKey -Hive "LocalMachine" -KeyName ("SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackageIndex\{0}0.0.0.0" -f $_.BaseName) -Existence
        }

        $InstallSplat = @{
            ApplicationName          = $AppObj.LocalizedDisplayName
            DeploymentTypeName       = $InstallDTName
            ContentLocation          = $ContentLocation
            InstallCommand           = $InstallCommandStr
            AddDetectionClause       = $DetectionMethod
            UserInteractionMode      = "Hidden"
            RebootBehavior           = "NoAction"
            AddRequirement           = $GlobalCondition | New-CMRequirementRuleCommonValue -Value1 $WindowsVersion["Build"] -RuleOperator IsEquals
            LogonRequirementType     = "OnlyWhenUserLoggedOn"
            InstallationBehaviorType = "InstallForSystem"
        }

        $InstallDTObj = Add-CMScriptDeploymentType @InstallSplat | ForEach-Object { Get-CMDeploymentType -DeploymentTypeId $_.CI_ID -ApplicationName $AppObj.LocalizedDisplayName }

        $SetLanguageListSplat = @{
            ApplicationName          = $AppObj.LocalizedDisplayName
            DeploymentTypeName       = $SetLanguageListDTName
            InstallCommand           = 'powershell.exe -executionpolicy bypass -noprofile -command "& {{ $List = Get-WinUserLanguageList; $List.Add(`"{0}`"); Set-WinUserLanguageList $List -Force; exit 1641 }}"' -f $Language
            ScriptLanguage           = "PowerShell"
            ScriptText               = "if ((Get-WinUserLanguageList).LanguageTag -contains `"{0}`") {{ Write-Output `"Detected`" }}" -f $Language
            UserInteractionMode      = "Hidden"
            RebootBehavior           = "ForceReboot"
            AddRequirement           = $GlobalCondition | New-CMRequirementRuleCommonValue -Value1 $WindowsVersion["Build"] -RuleOperator IsEquals
            InstallationBehaviorType = "InstallForUser"
        }

        $SetLanguageListObj = Add-CMScriptDeploymentType @SetLanguageListSplat | ForEach-Object { Get-CMDeploymentType -DeploymentTypeId $_.CI_ID -ApplicationName $AppObj.LocalizedDisplayName }

        $null = $SetLanguageListObj | Set-CMDeploymentType -Priority "Increase"
        $null = $SetLanguageListObj | New-CMDeploymentTypeDependencyGroup -GroupName "Install language items" | Add-CMDeploymentTypeDependency -DeploymentTypeDependency $InstallDTObj -IsAutoInstall:$true

    }
}