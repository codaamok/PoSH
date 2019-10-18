<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    TODO:
        # perhaps function-ise the folder rotation
    General notes
#>
# Overview:
# delete n-2
# copy n-1 n-2
# copy n to n-1
# service
#Requires -Version 5.1
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, Position = 0, HelpMessage="Package ID of the OS image.")]
    [String[]]
    $PackageID,
    [Parameter(Mandatory=$true, Position = 1, HelpMessage="ConfigMgr site server of the site site code.")]
    [ValidateScript({
        If(!(Test-Connection -ComputerName $_ -Count 1 -ErrorAction SilentlyContinue)) {
            throw "Host `"$($_)`" is unreachable"
        } Else {
            return $true
        }
    })]
    [string]$SiteServer,
    [Parameter(Mandatory=$false, Position = 2, HelpMessage="ConfigMgr site code you are querying.")]
    [ValidatePattern('^[a-zA-Z0-9]{3}$')]
    [string]$SiteCode
)

-Begin {

    $JobId = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'

    #region Define functions
    Function Write-CMLogEntry {
        <#
        .SYNOPSIS
        Write to log file in CMTrace friendly format.
        .DESCRIPTION
        Half of the code in this function is Cody Mathis's. I added log rotation and some other bits, with help of Chris Dent for some sorting and regex. Should find this code on the WinAdmins GitHub repo for configmgr.
        .OUTPUTS
        Writes to $Folder\$FileName and/or standard output.
        .LINK
        https://github.com/winadminsdotorg/SystemCenterConfigMgr
        #>
        param (
            [parameter(Mandatory = $true, HelpMessage = 'Value added to the log file.')]
            [ValidateNotNullOrEmpty()]
            [string]$Value,
            [parameter(Mandatory = $false, HelpMessage = 'Severity for the log entry. 1 for Informational, 2 for Warning and 3 for Error.')]
            [ValidateNotNullOrEmpty()]
            [ValidateSet('1', '2', '3')]
            [string]$Severity = 1,
            [parameter(Mandatory = $false, HelpMessage = "Stage that the log entry is occuring in, log refers to as 'component'.")]
            [ValidateNotNullOrEmpty()]
            [string]$Component,
            [parameter(Mandatory = $true, HelpMessage = 'Name of the log file that the entry will written to.')]
            [ValidateNotNullOrEmpty()]
            [string]$FileName,
            [parameter(Mandatory = $true, HelpMessage = 'Path to the folder where the log will be stored.')]
            [ValidateNotNullOrEmpty()]
            [string]$Folder,
            [parameter(Mandatory = $false, HelpMessage = 'Set timezone Bias to ensure timestamps are accurate.')]
            [ValidateNotNullOrEmpty()]
            [int32]$Bias,
            [parameter(Mandatory = $false, HelpMessage = 'Maximum size of log file before it rolls over. Set to 0 to disable log rotation.')]
            [ValidateNotNullOrEmpty()]
            [int32]$MaxLogFileSize = 0,
            [parameter(Mandatory = $false, HelpMessage = 'Maximum number of rotated log files to keep. Set to 0 for unlimited rotated log files.')]
            [ValidateNotNullOrEmpty()]
            [int32]$MaxNumOfRotatedLogs = 0,
            [parameter(Mandatory = $true, HelpMessage = 'A switch that enables the use of this function.')]
            [ValidateNotNullOrEmpty()]
            [switch]$Enable,
            [switch]$WriteHost
        )
    
        # Runs this regardless of $Enable value
        If ($WriteHost.IsPresent -eq $true) {
            Write-Host $Value
        }
    
        If ($Enable.IsPresent -eq $true) {
            # Determine log file location
            $LogFilePath = Join-Path -Path $Folder -ChildPath $FileName
    
            If ((([System.IO.FileInfo]$LogFilePath).Exists) -And ($MaxLogFileSize -ne 0)) {
    
                # Get log size in bytes
                $LogFileSize = [System.IO.FileInfo]$LogFilePath | Select-Object -ExpandProperty Length
    
                If ($LogFileSize -ge $MaxLogFileSize) {
    
                    # Get log file name without extension
                    $LogFileNameWithoutExt = $FileName -replace ([System.IO.Path]::GetExtension($FileName))
    
                    # Get already rolled over logs
                    $RolledLogs = "{0}_*" -f $LogFileNameWithoutExt
                    $AllLogs = Get-ChildItem -Path $Folder -Name $RolledLogs -File
    
                    # Sort them numerically (so the oldest is first in the list)
                    $AllLogs = $AllLogs | Sort-Object -Descending { $_ -replace '_\d+\.lo_$' }, { [Int]($_ -replace '^.+\d_|\.lo_$') }
                
                    ForEach ($Log in $AllLogs) {
                        # Get log number
                        $LogFileNumber = [int32][Regex]::Matches($Log, "_([0-9]+)\.lo_$").Groups[1].Value
                        switch (($LogFileNumber -eq $MaxNumOfRotatedLogs) -And ($MaxNumOfRotatedLogs -ne 0)) {
                            $true {
                                # Delete log if it breaches $MaxNumOfRotatedLogs parameter value
                                $DeleteLog = Join-Path $Folder -ChildPath $Log
                                [System.IO.File]::Delete($DeleteLog)
                            }
                            $false {
                                # Rename log to +1
                                $Source = Join-Path -Path $Folder -ChildPath $Log
                                $NewFileName = $Log -replace "_([0-9]+)\.lo_$",("_{0}.lo_" -f ($LogFileNumber+1))
                                $Destination = Join-Path -Path $Folder -ChildPath $NewFileName
                                [System.IO.File]::Copy($Source, $Destination, $true)
                            }
                        }
                    }
    
                    # Copy main log to _1.lo_
                    $NewFileName = "{0}_1.lo_" -f $LogFileNameWithoutExt
                    $Destination = Join-Path -Path $Folder -ChildPath $NewFileName
                    [System.IO.File]::Copy($LogFilePath, $Destination, $true)
    
                    # Blank the main log
                    $StreamWriter = [System.IO.StreamWriter]::new($LogFilePath, $false)
                    $StreamWriter.Close()
                }
            }
    
            # Construct time stamp for log entry
            switch -regex ($Bias) {
                '-' {
                    $Time = [string]::Concat($(Get-Date -Format 'HH:mm:ss.fff'), $Bias)
                }
                Default {
                    $Time = [string]::Concat($(Get-Date -Format 'HH:mm:ss.fff'), '+', $Bias)
                }
            }
    
            # Construct date for log entry
            $Date = (Get-Date -Format 'MM-dd-yyyy')
        
            # Construct context for log entry
            $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
        
            # Construct final log entry
            $LogText = [string]::Format('<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="{4}" type="{5}" thread="{6}" file="">', $Value, $Time, $Date, $Component, $Context, $Severity, $PID)
        
            # Add value to log file
            try {
                $StreamWriter = [System.IO.StreamWriter]::new($LogFilePath, 'Append')
                $StreamWriter.WriteLine($LogText)
                $StreamWriter.Close()
            }
            catch [System.Exception] {
                Write-Warning -Message ("Unable to append log entry to {0} file. Error message: {1}" -f $FileName, $_.Exception.Message)
            }
        }
    }
    #endregion

    #region PSDefaultParameterValues
    $PSDefaultParameterValues["Write-CMLogEntry:Bias"]=(Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias)
    $PSDefaultParameterValues["Write-CMLogEntry:Folder"]=($PSCommandPath | Split-Path -Parent)
    $PSDefaultParameterValues["Write-CMLogEntry:FileName"]=(($PSCommandPath | Split-Path -Leaf) + "_" + $JobId + ".log")
    $PSDefaultParameterValues["Write-CMLogEntry:Enable"]=$Log.IsPresent
    $PSDefaultParameterValues["Write-CMLogEntry:MaxLogFileSize"]=2MB
    $PSDefaultParameterValues["Write-CMLogEntry:MaxNumOfRotatedLogs"]=0
    #endregion

    Write-CMLogEntry -Value "Starting" -Severity 1 -Component "Initilisation" -WriteHost

    #region Initialise variables
    try {
        If ([string]::IsNullOrEmpty($SiteCode) -eq $true) {
            # Using a tmp variable because can't modify $SiteCode to fall outside of the ValidatePattern() attribute defined in the script's parameter block
            $tmp = Get-CimInstance -ComputerName $SiteServer -ClassName SMS_ProviderLocation -Namespace "ROOT\SMS" | Select-Object -ExpandProperty SiteCode
            If ($tmp.count -gt 1) {
                Write-CMLogEntry -Value ("Found multiple site codes: {0}" -f ($tmp -join ", ")) -Severity 1 -Component "Initilisation" -WriteHost
                throw
            } Else {
                # Reasonable assurance now the value confines to what's defined in ValidatePattern() attribute, so go ahead and reassign
                $SiteCode = $tmp
            }
            Write-CMLogEntry -Value ("Using site code: {0}" -f $SiteCode) -Severity 1 -Component "Initilisation" -WriteHost
        }
    }
    catch {
        $Message = "Could not determine site code, please provide it using the -SiteCode parameter, quiting"
        Write-CMLogEntry -Value $Message -Severity 1 -Component "Initilisation"
        throw $Message
    }

    $SiteNamespace = "ROOT\SMS\site_{0}" -f $SiteCode
    #endregion

}
-Process {
    ForEach ($pkgID in $PackageID) {

        Write-CMLogEntry -Value ("Working on: {0}" -f $pkgID) -Severity 1 -Component "Processing" -WriteHost

        # Get source path, skip $pkgID if error
        try {
            $Query = "SELECT PkgSourcePath FROM SMS_ImagePackage WHERE PackageID=''" -f $pkgID
            $SourcePath = Get-WmiObject -Query $Query -Namespace $SiteNamespace -ErrorAction Stop | Select-Object -ExpandProperty PkgSourcePath
        }
        catch {
            $Message = "Failed to get source path for: {0} ({1}), skipping..." -f $pkgID, $Error[0].Exception.Message
            Write-CMLogEntry -Value $Message -Severity 2 -Component "Processing" -WriteHost
            break
        }
        
        $Nminus2 = "{0}_N-2" -f $PackageID
        $Nminus1 = "{0}_N-1" -f $PackageID      

        Write-Verbose ("Checking if N-2 path exists: {0}" -f $Nminus2)
        if (Test-Path -LiteralPath $Nminus2 -PathType Container -ErrorAction SilentlyContinue) {
            try {
                Remove-Item -LiteralPath $Nminus2 -Recurse -Force -ErrorAction Stop
                $Message = "Successfully deleted N-2: {0}" -f $Nminus2
                Write-CMLogEntry -Value $Message -Severity 1 -Component "Processing" -WriteHost
            }
            catch {
                $Message = "Failed to delete N-2 folder: {0} ({1}), skipping..." -f $Nminus2, $Error[0].Exception.Message
                Write-CMLogEntry -Value $Message -Severity 2 -Component "Processing" -WriteHost
                break
            } 
        }
        else {
            Write-Verbose ("N-2 path does not exist: {0}" -f $Nminus2)
        }

        Write-Verbose ("Checking if N-1 path exists: {0}" -f $Nminus1)
        if (Test-Path -LiteralPath $Nminus1 -PathType Container -ErrorAction SilentlyContinue) {
            try {
                Move-Item -LiteralPath $Nminus1 -Destination $Nminus2 -Force -ErrorAction Stop
                $Message = "Successfully moved N-1 to N-2: {0} -> {1}" -f $Nminus1, $Nminus2
                Write-CMLogEntry -Value $Message -Severity 1 -Component "Processing" -WriteHost
            }
            catch {
                $Message = "Failed to move N-1 folder to N-2: {0} -> {1} ({2}), skipping..." -f $Nminus1, $Nminus2, $Error[0].Exception.Message
                Write-CMLogEntry -Value $Message -Severity 2 -Component "Processing" -WriteHost
                break
            } 
        }
        else {
            Write-Verbose ("N-1 path does not exist: {0}" -f $Nminus1)
        }

        Write-Verbose ("Checking if source path for {0} exists: {1}" -f $pkgID, $SourcePath)
        if (Test-Path -LiteralPath $SourcePath -PathType Container -ErrorAction SilentlyContinue) {
            try {
                Move-Item -LiteralPath $SourcePath -Destination $Nminus1 -Force -ErrorAction Stop
                $Message = "Successfully moved source path for {0} to N-1: {1} -> {2}" -f $pkgID, $SourcePath, $Nminus1
                Write-CMLogEntry -Value $Message -Severity 1 -Component "Processing" -WriteHost
            }
            catch {
                $Message = "Failed to move source path for {0} folder to N-1: {1} -> {2} ({3}), skipping..." -f $pkgID, $SourcePath, $Nminus1, $Error[0].Exception.Message
                Write-CMLogEntry -Value $Message -Severity 2 -Component "Processing" -WriteHost
                break
            } 
        }
        else {
            $Message = "Source path for {0} not exist: {1}, skipping..." -f $pkgID, $SourcePath
            Write-CMLogEntry -Value $Message -Severity 2 -Component "Processing" -WriteHost
            break
        }

        # Delete n-2
        # Move n-1 to n-2
        # Move n to n-1

        # Service
    }
}
-End {
    Write-CMLogEntry -Value "Finished" -Severity 1 -Component "Exit"
}