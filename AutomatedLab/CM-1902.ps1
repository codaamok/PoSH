
$LabName = "CMLab01"
New-LabDefinition -Name CMLab01 -DefaultVirtualizationEngine HyperV -VmPath "C:\Labs\$LabName"

$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:OperatingSystem' = 'Windows Server 2019 Standard (Desktop Experience)'
    'Add-LabMachineDefinition:DomainName' = 'acc.lab'
}

Add-LabIsoImageDefinition -Name SQLServer2017 -Path $labSources\ISOs\en_sql_server_2017_standard_x64_dvd_11294407.iso

Add-LabMachineDefinition -Name DC01 -Roles RootDC -MinMemory 1GB -MaxMemory 4GB -Memory 2GB

$sccmRole = Get-LabPostInstallationActivity -CustomRole CM-1902 -Properties @{
    SccmSiteCode = "CM1"
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

Add-LabDiskDefinition -Name "CM01-SQL-01" -DiskSizeInGb 30GB -Label "SQL-01" -DriveLetter "E"
Add-LabDiskDefinition -Name "CM01-DATA-01" -DiskSizeInGb 50GB -Label "DATA-01" -DriveLetter "F"

Add-LabMachineDefinition -Name CM01 -Roles $sqlRole -MinMemory 2GB -MaxMemory 8GB -Memory 4GB -PostInstallationActivity $sccmRole -Processors 4

Install-Lab

Show-LabDeploymentSummary -Detailed
