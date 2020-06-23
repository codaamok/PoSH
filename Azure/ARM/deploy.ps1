# This script was mostly made for my own benefit while studying for AZ-103
# For the odd wander on the Internet stumbling across this, use it as a reference if you like
# I wanted to mess around with ARM templates, load balancers, Az PowerShell module, vnets (and routing), storage and the key vault services
# I did originally start out creating a template with no parameter file using the PsArmResources module, so maybe revisit that later and add Linux support for it

$VerbosePreference = "Continue"

$AzContext = Get-AzContext

if ($AzContext.Subscription.Name -like "Visual Studio Enterprise - MPN*") {
    throw "Please change your current subscription"
}

$Date = (Get-Date)
$Location = "uksouth"
$NumberOfVMs = 3
$MyIP = Invoke-RestMethod -Uri "https://ipinfo.io/json" -Headers @{"Authorisation" = "Bearer {0}" -f (Get-Secure "IPInfo").GetNetworkCredential().Password} | Select-Object -ExpandProperty ip
$ArmTemplate = "C:\git\PoSH\Azure\ARM\template.json"

foreach ($item in 1..$NumberOfVMs) {
    #region Name resources
    # https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging#example-names
    $KeyVaultName     = "kv-lab-{0}-001" -f $Location
    $ServerName       = "nginx{0:D3}" -f $item
    $VMName           = "vm{0}" -f $ServerName
    $RGName           = "rg-{0}-lab-001" -f $ServerName
    $VNetName         = "vnet-lab-{0}-{1:D3}" -f $Location, $item
    $SubnetName       = "snet-lab-{0}-{1:D3}" -f $Location, $item
    $VNICName         = "nic-{0:D2}-{1}" -f $item, $ServerName
    $NSGName          = "nsg-{0}-{1:D3}" -f $ServerName, $item
    $PIPName          = "pip-{0}-lab-{1}-{2:D3}" -f $ServerName, $Location, $item
    # $VMStorageAccName = "stvmpm{0}{1}{2:D3}" -f $ServerName, $Location, $item
    #endregion

    #region
    # Define properties
    $AddressPrefix = "192.168.10{0}.0/24" -f $item
    #endregion


    Write-Verbose "Creating resource group"
    $RG = New-AzResourceGroup -Name $RGName -Location $Location

    if (-not (Get-AzKeyVault -VaultName $KeyVaultName)) {
        Write-Verbose "Creating key vault"
        $KeyVault = New-AzKeyVault -Name $KeyVaultName -ResourceGroupName $RG.ResourceGroupName -Location $Location -DisableSoftDelete
    }

    $KeyFile = "{0}\.ssh\{1}" -f [Environment]::GetFolderPath("MyDocuments"), $VMName
    $Comment = "localhost={0} target={1} created={2}" -f $env:ComputerName, $VMName, $Date

    if (Test-Path $KeyFile) {
        Remove-Item $KeyFile* -Force
    }

    Write-Verbose "Generating ssh key pair"
    ssh-keygen.exe -t "rsa" -b 4096 -N (Get-Secure "azure-arm-testing").GetNetworkCredential().Password -C $Comment -f $KeyFile -q

    $PublicKey = Get-Content -Path ("{0}.pub" -f $KeyFile)

    if (Test-Path $KeyFile) {
        Copy-Item $KeyFile $home\.ssh -Force
    }

    $KeyFileContent = (Get-Content $KeyFile) -join "`n"
    $SecureString = ConvertTo-SecureString -String $KeyFileContent -AsPlainText -Force
    Write-Verbose "Stashing private key to key vault"
    $Secret = Set-AzKeyVaultSecret -VaultName $KeyVault.VaultName -Name ("{0}-PrivateKey" -f $VMName) -SecretValue $SecureString

    $ArmTemplateParameters = "{0}\arm-template-parameters-{1}.json" -f $env:temp, $VMName

    Write-Verbose "Creating json template and saving to file"
    [PSCustomObject]@{
        '$schema' = "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#"
        "contentVersion" = "1.0.0.0"
        "parameters" = [PSCustomObject]@{
            location = [PSCustomObject]@{
                "value" = $Location
            }
            networkInterfaceName = [PSCustomObject]@{
                "value" = $VNICName
            }
            networkSecurityGroupName = [PSCustomObject]@{
                "value" = $NSGName
            }
            networkSecurityGroupRules = [PSCustomObject]@{
                "value" = @(
                    [PSCustomObject]@{
                        name = "SSH"
                        properties = [PSCustomObject]@{
                            priority = 300
                            protocol = "TCP"
                            access = "Allow"
                            direction = "Inbound"
                            sourceAddressPrefix = $MyIP
                            sourcePortRange = "*"
                            destinationAddressPrefix = "*"
                            destinationPortRange = "22"
                        }
                    }
                )
            }
            subnetName = [PSCustomObject]@{
                "value" = $SubnetName
            }
            subnets = [PSCustomObject]@{
                "value" = @(
                    [PSCustomObject]@{
                        name = $SubnetName
                        properties = [PSCustomObject]@{
                            addressPrefix = $AddressPrefix
                        }
                    }
                )
            }
            virtualNetworkName = [PSCustomObject]@{
                "value" = $VNetName
            }
            addressPrefixes = [PSCustomObject]@{
                "value" = @($AddressPrefix)
            }
            publicIpAddressName = [PSCustomObject]@{
                "value" = $PIPName
            }
            virtualMachineName = [PSCustomObject]@{
                "value" = $VMName
            }
            virtualMachineComputerName = [PSCustomObject]@{
                "value" = $ServerName
            }
            virtualMachineRG = [PSCustomObject]@{
                "value" = $RGName
            }
            virtualMachineSize = [PSCustomObject]@{
                "value" = "Standard_B1ms"
            }
            adminPublicKey = [PSCustomObject]@{
                "value" = $PublicKey.ToString()
            }
            autoShutdownStatus = [PSCustomObject]@{
                "value" = "Enabled"
            }
            autoShutdownTime = [PSCustomObject]@{
                "value" = "19:00"
            }
            autoShutdownTimeZone = [PSCustomObject]@{
                "value" = "GMT Standard Time"
            }
            autoShutdownNotificationStatus = [PSCustomObject]@{
                "value" = "Enabled"
            }
            autoShutdownNotificationLocale = [PSCustomObject]@{
                "value" = "en"
            }
            autoShutdownNotificationEmail = [PSCustomObject]@{
                "value" = "me@cookadam.co.uk"
            }
        }
    } | ConvertTo-Json -Depth 5 | Set-Content -Path $ArmTemplateParameters -Force

    $DeploymentName = "{0}_{1}" -f $VMName, (Get-Date $Date -Format 'yyyy-MM-dd_HH-mm-ss')

    Write-Verbose "Creating deployment using template"
    # Didn't realise the template parameter object parameter accepted hashtable and not json
    New-AzResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $RG.ResourceGroupName -TemplateFile $ArmTemplate -TemplateParameterFile $ArmTemplateParameters

    Remove-Item $ArmTemplateParameters -Force
}
