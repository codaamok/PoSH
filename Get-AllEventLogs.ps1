function Get-AllEventLogs {
    <#
    .SYNOPSIS
        Query all logs or providers on a remote computer. Optionally provide a datetime range.
    .DESCRIPTION
        Query all logs or providers on a remote computer. Optionally provide a datetime range.
    .EXAMPLE
        PS C:\> $Date = (Get-Date -Year 2020 -Month 5 -Day 25 -Hour 1 -Minute 45 -Second 00)
        PS C:\> Get-AllEventLogs -ComputerName "server.contoso.com" -LogType "Providers" -StartTime $Date -TimeSpan (New-TimeSpan -Minutes 5)
        
        Returns logs from all providers from server.contoso.com between 01:45:00 25/05/2020 - 01:50:00 25/05/2020
    .NOTES
        Author: Adam Cook (@codaamok)
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, ParameterSetName="TimeSpan")]
        [Parameter(Mandatory, ParameterSetName="NoTimeSpan")]
        [String]$ComputerName,

        [Parameter(Mandatory, ParameterSetName="TimeSpan")]
        [Parameter(Mandatory, ParameterSetName="NoTimeSpan")]
        [ValidateSet("Logs", "Providers")]
        [String]$LogType,

        [Parameter(Mandatory, ParameterSetName="TimeSpan")]
        [DateTime]$StartTime,

        [Parameter(Mandatory, ParameterSetName="TimeSpan")]
        [TimeSpan]$TimeSpan
    )

    $GetWinEventSplat = @{ ComputerName = $ComputerName }

    switch ($LogType) {
        "Logs" {
            $GetWinEventSplat["ListLog"] = "*"
            $GetWinEventLogType          = "LogName"
            $LogNamePropertyName         = "LogName" # The name of the property for the name of the log or provider is different between eachother
        }
        "Providers" {
            $GetWinEventSplat["ListProvider"] = "*"
            $GetWinEventLogType               = "ProviderName"
            $LogNamePropertyName              = "Name" # The name of the property for the name of the log or provider is different between eachother
        }
    }

    $Logs = Get-WinEvent @GetWinEventSplat

    Write-Verbose -Message ("Query the following logs: {0}" -f [String]::Join(", ", $Logs.$LogNamePropertyName)) -Verbose
    Write-Verbose -Message ("Total number of logs: {0}" -f $Logs.Count) -Verbose

    $result = foreach ($Log in $Logs) {
        [Int32]$Percentage = $Logs.IndexOf($Log) / $Logs.Count * 100
        Write-Progress -Activity ("Querying {0}: {1}" -f $GetWinEventLogType, $Log.$LogNamePropertyName) -PercentComplete $Percentage -Status ("{0}% complete" -f $Percentage)
        
        $FilterHT = @{
            $GetWinEventLogType = $Log.$LogNamePropertyName
        }

        if ($PSCmdlet.ParameterSetName -eq "TimeRange") {
            $FilterHT["StartTime"] = $StartTime
            $FilterHT["EndTime"]   = $StartTime + $TimeSpan
        }

        try {
            Get-WinEvent -FilterHashtable $FilterHT -ComputerName $ComputerName -ErrorAction "Stop"
        }
        catch {
            if ($_.Exception.Message -ne "No events were found that match the specified selection criteria.") {
                Write-Verbose ("Error querying {0}" -f $FilterHT[$GetWinEventLogType]) -Verbose
                Write-Error -ErrorRecord $_
            }
        }
    }

    $result | Select-Object @(
        "TimeCreated",
        "Id"
        "ProviderName",
        @{Label="Message";Expression={$_.Message -replace "\r\n", " "}}
    ) | Sort-Object -Property TimeCreated
}