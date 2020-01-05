<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
#>
#Requires -Version 5.1 -Modules "AutomatedLab", "Hyper-V"
[Cmdletbinding()]
Param (
    [Parameter()]
    [String]$LabName = "CMLab01",

    [Parameter()]
    [ValidateScript({
        if (!([System.IO.Directory]::Exists($_))) { throw "Invalid path or access denied" } elseif (!($_ | Test-Path -PathType Container)) { throw "Value must be a directory, not a file" }; return $true
    })]
    [String]$VMPath = "C:\AutomatedLab",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [String]$Domain = "winadmins.lab",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [String]$AdminUser = "Administrator",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [String]$AdminPass = "Somepass1",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [AutomatedLab.IPNetwork]$AddressSpace,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [String]$ExternalVMSwitchName = "Internet",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-zA-Z0-9]{3}$')]
    [String]$SiteCode = "P01",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [String]$SiteName = $LabName,

    [Parameter()]
    [ValidateSet("1902","1906","1910","Latest")]
    [String]$CMVersion = "Latest",

    [Parameter()]
    [ValidateSet("2016","2019")]
    [String]$OSVersion = "2019",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [String]$DCHostname = "DC01",

    [Parameter()]
    [ValidateScript({
        if ($_ -lt 0) { throw "Invalid number of CPUs" }; return $true
    })]
    [Int]$DCCPU = 2,

    [Parameter()]
    [ValidateScript({
        if ($_ -lt [Double]128MB -or $_ -gt [Double]128GB) { throw "Memory for VM must be more than 128MB and less than 128GB" }; $true
        if ($_ -lt [Double]1GB) { throw "Please specify more than 1GB of memory" }
    })]
    [Double]$DCMemory = 2GB,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [String]$CMHostname = "CM01",

    [Parameter()]
    [ValidateScript({
        if ($_ -lt 0) { throw "Invalid number of CPUs" }; return $true
    })]
    [Int]$CMCPU = 4,

    [Parameter()]
    [ValidateScript({
        if ($_ -lt [Double]128MB -or $_ -gt [Double]128GB) { throw "Memory for VM must be more than 128MB and less than 128GB" }
        if ($_ -lt [Double]1GB) { throw "Please specify more than 1GB of memory" }
        return $true
    })]
    [Double]$CMMemory = 8GB,

    [Parameter()]
    [ValidateSet("CMTrace", "OneTrace")]
    [String]$LogViewer = "OneTrace",

    [Parameter()]
    [Switch]$SkipDomainCheck,

    [Parameter()]
    [Switch]$SkipLabNameCheck,

    [Parameter()]
    [Switch]$SkipHostnameCheck,

    [Parameter()]
    [Switch]$DoNotDownloadWMIEv2,

    [Parameter()]
    [Switch]$PostInstallations,

    [Parameter()]
    [Switch]$ExcludePostInstallations,

    [Parameter()]
    [Switch]$NoInternetAccess,

    [Parameter()]
    [Switch]$AutoLogon
)

#region Preflight checks
switch ($true) {
    (-not $SkipLabNameCheck.IsPresent) {
        if ((Get-Lab -List -ErrorAction SilentlyContinue) -contains $_) { 
            throw ("Lab already exists with the name '{0}'" -f $LabName)
        }
    }
    (-not $SkipDomainCheck.IsPresent) {
        if (Test-Connection $_ -Count 1 -ErrorAction "SilentlyContinue") { 
            throw ("Domain '{0}' already exists, choose a different domainz" -f $Domain)
        }
    }
    (-not $SkipHostnameCheck.IsPresent) {
        if (Test-Connection $DCHostname -Count 1 -ErrorAction "SilentlyContinue") { throw ("Host '{0}' already exists, choose a different name" -f $DCHostname)}
        if (Test-Connection $CMHostname -Count 1 -ErrorAction "SilentlyContinue") { throw ("Host '{0}' already exists, choose a different name" -f $CMHostname)}
    }
    # I know I can use ParameterSets, but I want to be able to execute this script without any parameters too, so this is cleaner.
    ($PostInstallations.IsPresent -And $ExcludePostInstallations.IsPresent) {
        throw "Can not use -PostInstallations and -ExcludePostInstallations together"
    }
    ($NoInternetAccess.IsPresent -And $PSBoundParameters.ContainsKey("ExternalVMSwitchName")) {
        throw "Can not use -NoInternetAccess and -ExternalVMSwitchName together"
    }
    ((Get-VMSwitch).Name -notcontains $ExternalVMSwitchName) { 
        throw "Hyper-V virtual switch '$ExternalVMSwitchName' does not exist"
    }
    ((Get-VMSwitch -Name $ExternalVMSwitchName).SwitchType -ne "External") { 
        throw "Hyper-V virtual switch '$ExternalVMSwitchName' is not of External type" 
    }
}
#endregion

