<#
.SYNOPSIS
    Get all ConfigMgr active deployments and understand the size of the collections they're deployed to.
.DESCRIPTION
    Get all ConfigMgr active deployments and understand the size of the collections they're deployed to. For Applications, ObjectID is always CI_ID.
.EXAMPLE
    PS C:\> Get-CMDeploymentCollections.ps1 -SiteServer "primary.contoso.com"
    
    ObjectName     : OSD - Modular OSD - Production
    ObjectType     : TaskSequence
    ObjectID       : ABC0011F
    CollectionID   : ABC0003C
    CollectionName : OSD - Windows 10 1909 - de-de
    CollectionType : DeviceCollection
    MemberCount    : 0
    DeploymentID   : ABC2000F

    ObjectName     : OSD - Modular OSD - Production
    ObjectType     : TaskSequence
    ObjectID       : ABC0011F
    CollectionID   : ABC0003D
    CollectionName : OSD - Windows 10 1909 - en-gb
    CollectionType : DeviceCollection
    MemberCount    : 1
    DeploymentID   : ABC20010

    ...

    Get all ConfigMgr active deployments including the "MemberCount" property to indicate the size of the collection each deployment is deployed to.
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

enum SMS_DeploymentSummary_CollectionType {
    UserCollection = 1
    DeviceCollection
}

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

$Namespace = "root/sms/site_{0}" -f $SiteCode
$Query = "SELECT * FROM SMS_DeploymentSummary"

Get-CimInstance -ComputerName $SiteServer -Namespace $Namespace -Query $Query | Select-Object -Property @(
    @{ Name = "ObjectName"; Expression = { $_.ApplicationName } }
    @{ Name = "ObjectType"; Expression = { [SMS_DeploymentSummary_FeatureType]$_.FeatureType } }
    # Applications contain both CI_ID and PackageID, so want CI_ID if FeatureType is Application, otherwise return PackageID if it exists, failing that return CI_ID if it exists, failing that return null.
    @{ Name = "ObjectID";   Expression = { if ($_.PSObject.Properties.Name -contains "CI_ID" -And [SMS_DeploymentSummary_FeatureType]$_.FeatureType -match "Application|Baseline|ConfigurationPolicy|SoftwareUpdate") {
        $_.CI_ID
    }
    elseif ($_.PSObject.Properties.Name -contains "PackageID" -And -not [String]::IsNullOrEmpty($_.PackageID)) {
        $_.PackageID
    }
    elseif ($_.PSObject.Properties.Name -contains "CI_ID" -And -not [String]::IsNullOrEmpty($_.CI_ID)) {
        $_.CI_ID
    }
    else {
        $null
    } } }
    @{ Name = "PackageSize"; Expression = { 
        if ([SMS_DeploymentSummary_FeatureType]$_.FeatureType -eq "Application") {
            $Query = "SELECT PackageSize FROM SMS_ContentPackage WHERE SecurityKey='{0}'" -f $_.ModelName
            (Get-CimInstance -ComputerName $SiteServer -Namespace $Namespace -Query $Query).PackageSize
        } elseif ([SMS_DeploymentSummary_FeatureType]$_.FeatureType -eq "Program") {
            $Query = "SELECT PackageSize FROM SMS_Package WHERE PackageID='{0}'" -f $_.PackageID
            (Get-CimInstance -ComputerName $SiteServer -Namespace $Namespace -Query $Query).PackageSize
        } 
    } }
    "CollectionID"
    "CollectionName"
    @{ Name = "CollectionType"; Expression = { [SMS_DeploymentSummary_CollectionType]$_.CollectionType } }
    @{ Name = "MemberCount";    Expression = { 
        $Query = "SELECT MemberCount FROM SMS_Collection WHERE CollectionID='{0}'" -f $_.CollectionID
        try {
            Get-CimInstance -ComputerName $SiteServer -Namespace $Namespace -Query $Query -ErrorAction "Stop" | Select-Object -ExpandProperty MemberCount
        }
        catch {
            $null
            Write-Error -ErrorRecord $_
        }
    }}
    "DeploymentID"
)
