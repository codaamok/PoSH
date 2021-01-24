#Requires -Module "Az"
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [String]$Name,

    [Parameter()]
    [String]$Size = "Standard_D8ds_v4"
)

# Configuration variables
$Location = "uksouth"
$IPInfoApiKey = (Get-Secure "IPInfo").GetNetworkCredential().Password
$IPInfo = Invoke-RestMethod -Uri "https://ipinfo.io/json" -Headers @{"Authorisation" = "Bearer $IPInfoApiKey"} -ErrorAction "Stop"
Write-Verbose ("Public IP is '{0}'" -f $IPinfo.IP)


#region Create Resource Group
$Params = @{
    Name = "{0}-rg" -f $Name
    Location = $Location
    ErrorAction = "Stop"
}
$ResourceGroup = New-AzResourceGroup @Params
#endregion

#region Create Network Security Group rules
$Params = @{
    Name = "rdp-rule"
    Description = "Allow RDP"
    Access = "Allow"
    Protocol = "Tcp"
    Direction = "Inbound"
    Priority = 100
    SourceAddressPrefix = $IPInfo.IP
    SourcePortRange = "*"
    DestinationAddressPrefix = "*"
    DestinationPortRange = 3389
    ErrorAction = "Stop"
}
$rule1 = New-AzNetworkSecurityRuleConfig @Params
#endregion

#region
$Params = @{
    Name = "{0}-nsg" -f $Name
    Location = $Location
    ResourceGroupName = $ResourceGroup.ResourceGroupName
    SecurityRules = $rule1
    ErrorAction = "Stop"
}
$NetworkSecurityGroup = New-AzNetworkSecurityGroup @Params
#endregion

$Params = @{
    Name = $Name
    Location = $Location
    SecurityGroupName = $NetworkSecurityGroup.Name
    ResourceGroupName = $ResourceGroup.ResourceGroupName
    Image = "Win2019Datacenter"
    Size = $Size
    ErrorAction = "Stop"
}
New-AzVm @Params

$Params = @{
    Name = "SetupAutomatedLab"
    Location = $Location
    ResourceGroupName = $ResourceGroup.ResourceGroupName
    VMName = $Name
    FileUri = "https://raw.githubusercontent.com/codaamok/PoSH/master/Azure/AutomatedLab/New-AzVM-AutomatedLab-CustomScriptExt.ps1"
    Run = "New-AzVM-AutomatedLab-CustomScriptExt.ps1"
    ErrorAction = "Stop"
}
Set-AzVMCustomScriptExtension @Params
