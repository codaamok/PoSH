#Requires -Module powershell-yaml
<#
.SYNOPSIS
    This script was mostly made for my own consumption while studying for AZ-103 - don't expect it to make sense. Use it as a reference if you like
.DESCRIPTION
    This script was mostly made for my own consumption while studying for AZ-103 - don't expect it to make sense. Use it as a reference if you like
    I wanted to mess around with ARM templates, load balancers, Az PowerShell module, vnets (and routing), storage and the key vault services.
    I did originally start out creating a template with no parameter file using the PsArmResources module, so maybe revisit that later and add Linux support for it.
.NOTES
    Author: Adam Cook
#>
[CmdletBinding()]
param (
    [Parameter()]    
    [DateTime]$Date = (Get-Date),

    [Parameter()]
    [String]$Location = "uksouth",

    [Parameter()]
    [Int]$Lowest = 1,

    [Parameter()]
    [Int]$Highest = 4,

    [Parameter()]
    [String]$ArmTemplate = ".\template.json",

    [Parameter()]
    [String]$KeyVaultName = "kv-lab-{0}-001" -f $Location,

    [Parameter()]
    [PSCredential]$SASToken = (Get-Secure -Name "AzureARMnginxSASToken"),

    [Parameter()]
    [String]$ContainerName = "nginx-loadbalancer-test",

    [Parameter()]
    [String]$StorageAccountName = "storageaccounthomel8cb5",

    [Parameter()]
    [String]$VNetName = "vnet-lab-{0}-001" -f $Location,

    [Parameter()]
    [String]$VNetAddressPrefix = "192.168.0.0/16",

    [Parameter()]
    [String[]]$NSGAllowedIPs = (Invoke-RestMethod -Uri "https://ipinfo.io/json" -Headers @{"Authorisation" = "Bearer {0}" -f (Get-Secure "IPInfo").GetNetworkCredential().Password} | Select-Object -ExpandProperty ip),

    [Parameter()]
    [String]$SubscriptionId = (Get-Secure "AzureARMnginxSASToken").UserName,

    [Parameter()]
    [String]$AzureTenantId = "cf7d21a4-6f74-4b08-8b68-89b756ecd52e"
)

$VerbosePreference = "Continue"

$AzContext = Get-AzContext

if ($AzContext.Subscription.Name -notlike "*$SubscriptionId*") {
    throw "Please change your current subscription"
}

$RGName = "rg-keyvault-lab-001"

Write-Verbose "Creating resource group $RGName"
$RG = New-AzResourceGroup -Name $RGName -Location $Location

if (-not (Get-AzKeyVault -VaultName $KeyVaultName)) {
    Write-Verbose "Creating key vault"
    $KeyVault = New-AzKeyVault -Name $KeyVaultName -ResourceGroupName $RG.ResourceGroupName -Location $Location -DisableSoftDelete
}

Write-Verbose "Stashing codaamok.net certificates to key vault"
$FullChain = (Get-Content -Path "C:\Users\acc\OneDrive - Adam Cook\Documents\projects\azure-learning\codaamok.net-fullchain.pem" -ErrorAction "Stop") -join "`n"
$null = Set-AzKeyVaultSecret -VaultName $KeyVault.VaultName -Name "codaamok-net-fullchain-pem" -SecretValue (ConvertTo-SecureString -String $FullChain -AsPlainText -Force)
$PrivateKey = (Get-Content -Path "C:\Users\acc\OneDrive - Adam Cook\Documents\projects\azure-learning\codaamok.net-privkey.pem" -ErrorAction "Stop") -join "`n"
$null = Set-AzKeyVaultSecret -VaultName $KeyVault.VaultName -Name "codaamok-net-privkey-pem" -SecretValue (ConvertTo-SecureString -String $PrivateKey -AsPlainText -Force)

$AzureApp = Get-Secure "AzureARMnginxKeyVaultAPIClientSecret"

#region Create cloud-init file
# It's probably a really bad idea to pass secrets like this to a yaml file, which is probably save on disk in the VM, or at least logged somewhere in some log file when executed
$yaml = @{
    "package_upgrade" = $true
    "packages" = @(
        "nginx"
    )
    "runcmd" = @(
        "echo ADAM COOK: install PowerShell Core"
        "wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb"
        "dpkg -i packages-microsoft-prod.deb"
        "apt-get update"
        "add-apt-repository universe"
        "apt-get install -y powershell"
        "echo ADAM COOK: get nginx config"
        "curl 'https://{0}.blob.core.windows.net/{1}/lb.codaamok.net{2}' --create-dirs -o /etc/nginx/sites-available/lb.codaamok.net" -f $StorageAccountName, $ContainerName, $SASToken.GetNetworkCredential().Password
        'ln -f -s /etc/nginx/sites-available/lb.codaamok.net /etc/nginx/sites-enabled/default'
        "echo ADAM COOK: get nginx certificates"
        "curl 'https://raw.githubusercontent.com/codaamok/PoSH/master/Azure/Get-AzAPIKeyVaultSecret.ps1' -o Get-AzAPIKeyVaultSecret.ps1"
        "pwsh -Command '& { ./Get-AzAPIKeyVaultSecret.ps1 -KeyVaultName {0} -SecretName codaamok-net-fullchain-pem -TenantId {1} -ClientId {2} -ClientSecret {3} -SubscriptionId {4} | Select-Object -ExpandProperty value }' >> /etc/letsencrypt/live/codaamok.net/fullchain.pem" -f $KeyVault.VaultName, $AzureTenantId, $AzureApp.UserName, $AzureApp.GetNetworkCredential().Password, $SubscriptionId
        "pwsh -Command '& { ./Get-AzAPIKeyVaultSecret.ps1 -KeyVaultName {0} -SecretName codaamok-net-privkey-pem -TenantId {1} -ClientId {2} -ClientSecret {3} -SubscriptionId {4} | Select-Object -ExpandProperty value }' >> /etc/letsencrypt/live/codaamok.net/privkey.pem" -f $KeyVault.VaultName, $AzureTenantId, $AzureApp.UserName, $AzureApp.GetNetworkCredential().Password, $SubscriptionId
        "echo ADAM COOK: set certificate permissions"
        "chmod 600 /etc/letsencrypt/live/codaamok.net/fullchain.pem /etc/letsencrypt/live/codaamok.net/privkey.pem"
        "echo ADAM COOK: create nginx root index file"
        "mkdir -p /var/www/lb.codaamok.net && hostname >> /var/www/lb.codaamok.net/index.html"
    )
    "power_state" = @{
        "mode" = "reboot"
        "message" = "ADAM COOK: rebooting now"
        "condition" = $true
    }
}
#endregion