#region Initialise
$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:OperatingSystem' = "Windows Server $OSVersion Standard (Desktop Experience)"
    'Add-LabMachineDefinition:DomainName'      = $Domain
    'Add-LabMachineDefinition:Network'         = $LabName
    'Add-LabMachineDefinition:ToolsPath'       = "$labSources\Tools"
    'Add-LabMachineDefinition:MinMemory'       = 1GB
    'Add-LabMachineDefinition:Memory'          = 1GB
}

if ($AutoLogon.IsPresent) {
    $PSDefaultParameterValues['Add-LabMachineDefinition:AutoLogonDomainName'] = $Domain
    $PSDefaultParameterValues['Add-LabMachineDefinition:AutoLogonUserName']   = $AdminUser
    $PSDefaultParameterValues['Add-LabMachineDefinition:AutoLogonPassword']   = $AdminPass
}

# Changing the below doesn't actually do anything at the moment. One day I will test vmware.
$Engine = "HyperV"
#endregion

#region New-LabDefinition
$NewLabDefinitionSplat = @{
    Name                        = $LabName
    DefaultVirtualizationEngine = $Engine
    ReferenceDiskSizeInGB       = 100
    ErrorAction                 = "Stop"
}
if ($PSBoundParameters.ContainsKey("VMPath")) { 
    $Path = Join-Path -Path $VMPath -ChildPath $LabName
    $NewLabDefinitionSplat.Add("VMPath",$Path)
}
New-LabDefinition @NewLabDefinitionSplat
#endregion

#region Set credentials
Add-LabDomainDefinition -Name $domain -AdminUser $AdminUser -AdminPassword $AdminPass
Set-LabInstallationCredential -Username $AdminUser -Password $AdminPass
#endregion

#region Download WMIExplorer v2
if (-not $DoNotDownloadWMIEv2.IsPresent) {
    $WMIv2Zip = Join-Path -Path $labSources -ChildPath "Tools\WmiExplorer_2.0.0.2.zip"
    $WMIv2Exe = Join-Path -Path $labSources -ChildPath "Tools\WmiExplorer.exe"
    if (-not (Test-Path $WMIv2Zip) -And (-not (Test-Path $WMIv2Exe))) {
        Write-ScreenInfo -Message "Downloading WMIExplorer v2" -TaskStart
        try {
            Get-LabInternetFile -Uri "https://github.com/vinaypamnani/wmie2/releases/download/v2.0.0.2/WmiExplorer_2.0.0.2.zip" -Path $WMIv2Zip -ErrorAction Stop -ErrorVariable GetLabInternetFileErr
        }
        catch {
            Write-ScreenInfo -Message ("Could not download WmiExplorer ({0})" -f $GetLabInternetFileErr.Exception.Message) -Type "Warning"
        }
        if (Test-Path -Path $WMIv2Zip) {
            Expand-Archive -Path $WMIv2Zip -DestinationPath $labSources\Tools -ErrorAction Stop
            try {
                Remove-Item -Path $WMIv2Zip -Force -ErrorAction Stop -ErrorVariable RemoveItemErr
            }
            catch {
                Write-ScreenInfo -Message ("Failed to delete '{0}' ({1})" -f $WMIZip, $RemoveItemErr.Exception.Message) -Type "Warning"
            }
        } 
        Write-ScreenInfo -Message "Activity done" -TaskEnd
    }
    else {
        Write-ScreenInfo -Message "WmiExplorer.exe already exists, skipping the download. Delete the file '{0}' if you want to download again."
    }
}
#endregion

