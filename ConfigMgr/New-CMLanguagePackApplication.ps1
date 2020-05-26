$Languages = @(
    "fr-FR",
    "de-DE"
)

$WindowsVersion = @{
    "1909" = "18363"
}

$GlobalCondition = Get-CMGlobalCondition -Name "Operating System build"

foreach($Language in $Languages) {
    # Sub expression to force key name to be string
    $Obj = New-CMApplication -Name "Windows 10 x64 $($WindowsVersion.Keys) Language Pack"

    $InstallSplat = @{
        ApplicationName          = $Obj.LocalizedDisplayName
        DeploymentTypeName       = "Install"
        ContentLocation          = "\\sccm.acc.local\Applications$\Language\{0}" -f $Language
        InstallCommand           = 'powershell.exe -executionpolicy bypass -noprofile -file ".\Install.ps1"'
        AddDetectionClause       = New-CMDetectionClauseRegistryKey -Hive "LocalMachine" -KeyName ("SYSTEM\CurrentControlSet\Control\MUI\UILanguages\{0}" -f $Language) -Existence
        UserInteractionMode      = "Hidden"
        RebootBehavior           = "NoAction"
        AddRequirement           = $GlobalCondition | New-CMRequirementRuleCommonValue -Value1 $WindowsVersion["1909"] -RuleOperator IsEquals
        LogonRequirementType     = "OnlyWhenUserLoggedOn"
        InstallationBehaviorType = "InstallForSystem"
    }

    # Example contents of Install.ps1
    # "& { Get-ChildItem -Filter `"*.cab`" | ForEach-Object { dism.exe /Online /Add-Package /PackagePath:$_ /Quiet /NoRestart }
    # Add-AppxProvisionedPackage -Online -PackagePath (Get-ChildItem -Filter `"*.appx`") -LicensePath `".\License.xml`"
    # $p = (Get-AppxPackage | Where-Object { $_.Name -like `"*LanguageExperiencePack{0}*`" }).InstallLocation
    # Add-AppxPackage -Register -Path $p\AppxManifest.xml -DisableDevelopmentMode }"' -f $Language

    $InstallDT = Add-CMScriptDeploymentType @InstallSplat

    $SetLanguageListSplat = @{
        ApplicationName          = $Obj.LocalizedDisplayName
        DeploymentTypeName       = "Configure language list"
        InstallCommand           = 'powershell.exe -executionpolicy bypass -noprofile -command "& { $List = Get-WinUserLanguageList; $List.Add(`"{0}`"); Set-WinUserLanguageList $List -Force; exit 1641 }"' -f $Language
        ScriptLanguage           = "PowerShell"
        ScriptText               = "if ((Get-WinUserLanguageList).LanguageTag -contains `"{0}`") { Write-Output `"Detected`""
        UserInteractionMode      = "Hidden"
        RebootBehavior           = "ForceReboot"
        AddRequirement           = $InstallSplat["AddRequirement"]
        LogonRequirementType     = "OnlyWhenUserLoggedOn"
        InstallationBehaviorType = "InstallForUser"
    }

    $null = Add-CMScriptDeploymentType @SetLanguageListSplat
}
