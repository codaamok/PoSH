<#
.SYNOPSIS
    Get ConfigMgr Packages or Applications which are not deployed.
.DESCRIPTION
    Get ConfigMgr Packages or Applications which are not deployed. For Applications, ObjectID is always CI_ID.
.EXAMPLE
    PS C:\> Get-CMNonDeployedAppsPkgs.ps1 -SiteServer "primary.contoso.com"
    
    ObjectName            ObjectType  ObjectID PackageSize
    ----------            ----------  -------- -----------
    GIMP 2.10.8           Application 16873701      198936
    Python 3.7.3          Application 16873723       50405
    TreeSize Free 4.3.1   Application 16873730        7755
    VLC Media Player 3.06 Application 16873741      106690
    PuTTY 0.71            Application 16922343        6042
    darktable 2.6.2       Application 16999498       68356
    Evernote 6.20.2.8626  Application 16999508      127693
    Everything 1.4.1.935  Application 16999530        3143
    Firefox 69.0.1        Application 16999552       95072
    gitforwindows 2.23.0  Application 16999566       92926
    ...

    Get ConfigMgr Packages or Applications which are not deployed and also return its PackageSize property (in MBs).
.INPUTS
    This function does not accept input from the pipeline.
.OUTPUTS
    PSCustomObject
.NOTES
    Author: Adam Cook (@codaamok)
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [String]$SiteServer,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [String]$SiteCode
)

try {
    if (-not $PSBoundParameters.ContainsKey("SiteCode")) {
        $SiteCode = Get-CimInstance -ComputerName $SiteServer -ClassName SMS_ProviderLocation -Namespace "ROOT\SMS" | Select-Object -ExpandProperty SiteCode
        if ($SiteCode.count -gt 1) {
            $Message = "Found multiple site codes: {0}" -f ($SiteCode -join ", ")
            Write-Error -Message $Message -Category "InvalidOperation" -ErrorAction "Stop"
        }
        else {
            Write-Verbose -Message ("Found site code: {0}" -f $SiteCode)
        }    
    }
}
catch {
    Write-Error -ErrorRecord $_
    $Message = "Could not determine site code, please provide it using the -SiteCode parameter"
    Write-Error -Message $Message -Category $_.CategoryInfo.Category -ErrorAction "Stop"
}

enum SMS_DeploymentSummary_FeatureType {
    Application = 1
    Program
    MobileProgram
    Script
    SoftwareUpdate
    Baseline
    TaskSequence
    ContentDistribution
    DistributionPointGroup
    DistributionPointHealth
    ConfigurationPolicy
    AbstractConfigurationItem = 28
}

$Namespace = "root/sms/site_{0}" -f $SiteCode

#region Get Applications
$Splat = @{
    ComputerName = $SiteServer
    Namespace    = $Namespace
    Query        = "SELECT * FROM SMS_ApplicationLatest WHERE IsDeployed = {0}" -f [Int]$false
}
Get-CimInstance @Splat | Select-Object -Property @(
    @{ Name = "ObjectName";  Expression = { $_.LocalizedDisplayName } }
    @{ Name = "ObjectType";  Expression = { "Application" } }
    @{ Name = "ObjectID";    Expression = { $_.CI_ID } }
    @{ Name = "PackageSize"; Expression = { 
        $Splat["Query"] = "SELECT PackageSize FROM SMS_ContentPackage WHERE SecurityKey = '{0}'" -f $_.ModelName
        (Get-CimInstance @Splat).PackageSize
    } }
)
#endregion

#region Get Packages
#region Get already deployed Packages
$Splat["Query"] = "SELECT PackageID 
    FROM SMS_DeploymentSummary
    WHERE FeatureType='{0}'" -f [Int][SMS_DeploymentSummary_FeatureType]"Program"
$DeployedPackages = (Get-CimInstance @Splat).PackageID
#endregion

#region Get all packages minus already deployed Packages
$Splat["Query"] = "SELECT * FROM SMS_Package"
if ($DeployedPackages.Count -gt 0) {
    $Conditions = foreach ($Package in $DeployedPackages) {
        "PackageID != '{0}'" -f $Package
    }
    $Splat["Query"] = "{0} WHERE ( {1} )" -f $Splat["Query"], [String]::Join(" AND ", $Conditions)
}
Write-Verbose $Splat["Query"] -Verbose
Get-CimInstance @Splat | Select-Object -Property @(
    @{ Name = "ObjectName";  Expression = { $_.Name } }
    @{ Name = "ObjectType";  Expression = { "Package" } }
    @{ Name = "ObjectID";    Expression = { $_.PackageID } }
    "PackageSize"
)
#endregion
#endregion