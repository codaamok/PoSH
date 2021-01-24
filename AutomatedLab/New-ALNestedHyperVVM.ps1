$LabDefintiion = @{
    Name = "HYP01"
    DefaultVirtualizationEngine = "HyperV"
    ReferenceDiskSizeInGB = 100
    ErrorAction = "Stop"
}

New-LabDefinition @LabDefintiion

Add-LabVirtualNetworkDefinition -Name $LabDefintiion["Name"] -HyperVProperties @{ SwitchType = 'External'; AdapterName = 'vEthernet (vEthernet (Inte)' }

$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch $LabDefintiion["Name"] -UseDhcp

$LabMachineDefinition = @{
    Name = "HYP01"
    OperatingSystem = "Windows Server 2019 Standard (Desktop Experience)"
    Memory = 20GB
    Role = "HyperV"
    NetworkAdapter = $netAdapter
    ErrorAction = "Stop"
}

Add-LabMachineDefinition @LabMachineDefinition

Install-Lab

Copy-LabFileItem -Path "C:\git\PoSH\Azure\AutomatedLab\New-AzVM-AutomatedLab-CustomScriptExt.ps1" -ComputerName $LabDefintiion["Name"] -DestinationFolderPath "C:\"

Invoke-LabCommand -ActivityName "Executing post-install script" -ComputerName $LabDefintiion["Name"] -FilePath "C:\New-AzVM-AutomatedLab-CustomScriptExt.ps1"
