function Copy-CMTSDeployments {
    <#
    .SYNOPSIS
        A function to copy deployments from one task sequence to another. Modify the New-CMTaskSequenceDeployment parameters in the splat as desired.
    .EXAMPLE
        PS C:\> Copy-CMTSDeployments -taskSequenceId_old "ABC0037A" -taskSequenceId_new "ABC004EA" -ExcludeCollections "ABC0133F", "ABC01340"
        
        Gathers all deployments from task sequence ABC0037A and deploys them to ABC004EA, excluding ABC0133F and ABC01340.
    .NOTES
        Author: Adam Cook @codaamok
    #>
    [CmdletBinding()]
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

    foreach ($TS in @($taskSequenceId_old, $taskSequenceId_new)) {
        if (-not(Get-CMTaskSequence -TaskSequencePackageId $TS)) {
            throw ("Task sequence '{0}' not found" -f $TS)
        }
    }

    $collectionIds = Get-CMTaskSequenceDeployment -TaskSequenceId $taskSequenceId_old | Select-Object -ExpandProperty CollectionId 

    #$CMSchedule = New-CMSchedule -Start $Date -Nonrecurring 

    $Comment = "Created by user {0} on {1}" -f $env:username, (Get-Date).ToString()

    foreach ($collection in $collectionIds) { 
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
            AvailableDateTime           = $Date.AddDays(-1)
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
            Write-Error -ErrorRecord $_
            Write-Output ("Failed: {0}" -f $collection)
        }
    }
}