foreach ($item in $Lowest..$Highest) {
    #region Name resources
    # https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging#example-names
    $ServerName          = "nginx{0:D3}" -f $item
    $VMName              = "vm{0}" -f $ServerName
    $RGName              = "rg-{0}-lab-001" -f $ServerName
    $VNICName            = "nic-001-{0}" -f $ServerName
    $SubnetName          = "snet-lab-{0}-{0:D3}" -f $Location, $item
    $SubnetAddressPrefix = "192.168.10{0}.0/24" -f $item
    $NSGName             = "nsg-{0}-001" -f $ServerName
    $PIPName             = "pip-{0}-lab-{1}-001" -f $ServerName, $Location
    # $VMStorageAccName  = "stvmpm{0}{1}{2:D3}" -f $ServerName, $Location, $item
    #endregion

    Write-Verbose "Creating resource group $RGName"
    $RG = New-AzResourceGroup -Name $RGName -Location $Location

    $KeyFile = "{0}\.ssh\{1}" -f [Environment]::GetFolderPath("MyDocuments"), $VMName
    $Comment = "localhost={0} target={1} created={2}" -f $env:ComputerName, $VMName, $Date

    if (Test-Path $KeyFile) {
        Remove-Item $KeyFile* -Force
    }

    Write-Verbose "Generating ssh key pair"
    ssh-keygen.exe -t "rsa" -b 4096 -N (Get-Secure "azure-arm-testing").GetNetworkCredential().Password -C $Comment -f $KeyFile -q

    $PublicKey = Get-Content -Path ("{0}.pub" -f $KeyFile)
    $PrivateKey = (Get-Content -Path $KeyFile) -join "`n"

    if (Test-Path $KeyFile) {
        Copy-Item $KeyFile $home\.ssh -Force
    }

    Write-Verbose "Stashing private key to key vault"
    $Secret = Set-AzKeyVaultSecret -VaultName $KeyVault.VaultName -Name ("{0}-PrivateKey" -f $VMName) -SecretValue (ConvertTo-SecureString -String $PrivateKey -AsPlainText -Force)

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
                            sourceAddressPrefix = $NSGAllowedIPs
                            sourcePortRange = "*"
                            destinationAddressPrefix = "*"
                            destinationPortRange = "22"
                        }
                    },
                    [PSCustomObject]@{
                        name = "HTTP"
                        properties = [PSCustomObject]@{
                            priority = 400
                            protocol = "TCP"
                            access = "Allow"
                            direction = "Inbound"
                            sourceAddressPrefix = "*"
                            sourcePortRange = "*"
                            destinationAddressPrefix = "*"
                            destinationPortRange = "80"
                        }
                    },
                    [PSCustomObject]@{
                        name = "HTTPS"
                        properties = [PSCustomObject]@{
                            priority = 500
                            protocol = "TCP"
                            access = "Allow"
                            direction = "Inbound"
                            sourceAddressPrefix = "*"
                            sourcePortRange = "*"
                            destinationAddressPrefix = "*"
                            destinationPortRange = "443"
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
                            addressPrefix = $SubnetAddressPrefix
                        }
                    }
                )
            }
            virtualNetworkName = [PSCustomObject]@{
                "value" = $VNetName
            }
            vnetAddressPrefixes = [PSCustomObject]@{
                "value" = @($VNetAddressPrefix)
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
            blobStorageUrl = [PSCustomObject]@{
                # the trailing slash is important!
                # https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/template-functions-string#uri
                "value" = "https://{0}.blob.core.windows.net/{1}/" -f $StorageAccountName, $ContainerName
            }
            blobStorageSASToken = [PSCustomObject]@{
                "value" = $SASToken.GetNetworkCredential().Password
            }
            cloudinitCustomData = [PSCustomObject]@{
                "value" = (ConvertTo-Yaml -Data $yaml).Insert(0, "#cloud-config`n")
            }
        }
    } | ConvertTo-Json -Depth 5 | Set-Content -Path $ArmTemplateParameters -Force

    $DeploymentName = "{0}_{1}" -f $VMName, (Get-Date $Date -Format 'yyyy-MM-dd_HH-mm-ss')

    Write-Verbose "Creating deployment using template"
    # Didn't realise the template parameter object parameter accepted hashtable and not json
    $Deployment = New-AzResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $RG.ResourceGroupName -TemplateFile $ArmTemplate -TemplateParameterFile $ArmTemplateParameters

    $Deployment

    Remove-Item $ArmTemplateParameters -Force
}
