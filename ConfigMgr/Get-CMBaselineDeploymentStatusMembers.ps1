Function Get-CMBaselineDeploymentStatusMembers {
    <#
    .SYNOPSIS
        A function to return the members for a Configuration Baseline (CI) deployment of a particular status, e.g. compliant, noncompliant or error.
    .DESCRIPTION
        This function will let you retrieve the list of members for a CI deployment of a particular status. It queries the site server's WMI so the console is not necessary and it can be ran remotely.
    .EXAMPLE
        PS C:\> Get-CMBaselineDeploymentStatusMembers -BaslineName "CB - Name of my baseline" -CollectionName "All Desktop and Server Clients" -Status NonCompliant -SiteServer server.contoso.com
            Gets all the members that are "NonCompliant" for the baseline "CB - Name of my baseline" deployed to "All Desktop and Server Clients"
    .NOTES
        Author: Adam Cook
        Contact: @codaamok
        Created: 2019-10-14
        Updated: 2019-10-14
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $BaslineName,
        [Parameter(Mandatory=$true, ParameterSetName="CollectionName")]
        [string]
        $CollectionName,
        [Parameter(Mandatory=$true, ParameterSetName="CollectionId")]
        [string]
        $CollectionId,
        [Parameter(Mandatory=$true)]
        [ValidateSet("Compliant","NonCompliant","Error")]
        [string]
        $Status,
        [Parameter(Mandatory=$true)]
        [string]
        $SiteServer
    )

    $SiteCode = Get-WmiObject -Query "SELECT SiteCode FROM SMS_ProviderLocation" -Namespace "ROOT\SMS" -ComputerName $SiteServer | Select-Object -ExpandProperty SiteCode
    $SiteNamespace = ("ROOT\SMS\site_{0}" -f $SiteCode)

    if ($CollectionName) {
        $Query = ("SELECT CollectionID FROM SMS_Collection WHERE Name=`"{0}`"" -f $CollectionName)
        $CollectionID = Get-WmiObject -Query $Query -Namespace $SiteNamespace | Select-Object -ExpandProperty CollectionID
    }

    $Query = ("SELECT CI_UniqueID,LocalizedDescription,DateCreated,DateLastModified FROM SMS_ConfigurationBaselineInfo WHERE LocalizedDisplayName=`"{0}`"" -f $BaslineName)
    $ConfigurationBaselineInfo = Get-WmiObject -Query $Query -Namespace $SiteNamespace

    $Query = ("SELECT AssignmentID FROM SMS_BaselineAssignment WHERE AssignedCI_UniqueID=`"{0}`"" -f $ConfigurationBaselineInfo.CI_uniqueID)
    $AssignmentID = Get-WmiObject -Query $Query -Namespace $SiteNamespace | Select-Object -ExpandProperty AssignmentID

    $Query = ("SELECT AssetName FROM SMS_DCMDeployment{0}AssetDetails WHERE AssignmentID=`"{1}`"" -f $Status, $AssignmentID)
    $Members = Get-WmiObject -Query $Query -Namespace $SiteNamespace | Select-Object -ExpandProperty AssetName

    [PSCustomObject]@{
        BaselineName        = $BaslineName
        Description         = $ConfigurationBaselineInfo.LocalizedDescription
        DateCreated         = $ConfigurationBaselineInfo.DateCreated
        DateLastModified    = $ConfigurationBaselineInfo.DateLastModified
        MembersCount        = $Members.count
        Members             = $Members
    }

}
