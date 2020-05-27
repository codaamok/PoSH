# TODO Pass GC at parameter, check it is the win32_operatingsystem wql query
# TODO maybe optionally create the install.ps1
# TODO use an existing Application if it exists

$Languages = @(
    "fr-FR",
    "de-DE"
)

$WindowsVersion = @{
    "Version" = "1909"
    "Build" = "18363" 
}

$GlobalCondition = Get-CMGlobalCondition -Name "Operating System build"

foreach($Language in $Languages) {
    # Sub expression to force key name to be string
    $AppObj = New-CMApplication -Name ("Windows 10 x64 Language Pack - {0}" -f $Language)

    $InstallSplat = @{
        ApplicationName          = $AppObj.LocalizedDisplayName
        DeploymentTypeName       = "{0} ({1}) - Install language items (SYSTEM)" -f $WindowsVersion["Version"], $WindowsVersion["Build"]
        ContentLocation          = "\\sccm.acc.local\Applications$\Language\{0}" -f $Language
        InstallCommand           = 'powershell.exe -executionpolicy bypass -noprofile -file ".\Install.ps1"'
        AddDetectionClause       = New-CMDetectionClauseRegistryKey -Hive "LocalMachine" -KeyName ("SYSTEM\CurrentControlSet\Control\MUI\UILanguages\{0}" -f $Language) -Existence
        UserInteractionMode      = "Hidden"
        RebootBehavior           = "NoAction"
        AddRequirement           = $GlobalCondition | New-CMRequirementRuleCommonValue -Value1 $WindowsVersion["Build"] -RuleOperator IsEquals
        LogonRequirementType     = "OnlyWhenUserLoggedOn"
        InstallationBehaviorType = "InstallForSystem"
    }

    $InstallDTObj = Add-CMScriptDeploymentType @InstallSplat | ForEach-Object { Get-CMDeploymentType -DeploymentTypeId $_.CI_ID -ApplicationName $AppObj.LocalizedDisplayName }

    $SetLanguageListSplat = @{
        ApplicationName          = $AppObj.LocalizedDisplayName
        DeploymentTypeName       = "{0} ({1}) - Configure language list (USER)" -f $WindowsVersion["Version"], $WindowsVersion["Build"]
        InstallCommand           = 'powershell.exe -executionpolicy bypass -noprofile -command "& {{ $List = Get-WinUserLanguageList; $List.Add(`"{0}`"); Set-WinUserLanguageList $List -Force; exit 1641 }}"' -f $Language
        ScriptLanguage           = "PowerShell"
        ScriptText               = "if ((Get-WinUserLanguageList).LanguageTag -contains `"{0}`") {{ Write-Output `"Detected`" }}" -f $Language
        UserInteractionMode      = "Hidden"
        RebootBehavior           = "ForceReboot"
        AddRequirement           = $GlobalCondition | New-CMRequirementRuleCommonValue -Value1 $WindowsVersion["Build"] -RuleOperator IsEquals
        InstallationBehaviorType = "InstallForUser"
    }

    $ConfigureDTObj = Add-CMScriptDeploymentType @SetLanguageListSplat | ForEach-Object { Get-CMDeploymentType -DeploymentTypeId $_.CI_ID -ApplicationName $AppObj.LocalizedDisplayName }

    $null = $ConfigureDTObj | Set-CMDeploymentType -Priority "Increase"
    $null = $ConfigureDTObj | New-CMDeploymentTypeDependencyGroup -GroupName "Install language items" | Add-CMDeploymentTypeDependency -DeploymentTypeDependency $InstallDTObj -IsAutoInstall:$true

}
