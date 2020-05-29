function New-LPRepository {
    <#
    .SYNOPSIS
        Copy out only the Language Packs you want from the Language Pack ISO
    .DESCRIPTION
        Copy out only the Language Packs you want from the Language Pack ISO
    .PARAMETER Langauge
        Language(s) you want to extract, e.g. en-us, fr-fr, de-de etc
    .PARAMETER SourcePath
        Path to where the Language Packs are in the Language Pack ISO
    .PARAMETER TargetPath
        Destination path to copy Language Packs to. A folder per language will be created under this folder.
    .EXAMPLE
        PS C:\> New-LPRepository -Language "fr-FR", "de-DE" -SourcePath "I:\x64\langpacks" -TargetPath "F:\OSD\Source\1909-Languages"

        Copies Language Packs named "fr-FR" and "de-DE" from path "I:\LocalExperiencePack" to "F:\OSD\Source\1909-Languages\LP\fr-FR" and "F:\OSD\Source\1909-Languages\LP\de-DE"
    .NOTES
        Author: Adam Cook (@codaamok)
    #>
    param (
        [Parameter()]
        [ValidateSet("ar-sa", "bg-bg", "cs-cz", "da-dk", "de-de", "el-gr", "en-gb", "en-us", "es-es", "es-mx", "et-ee", "fi-fi", "fr-ca", "fr-fr", "he-il", "hr-hr", "hu-hu", "it-it", "ja-jp", "ko-kr", "lt-lt", "lv-lv", "nb-no", "nl-nl", "pl-pl", "pt-br", "pt-pt", "ro-ro", "ru-ru", "sk-sk", "sl-si", "sr-la", "sv-se", "th-th", "tr-tr", "uk-ua", "zh-cn", "zh-tw")]
        [String[]]$Language,
        [Parameter(Mandatory)]
        [String]$SourcePath,
        [Parameter(Mandatory)]
        [String]$TargetPath
    )

    Get-ChildItem -Path $SourcePath -Filter "*.cab" | ForEach-Object {
        if ($_.Name -match "Microsoft-Windows-Client-Language-Pack_x64_([a-z]{2}-[a-z]{2})\.cab") {
            if ($Language -contains $Matches[1]) {
                $Path = "{0}\LP\{1}" -f $TargetPath, $Matches[1]
                if (-not (Test-Path $Path)) {
                    New-Item -Path $Path -ItemType Directory -Force
                }
    
                Copy-Item -Path $_.FullName -Destination $Path -Force
            }
        }
    }
}

function New-LXPRepository {
    <#
    .SYNOPSIS
        Copy out only the folders of the languages you want from the Language Experience Pack ISO
    .DESCRIPTION
        Copy out only the folders of the languages you want from the Language Experience Pack ISO
    .PARAMETER Langauge
        Language(s) you want to extract, e.g. en-us, fr-fr, de-de etc
    .PARAMETER SourcePath
        Path to where the folders of Language Experience Packs are in the Language Experience Pack ISO
    .PARAMETER TargetPath
        Destination path to copy the folders to
    .EXAMPLE
        PS C:\> New-LXPRepository -Language "fr-FR", "de-DE" -SourcePath "I:\LocalExperiencePack" -TargetPath "F:\OSD\Source\1909-Languages"

        Copies folders named "fr-FR" and "de-DE" in Language Experience Pack ISO path "I:\LocalExperiencePack" to "F:\OSD\Source\1909-Languages\LXP\"
    .NOTES
        Author: Adam Cook (@codaamok)
    #>
    param (
        [Parameter()]
        [ValidateSet("af-za", "am-et", "ar-sa", "as-in", "az-latn-az", "be-by", "bg-bg", "bn-bd", "bn-in", "bs-latn-ba", "ca-es", "ca-es-valencia", "chr-cher-us", "cs-cz", "cy-gb", "da-dk", "de-de", "el-gr", "en-gb", "en-us", "es-es", "es-mx", "et-ee", "eu-es", "fa-ir", "fi-fi", "fil-ph", "fr-ca", "fr-fr", "ga-ie", "gd-gb", "gl-es", "gu-in", "ha-latn-ng", "he-il", "hi-in", "hr-hr", "hu-hu", "hy-am", "id-id", "ig-ng", "is-is", "it-it", "ja-jp", "ka-ge", "kk-kz", "km-kh", "kn-in", "ko-kr", "kok-in", "ku-arab-iq", "ky-kg", "lb-lu", "lo-la", "lt-lt", "lv-lv", "mi-nz", "mk-mk", "ml-in", "mn-mn", "mr-in", "ms-my", "mt-mt", "nb-no", "ne-np", "nl-nl", "nn-no", "nso-za", "or-in", "pa-arab-pk", "pa-in", "pl-pl", "prs-af", "pt-br", "pt-pt", "quc-latn-gt", "quz-pe", "ro-ro", "ru-ru", "rw-rw", "sd-arab-pk", "si-lk", "sk-sk", "sl-si", "sq-al", "sr-cyrl-ba", "sr-cyrl-rs", "sr-latn-rs", "sv-se", "sw-ke", "ta-in", "te-in", "tg-cyrl-tj", "th-th", "ti-et", "tk-tm", "tn-za", "tr-tr", "tt-ru", "ug-cn", "uk-ua", "ur-pk", "uz-latn-uz", "vi-vn", "wo-sn", "xh-za", "yo-ng", "zh-cn", "zh-tw", "zu-za")]
        [String[]]$Language,
        [Parameter(Mandatory)]
        [String]$SourcePath,
        [Parameter(Mandatory)]
        [String]$TargetPath
    )
    
    Get-ChildItem -Path $SourcePath | ForEach-Object { 
        if ($Language -contains $_.Name) {
            $Path = "{0}\LXP\{1}" -f $TargetPath, $_.Name
            if (-not (Test-Path $Path)) {
                New-Item -Path $Path -ItemType Directory -Force
            }

            Copy-Item -Path ("{0}\*" -f $_.FullName) -Destination $Path -Force
        }
    }
}

