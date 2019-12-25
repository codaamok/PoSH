
$LabName = "CMLab01"
New-LabDefinition -Name "CMLab01" -DefaultVirtualizationEngine HyperV -VmPath "D:\AutomatedLab\$LabName" -ReferenceDiskSizeInGB 100

$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:OperatingSystem' = 'Windows Server 2019 Standard (Desktop Experience)'
    'Add-LabMachineDefinition:DomainName' = 'acc.lab'
    'Add-LabMachineDefinition:Processors' = 2
    'Add-LabMachineDefinition:Network' = $labName
    'Add-LabMachineDefinition:AutoLogonDomainName' = 'acc.lab'
    'Add-LabMachineDefinition:AutoLogonUserName' = 'Administrator'
    'Add-LabMachineDefinition:AutoLogonPassword' = 'Somepass1'
}

Add-LabVirtualNetworkDefinition -Name $labName -AddressSpace 192.168.11.0/24 -VirtualizationEngine HyperV
Add-LabVirtualNetworkDefinition -Name "Internet" -VirtualizationEngine HyperV -HyperVProperties @{ SwitchType = 'External'; AdapterName = 'Internet' }

Add-LabIsoImageDefinition -Name SQLServer2017 -Path $labSources\ISOs\en_sql_server_2017_standard_x64_dvd_11294407.iso

$netAdapter = @()
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch $LabName -Ipv4Address 192.168.11.0/24
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch "Internet" -UseDhcp
Add-LabMachineDefinition -Name DC01 -Roles RootDC,Routing -NetworkAdapter $netAdapter -MinMemory 1GB -MaxMemory 4GB -Memory 2GB

$sccmRole = Get-LabPostInstallationActivity -CustomRole "CM-1902" -Properties @{
    SccmSiteCode = "CM1"
    SccmSiteName = "AutomatedLab"
    SccmBinariesDirectory = "$labSources\SoftwarePackages\CM1902"
    SccmPreReqsDirectory = "$labSources\SoftwarePackages\CMPreReqs"
    SccmProductId = "Eval" # Can be "Eval" or a product key
    AdkDownloadPath = "$labSources\SoftwarePackages\ADK"
    WinPEDownloadPath = "$labSources\SoftwarePackages\WinPE"
    SqlServerName = 'CM01'
}

$sqlRole = Get-LabMachineRoleDefinition -Role SQLServer2017 -Properties @{ 
    Collation = 'SQL_Latin1_General_CP1_CI_AS'
}

Add-LabDiskDefinition -Name "CM01-DATA-01" -DiskSizeInGb 50 -Label "DATA-01" -DriveLetter "G"
Add-LabDiskDefinition -Name "CM01-SQL-01" -DiskSizeInGb 30 -Label "SQL-01" -DriveLetter "F"

Add-LabMachineDefinition -Name "CM01" -Roles $sqlRole -MinMemory 2GB -MaxMemory 8GB -Memory 4GB -PostInstallationActivity $sccmRole -Processors 4 -DiskName "CM01-DATA-01","CM01-SQL-01"

Install-Lab
# Use the below instead to only run the CM custom role
# Install-Lab -PostInstallations

Show-LabDeploymentSummary -Detailed
