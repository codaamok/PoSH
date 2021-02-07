[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [String]$Name,

    [Parameter()]
    [Double]$Memory = 12GB,

    [Parameter()]
    [ValidateSet(
        "Windows Server 2016 Standard Evaluation (Desktop Experience)",
        "Windows Server 2016 Datacenter Evaluation (Desktop Experience)",
        "Windows Server 2019 Standard Evaluation (Desktop Experience)",
        "Windows Server 2019 Datacenter Evaluation (Desktop Experience)",
        "Windows Server 2016 Standard (Desktop Experience)",
        "Windows Server 2016 Datacenter (Desktop Experience)",
        "Windows Server 2019 Standard (Desktop Experience)",
        "Windows Server 2019 Datacenter (Desktop Experience)"
    )]
    [String]$OSVersion = 'Windows Server 2019 Standard (Desktop Experience)',

    [Parameter()]
    [String]$ExternalVMSwitchName = "External",

    [Parameter()]
    [String]$PostInstallScript = "C:\git\PoSH\Azure\AutomatedLab\New-AzVM-AutomatedLab-CustomScriptExt.ps1"
)

if (-not (Test-Path $PostInstallScript)) {
    $Message = "Post install script does not exist, would you like to continue?"
    $Options = "&Yes", "&No"
    $Response = $Host.UI.PromptForChoice($null, $Message, $Options, 0)

    if ($Response -eq 1) {
        return
    }
    else {
        $IgnorePostInstallScript = $true
    }
}
else {
    $PostInstallScriptFileName = Split-Path $PostInstallScript -Leaf
}

$LabDefintiion = @{
    Name = $Name
    DefaultVirtualizationEngine = "HyperV"
    ReferenceDiskSizeInGB = 100
    ErrorAction = "Stop"
}

New-LabDefinition @LabDefintiion

Add-LabVirtualNetworkDefinition -Name $ExternalVMSwitchName -HyperVProperties @{ SwitchType = 'External'; AdapterName = $ExternalVMSwitchName }

$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch 'External' -UseDhcp

$LabMachineDefinition = @{
    Name = $Name
    OperatingSystem = $OSVersion
    Memory = $Memory
    Role = "HyperV"
    NetworkAdapter = $netAdapter
    ErrorAction = "Stop"
}

Add-LabMachineDefinition @LabMachineDefinition

Install-Lab

if (-not $IgnorePostInstallScript) {
    Copy-LabFileItem -Path "C:\git\PoSH\Azure\AutomatedLab\New-AzVM-AutomatedLab-CustomScriptExt.ps1" -ComputerName $Name -DestinationFolderPath "C:\"

    Invoke-LabCommand -ActivityName "Executing post-install script" -ComputerName $Name -ArgumentList $PostInstallScriptFileName -ScriptBlock { 
        param([String]$FileName)
        & "C:\$FileName" 
    }
}