function New-FoDLanguageFeaturesRepository {
    <#
    .SYNOPSIS
        Copy out only the languages you want of the Features on Demand LanguageFeatures Basic, Handwriting, OCR, Speech and TextToSpeech from Features on Demand ISO
    .DESCRIPTION
        Copy out only the languages you want of the Features on Demand LanguageFeatures Basic, Handwriting, OCR, Speech and TextToSpeech from Features on Demand ISO
    .PARAMETER Langauge
        Language(s) you want to extract, e.g. en-us, fr-fr, de-de etc
    .PARAMETER SourcePath
        Path to where the Features on Demand are in the Features on Demand ISO
    .PARAMETER TargetPath
        Destination path to copy Features on Demand to. A folder per language will be created under this folder.
    .EXAMPLE
        PS C:\> New-FoDLanguageFeaturesRepository -Language "fr-FR", "de-DE" -SourcePath "I:\" -TargetPath "F:\OSD\Source\1909-Languages"

        Copies Features on Demand of LanguageFeatures Basic, Handwriting, OCR, Speech and TextToSpeech with language elements "fr-FR", "de-DE" in path "I:\" to "F:\OSD\Source\1909-Languages\FoD\fr-FR" and "F:\OSD\Source\1909-Languages\FoD\de-DE"
    .NOTES
        Author: Adam Cook (@codaamok)
    #>
    param (
        [Parameter()]
        [ValidateSet("ar-SA", "bg-BG", "cs-CZ", "da-DK", "de-DE", "el-GR", "en-GB", "en-US", "es-ES", "es-MX", "et-EE", "fi-FI", "fr-CA", "fr-FR", "he-IL", "hr-HR", "hu-HU", "it-IT", "ja-JP", "ko-KR", "lt-LT", "lv-LV", "nb-NO", "nl-NL", "pl-PL", "pt-BR", "pt-PT", "ro-RO", "ru-RU", "sk-SK", "sl-SI", "sr-Latn-RS", "sv-SE", "th-TH", "tr-TR", "uk-UA", "zh-CN", "zh-TW")]
        [String[]]$Language,
        [Parameter(Mandatory)]
        [String]$SourcePath,
        [Parameter(Mandatory)]
        [String]$TargetPath
    )

    Get-ChildItem -Path $SourcePath | ForEach-Object {
        if ($_.Name -match "LanguageFeatures-\w+-([\w]{2}-[\w]{4}-[\w]{2}|[\w]{2}-[\w]{2})") {
            if ($Language -contains $Matches[1]) {
                $Path = "{0}\FoD\{1}" -f $TargetPath, $Matches[1]
                if (-not (Test-Path $Path)) {
                    New-Item -Path $Path -ItemType Directory -Force
                }
    
                Copy-Item -Path $_.FullName -Destination $Path -Force
            }
        }
    }
}

