<#
.SYNOPSIS
    Get the latest version of a secret within a given Azure Key Vault
.DESCRIPTION
    Get the latest version of a secret within a given Azure Key Vault
.EXAMPLE
    PS C:\> .\Get-AzAPIKeyVaultSecret.ps1 -KeyVaultName "MyVault" -SecretName "SecretName" -TenantId "3882fa5f-e633-458d-b2a5-faf30be63e2a" -ClientId "34b3aff5-bc13-427c-8198-6c73255798de" -ClientSecret "asdasfaFsad32e23eASD#'#~~" -SubscriptionId "0375a967-1c42-4613-9d5f-085a011c1674"
    
    Gets secret value for secret "ScretName" within key vault "MyVault" within tenant "3882fa5f-e633-458d-b2a5-faf30be63e2a" and subscription "0375a967-1c42-4613-9d5f-085a011c1674" using authentication with client id "34b3aff5-bc13-427c-8198-6c73255798de" and client secret "asdasfaFsad32e23eASD#'#~~"
.NOTES
    Author: Adam Cook
#>
[CmdletBinding()]
param (
    [Parameter()]
    [String]$KeyVaultName,

    [Parameter()]
    [String]$SecretName,

    [Parameter(Mandatory)]
    [String]$TenantId,

    [Parameter(Mandatory)]
    [String]$ClientId,

    [Parameter(Mandatory)]
    [String]$ClientSecret,

    [Parameter(Mandatory)]
    [String]$SubscriptionId,

    [Parameter()]
    [String]$APIVersion = "7.0"
)

function Get-AzAccessToken {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]$TenantId,

        [Parameter(Mandatory)]
        [String]$ClientId,

        [Parameter(Mandatory)]
        [String]$ClientSecret,

        [Parameter(Mandatory)]
        [String]$Resource
    )

    $Uri = "https://login.microsoft.com/{0}/oauth2/token" -f $TenantId

    $Body = @{
        "grant_type" = "client_credentials"
        "client_id" = $ClientId
        "client_secret" = $ClientSecret
        "resource" = $Resource
    }

    Invoke-RestMethod -Method "POST" -Uri $Uri -Body $Body -ContentType 'application/x-www-form-urlencoded'
}

$AccessToken = Get-AzAccessToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret -Resource "https://vault.azure.net"
$KeyVaultDnsName = "https://{0}.vault.azure.net" -f $KeyVaultName
$Uri = "{0}/secrets/{1}?api-version={2}" -f $KeyVaultDnsName, $SecretName, $APIVersion
$Headers = @{
    "Authorization" = "{0} {1}" -f $AccessToken.token_type, $AccessToken.access_token
}

Invoke-RestMethod -Method "GET" -Uri $Uri -Headers $Headers
