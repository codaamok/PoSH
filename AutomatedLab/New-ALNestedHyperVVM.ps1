$LabDefintiion = @{
    Name = "HYP01"
    DefaultVirtualizationEngine = "HyperV"
    ReferenceDiskSizeInGB = 100
    ErrorAction = "Stop"
}

New-LabDefinition @LabDefintiion

Add-LabVirtualNetworkDefinition -Name 'Default Switch' -HyperVProperties @{ SwitchType = 'External'; AdapterName = 'Internet' }

$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch 'Default Switch' -UseDhcp

$LabMachineDefinition = @{
    Name = "HYP01"
    OperatingSystem = "Windows Server 2019 Standard (Desktop Experience)"
    Memory = 16GB
    #Role = "HyperV"
    NetworkAdapter = $netAdapter
    ErrorAction = "Stop"
}

Add-LabMachineDefinition @LabMachineDefinition

Install-Lab
