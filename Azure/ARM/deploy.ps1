Import-Module "PsArmResources"

$Date = (Get-Date)
$KeyVaultName = "keyvault-homelab"
$Location = "uksouth"
$NumberOfVMs = 1

if (-not (Get-AzKeyVault -VaultName $KeyVaultName)) {
    New-AzKeyVault -Name $KeyVaultName -ResourceGroupName "homelab" -Location "West Europe"
}

foreach ($item in 1..$numOfServers) {
    #region Name resources
    # https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging#example-names
    $ServerName       = "nginx{0:D3}" -f $item
    $VMName           = "vm{0}" -f $ServerName
    $RGName           = "rg-{0}-lab-{1:D3}" -f $ServerName, $item
    $VNetName         = "vnet-lab-{0}-{1:D3}" -f $Location, $item
    $SubnetName       = "snet-lab-{0}-{1:D3}" -f $Location, $item
    $VNICName         = "nic-{0:D2}-{1}" -f $item, $ServerName
    $NSGName          = "nsg-{0}-{1:D3}" -f $ServerName, $item
    $PIPName          = "pip-{0}-lab-{1}-{2:D3}" -f $ServerName, $Location, $item
    $VMStorageAccName = "stvmpm{0}{1}{2:D3}" -f $ServerName, $Location, $item
    #endregion

    $KeyFile = "{0}\.ssh\{1}" -f [Environment]::GetFolderPath("MyDocuments"), $VMName
    $Comment = "localhost={0} target={1} created={2}" -f $env:ComputerName, $VMName, $Date

    if (Test-Path $KeyFile) {
        Remove-Item $KeyFile* -Force
    }

    ssh-keygen.exe -t "rsa" -b 4096 -N (Get-Secure "azure-arm-testing").GetNetworkCredential().Password -C $Comment -f $KeyFile -q

    if (Test-Path $KeyFile) {
        Copy-Item $KeyFile $home\.ssh -Force
    }

    $KeyFileContent = (Get-Content $KeyFile) -join "`n"
    $SecureString = ConvertTo-SecureString -String $KeyFileContent -AsPlainText -Force
    Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name ("{0}-PrivateKey" -f $VMName) -SecretValue $SecureString

    #region Create ARM template
    $template = New-PsArmTemplate

    $vnet = New-PsArmVnet -Name 
    #endregion
}