function New-CMLanguagePackApplication {
    <#
    .SYNOPSIS
        Create a Configuration Manager Application with two deployment types to install LP, LXP and FoD (as system) and make the language available to the user in the Settings language list.
    .DESCRIPTION
        Create a Configuration Manager Application with two deployment types to install LP, LXP and FoD (as system) and make the language available to the user in the Settings language list.
    .EXAMPLE
        PS C:\> New-CMLanguagePackApplication

        Explanation of what the example does
    .NOTES
        Author: Adam Cook (@codaamok)
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$SiteServer,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$SiteCode,

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
    begin {
        $OriginalLocation = (Get-Location).Path

        Import-Module ("{0}\..\ConfigurationManager.psd1" -f $ENV:SMS_ADMIN_UI_PATH) -ErrorAction "Stop"

        if ($null -eq (Get-PSDrive -Name $SiteCode -PSProvider "CMSite" -ErrorAction "SilentlyContinue")) {
            $null = New-PSDrive -Name $SiteCode -PSProvider "CMSite" -Root $SiteServer -ErrorAction "Stop"
        }

        Set-Location ("{0}:\" -f $SiteCode) -ErrorAction "Stop"

        $GlobalCondition_OSBuild = Get-CMGlobalCondition -Name $GlobalConditionName
        $GlobalCondition_OS = Get-CMGlobalCondition -Name 'Operating System' | Where-Object { $_.ModelName -eq 'GLOBAL/OperatingSystem' }

        if ($null -eq $GlobalCondition_OSBuild) {
            if ($CreateGlobalConditionIfMissing.IsPresent) {
                Write-Warning -Message "Global Condition missing, creating"
                $GlobalCondition_OSBuild = New-CMGlobalConditionWqlQuery -Name "Operating System build" -Namespace "root\cimv2" -Class "Win32_OperatingSystem" -Property "BuildNumber" -DataType "String"
            }
            else {
                Write-Error -Message ("Cannot find Global Condition '{0}', consider using -CreateGlobalConditionIfMissing" -f $GlobalConditionName) -Category "ObjectNotFound" -ErrorAction "Stop"
            }
        }
        else {
            if (-not ($GlobalCondition_OSBuild.SDMPackageXML | Select-String -SimpleMatch "<WqlQueryDiscoverySource><Namespace>root\cimv2</Namespace><Class>Win32_OperatingSystem</Class><Property>BuildNumber</Property></WqlQueryDiscoverySource>")) {
                Write-Error -Message ("Global Condition '{0}' found, but does not use WQL query with class Win32_OperatingSystem property BuildNumber" -f $GlobalCondition_OSBuild.LocalizedDisplayName) -Category "ObjectNotFound" -ErrorAction "Stop"
            }
        }
    }
    process {
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
                # Detection for LP, although LXP adds keys here too
                New-CMDetectionClauseRegistryKey -Hive "LocalMachine" -KeyName ("SYSTEM\CurrentControlSet\Control\MUI\UILanguages\{0}" -f $Language) -Existence
                # Detection for LXP
                New-CMDetectionClauseRegistryKey -Hive "LocalMachine" -KeyName ("SOFTWARE\Microsoft\LanguageOverlay\OverlayPackages\{0}" -f $Language) -Existence
            } -Process {
                # Detection for FoDs
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
                AddRequirement           = @(
                    $GlobalCondition_OSBuild | New-CMRequirementRuleCommonValue -Value1 $WindowsVersion["Build"] -RuleOperator IsEquals
                    $GlobalCondition_OS | New-CMRequirementRuleOperatingSystemValue -PlatformString "Windows/All_x64_Windows_10_and_higher_Clients" -RuleOperator "OneOf"
                )
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
                AddRequirement           = @(
                    $GlobalCondition_OSBuild | New-CMRequirementRuleCommonValue -Value1 $WindowsVersion["Build"] -RuleOperator IsEquals
                    $GlobalCondition_OS | New-CMRequirementRuleOperatingSystemValue -PlatformString "Windows/All_x64_Windows_10_and_higher_Clients" -RuleOperator "OneOf"
                )
                InstallationBehaviorType = "InstallForUser"
            }
    
            $SetLanguageListObj = Add-CMScriptDeploymentType @SetLanguageListSplat | ForEach-Object { Get-CMDeploymentType -DeploymentTypeId $_.CI_ID -ApplicationName $AppObj.LocalizedDisplayName }
    
            $null = $SetLanguageListObj | Set-CMDeploymentType -Priority "Increase"
            $null = $SetLanguageListObj | New-CMDeploymentTypeDependencyGroup -GroupName "Install language items" | Add-CMDeploymentTypeDependency -DeploymentTypeDependency $InstallDTObj -IsAutoInstall:$true
    
        }
    }
    end {
        Set-Location $OriginalLocation
    }
}
