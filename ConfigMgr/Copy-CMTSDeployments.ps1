function Copy-CMTSDeployments {
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
        Created: 2018-10-25
        Updated: 2020-01-21
    #>
    [CmdletBinding(SupportsShouldProcess)]
    #Requires -Module ConfigurationManager
    Param (
        [Parameter(Mandatory)]
        [String]$taskSequenceId_old = "P010037A",
        [Parameter(Mandatory)]
        [String]$taskSequenceId_new = "P01004EA",
        [Parameter()]
        [DateTime]$Date = (Get-Date),
        [Parameter()]
        [String[]]$ExcludeCollections
    )

    ForEach ($TS in @($taskSequenceId_old, $taskSequenceId_new)) {
        if (-not(Get-CMTaskSequence -TaskSequencePackageId $TS)) {
            throw ("Task sequence '{0}' not found" -f $TS)
        }
    }

    # Example way to create simple datetime object to populate $Date
    # $Date = Get-Date -Year 2020 -Month 01 -Day 21 -Hour 12 -Minute 0 -Second 0

    $collectionIds = Get-CMTaskSequenceDeployment -TaskSequenceId $taskSequenceId_old | Select-Object -ExpandProperty CollectionId 

    #$CMSchedule = New-CMSchedule -Start $Date -Nonrecurring 

    $Comment = "Created by user {0} on {1}" -f $env:username, (Get-Date).ToString()

    ForEach ($collection in $collectionIds) { 
        if ($ExcludeCollections -contains $collection) {
            Write-Output ("Excluded: '{0}'" -f $collection)
            continue
        }
        $HashArguments = @{
            CollectionId                = $collection
            TaskSequencePackageId       = $taskSequenceId_new
            Comment                     = $Comment
            DeployPurpose               = "Required"
            Availability                = "MediaAndPxe"
            UseUtcForAvailableSchedule  = $true
            #Schedule                    = $CMSchedule
            ScheduleEvent               = "AsSoonAsPossible"
            RerunBehavior               = "RerunIfFailedPreviousAttempt"
            ShowTaskSequenceProgress    = $true
            SoftwareInstallation        = $true
            SystemRestart               = $true
            InternetOption              = $false
            DeploymentOption            = "DownloadContentLocallyWhenNeededByRunningTaskSequence"
            AllowSharedContent          = $false
            AllowFallback               = $false
            AvailableDateTime           = $Date
            UseMeteredNetwork           = $false
            PersistOnWriteFilterDevice  = $true
            SendWakeupPacket            = $false
            ErrorAction                 = "Stop"
            WhatIf                      = $WhatIfPreference
        }
        try {
            New-CMTaskSequenceDeployment @HashArguments | Out-Null
            Write-Output ("Success: {0}" -f $collection)
        }
        catch {
            Write-Output ("Failed: {0}" -f $collection)
        }
    }
}