#region Forcing $LogViewer = CMTrace if $CMVersion -eq 1902
if ($CMVersion -eq 1902 -and $LogViewer -eq "OneTrace") {
    Write-ScreenInfo -Message "Setting LogViewer to 'CMTrace' as OneTrace is only availale in 1906 or newer" -Type "Warning"
    $LogViewer = "CMTrace"
}
#endregion

#region Build AutomatedLab
$netAdapter = @()
$AddLabVirtualNetworkDefinitionSplat = @{
    Name                   = $LabName
    VirtualizationEngine   = $Engine
}
$NewLabNetworkAdapterDefinitionSplat = @{
    VirtualSwitch = $LabName
}
if ($PSBoundParameters.ContainsKey("AddressSpace")) {
    $AddLabVirtualNetworkDefinitionSplat.Add("AddressSpace", $AddressSpace)
    $NewLabNetworkAdapterDefinitionSplat.Add("Ipv4Address", $AddressSpace)
}
Add-LabVirtualNetworkDefinition @AddLabVirtualNetworkDefinitionSplat
$netAdapter += New-LabNetworkAdapterDefinition @NewLabNetworkAdapterDefinitionSplat

if (-not $NoInternetAccess.IsPresent) {
    Add-LabVirtualNetworkDefinition -Name "Internet" -VirtualizationEngine $Engine -HyperVProperties @{ SwitchType = 'External'; AdapterName = 'Internet' }
    $netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch "Internet" -UseDhcp
}

Add-LabMachineDefinition -Name $DCHostname -Processors $DCCPU -Roles RootDC,Routing -NetworkAdapter $netAdapter -MaxMemory $DCMemory

Add-LabIsoImageDefinition -Name SQLServer2017 -Path "$labSources\ISOs\en_sql_server_2017_standard_x64_dvd_11294407.iso"

$sqlRole = Get-LabMachineRoleDefinition -Role SQLServer2017 -Properties @{ 
    Collation = 'SQL_Latin1_General_CP1_CI_AS'
}

Add-LabDiskDefinition -Name "CM01-DATA-01" -DiskSizeInGb 50 -Label "DATA01" -DriveLetter "G"
Add-LabDiskDefinition -Name "CM01-SQL-01" -DiskSizeInGb 30 -Label "SQL01" -DriveLetter "F"

if ($ExcludePostInstallations.IsPresent) {
    Add-LabMachineDefinition -Name $CMHostname -Processors $CMCPU -Roles $sqlRole -MaxMemory $CMMemory -DiskName "CM01-DATA-01","CM01-SQL-01"
}
else {
    $sccmRole = Get-LabPostInstallationActivity -CustomRole "CM-1902" -Properties @{
        SccmSiteCode            = $SiteCode
        SccmSiteName            = $SiteName
        SccmBinariesDirectory   = "$labSources\SoftwarePackages\CM1902"
        SccmPreReqsDirectory    = "$labSources\SoftwarePackages\CMPreReqs"
        SccmProductId           = "Eval" # Can be "Eval" or a product key
        Version                 = $CMVersion
        AdkDownloadPath         = "$labSources\SoftwarePackages\ADK"
        WinPEDownloadPath       = "$labSources\SoftwarePackages\WinPE"
        LogViewer               = $LogViewer
        SqlServerName           = $CMHostname
    }
    Add-LabMachineDefinition -Name $CMHostname -Processors $CMCPU -Roles $sqlRole -MinMemory 2GB -MaxMemory 8GB -Memory 4GB -DiskName "CM01-DATA-01","CM01-SQL-01" -PostInstallationActivity $sccmRole
}
#endregion

#region Install
if ($PostInstallations.IsPresent) {
    Install-Lab -PostInstallations -NoValidation
}
else {
    Install-Lab
}
Show-LabDeploymentSummary -Detailed
#endregion