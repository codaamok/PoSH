Function prompt {
    # .Description
    # This custom version of the PowerShell prompt will present a colorized location value based on the current provider. It will also display the PS prefix in red if the current user is running as administrator.    
    # .Link
    # https://go.microsoft.com/fwlink/?LinkID=225750
    # .ExternalHelp System.Management.Automation.dll-help.xml
    if ($PSVersionTable.PSVersion -ge [System.Version]"6.0") {
        Write-Host ('[{0}@{1}] [{2}] PS ' -f $env:USER, [System.Net.Dns]::GetHostName(), (Get-Date -Format "HH:mm:ss")) -NoNewline
        Write-Host $executionContext.SessionState.Path.CurrentLocation -ForegroundColor "Green"
        Write-Output "$('>' * ($nestedPromptLevel + 1)) "
        #Write-Host "[$env:USER@$Hostname] " -NoNewline
    }
    else {
        $user = [Security.Principal.WindowsIdentity]::GetCurrent()
        switch ((New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
            $true {
                $adminfg = "red"
            }
            $false {
                $adminfg = "white"
            }
        }
        switch ((Get-Location).Provider.Name) {
            "FileSystem"    { $fg = "green"}
            "Registry"      { $fg = "magenta"}
            "wsman"         { $fg = "cyan"}
            "Environment"   { $fg = "yellow"}
            "Certificate"   { $fg = "darkcyan"}
            "Function"      { $fg = "gray"}
            "alias"         { $fg = "darkgray"}
            "variable"      { $fg = "darkgreen"}
            default         { $fg = $host.ui.rawui.ForegroundColor}
        }
        Write-Host "[$env:USERNAME@$env:COMPUTERNAME] " -NoNewline
        Write-Host "[$(Get-Date -Format "HH:mm:ss")]" -NoNewline
        Write-Host " PS " -NoNewline -ForegroundColor $adminfg
        Write-Host "$($ExecutionContext.SessionState.Path.CurrentLocation)" -ForegroundColor $fg -NoNewline
        Write-Output "$('>' * ($nestedPromptLevel + 1)) "
        Write-Host "" 
    }
}

Function Get-HostName {

}

Function Reset-CMClientPolicy {
    Invoke-WmiMethod -Class SMS_Client -Namespace root\ccm -Name ResetPolicy -ArgumentList 1
}

function Show-JobProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Job[]]
        $Job
        ,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [scriptblock]
        $FilterScript
    )

    Process {
        $Job.ChildJobs | ForEach-Object {
            if (-not $_.Progress) {
                return
            }

            $LastProgress = $_.Progress
            if ($FilterScript) {
                $LastProgress = $LastProgress | Where-Object -FilterScript $FilterScript
            }

            $LastProgress | Group-Object -Property Activity,StatusDescription | ForEach-Object {
                $_.Group | Select-Object -Last 1

            } | ForEach-Object {
                $ProgressParams = @{}
                if ($_.Activity          -and $_.Activity          -ne $null) { $ProgressParams.Add('Activity',         $_.Activity) }
                if ($_.StatusDescription -and $_.StatusDescription -ne $null) { $ProgressParams.Add('Status',           $_.StatusDescription) }
                if ($_.CurrentOperation  -and $_.CurrentOperation  -ne $null) { $ProgressParams.Add('CurrentOperation', $_.CurrentOperation) }
                if ($_.ActivityId        -and $_.ActivityId        -gt -1)    { $ProgressParams.Add('Id',               $_.ActivityId) }
                if ($_.ParentActivityId  -and $_.ParentActivityId  -gt -1)    { $ProgressParams.Add('ParentId',         $_.ParentActivityId) }
                if ($_.PercentComplete   -and $_.PercentComplete   -gt -1)    { $ProgressParams.Add('PercentComplete',  $_.PercentComplete) }
                if ($_.SecondsRemaining  -and $_.SecondsRemaining  -gt -1)    { $ProgressParams.Add('SecondsRemaining', $_.SecondsRemaining) }

                Write-Progress @ProgressParams
            }
        }
    }
}

Function Get-ScheduledTasks {  
    <#
    .SYNOPSIS
        Get scheduled task information from a system
        https://gallery.technet.microsoft.com/Get-ScheduledTasks-Get-d2207def
    
    .DESCRIPTION
        Get scheduled task information from a system

        Uses Schedule.Service COM object, falls back to SchTasks.exe as needed.
        When we fall back to SchTasks, we add empty properties to match the COM object output.

    .PARAMETER ComputerName
        One or more computers to run this against

    .PARAMETER Folder
        Scheduled tasks folder to query.  By default, "\"

    .PARAMETER Recurse
        If specified, recurse through folders below $folder.
        
        Note:  We also recurse if we use SchTasks.exe

    .PARAMETER Path
        If specified, path to export XML files
        
        Details:
            Naming scheme is computername-taskname.xml
            Please note that the base filename is used when importing a scheduled task.  Rename these as needed prior to importing!

    .PARAMETER Exclude
        If specified, exclude tasks matching this regex (we use -notmatch $exclude)

    .PARAMETER CompatibilityMode
        If specified, pull scheduled tasks only with the schtasks.exe command, which works against older systems.
    
        Notes:
            Export is not possible with this switch.
            Recurse is implied with this switch.
    
    .EXAMPLE
    
        #Get scheduled tasks from the root folder of server1 and c-is-ts-91
        Get-ScheduledTasks server1, c-is-ts-91

    .EXAMPLE

        #Get scheduled tasks from all folders on server1, not in a Microsoft folder
        Get-ScheduledTasks server1 -recurse -Exclude "\\Microsoft\\"

    .EXAMPLE
    
        #Get scheduled tasks from all folders on server1, not in a Microsoft folder, and export in XML format (can be used to import scheduled tasks)
        Get-ScheduledTasks server1 -recurse -Exclude "\\Microsoft\\" -path 'D:\Scheduled Tasks'

    .NOTES
    
        Properties returned    : When they will show up
            ComputerName       : All queries
            Name               : All queries
            Path               : COM object queries, added synthetically if we fail back from COM to SchTasks
            Enabled            : COM object queries
            Action             : All queries.  Schtasks.exe queries include both Action and Arguments in this property
            Arguments          : COM object queries
            UserId             : COM object queries
            LastRunTime        : All queries
            NextRunTime        : All queries
            Status             : All queries
            Author             : All queries
            RunLevel           : COM object queries
            Description        : COM object queries
            NumberOfMissedRuns : COM object queries

        Thanks to help from Brian Wilhite, Jaap Brasser, and Jan Egil's functions:
            http://gallery.technet.microsoft.com/scriptcenter/Get-SchedTasks-Determine-5e04513f
            http://gallery.technet.microsoft.com/scriptcenter/Get-Scheduled-tasks-from-3a377294
            http://blog.crayon.no/blogs/janegil/archive/2012/05/28/working_2D00_with_2D00_scheduled_2D00_tasks_2D00_from_2D00_windows_2D00_powershell.aspx

    .FUNCTIONALITY
        Computers

    #>
    [cmdletbinding(
        DefaultParameterSetName='COM'
    )]
    param(
        [parameter(
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true, 
            ValueFromRemainingArguments=$false, 
            Position=0
        )]
        [Alias("host","server","computer")]
        [string[]]$ComputerName = "localhost",

        [parameter()]
        [string]$folder = "\",

        [parameter(ParameterSetName='COM')]
        [switch]$recurse,

        [parameter(ParameterSetName='COM')]
        [validatescript({
            #Test path if provided, otherwise allow $null
            if($_){
                Test-Path -PathType Container -path $_ 
            }
            else {
                $true
            }
        })]
        [string]$Path = $null,

        [parameter()]
        [string]$Exclude = $null,

        [parameter(ParameterSetName='SchTasks')]
        [switch]$CompatibilityMode
    )
    Begin{

        if(-not $CompatibilityMode){
            $sch = New-Object -ComObject Schedule.Service
        
            #thanks to Jaap Brasser - http://gallery.technet.microsoft.com/scriptcenter/Get-Scheduled-tasks-from-3a377294
            function Get-AllTaskSubFolders {
                [cmdletbinding()]
                param (
                    # Set to use $Schedule as default parameter so it automatically list all files
                    # For current schedule object if it exists.
                    $FolderRef = $sch.getfolder("\"),

                    [switch]$recurse
                )

                #No recurse?  Return the folder reference
                if (-not $recurse) {
                    $FolderRef
                }
                #Recurse?  Build up an array!
                else {
                    Try{
                        #This will fail on older systems...
                        $folders = $folderRef.getfolders(1)

                        #Extract results into array
                        $ArrFolders = @(
                            if($folders) {
                                foreach ($fold in $folders) {
                                    $fold
                                    if($fold.getfolders(1)) {
                                        Get-AllTaskSubFolders -FolderRef $fold
                                    }
                                }
                            }
                        )
                    }
                    Catch{
                        #If we failed and the expected error, return folder ref only!
                        if($_.tostring() -like '*Exception calling "GetFolders" with "1" argument(s): "The request is not supported.*')
                        {
                            $folders = $null
                            Write-Warning "GetFolders failed, returning root folder only: $_"
                            Return $FolderRef
                        }
                        else{
                            Throw $_
                        }
                    }

                    #Return only unique results
                        $Results = @($ArrFolders) + @($FolderRef)
                        $UniquePaths = $Results | select -ExpandProperty path -Unique
                        $Results | ?{$UniquePaths -contains $_.path}
                }
            } #Get-AllTaskSubFolders
        }

        function Get-SchTasks {
            [cmdletbinding()]
            param([string]$computername, [string]$folder, [switch]$CompatibilityMode)
            
            #we format the properties to match those returned from com objects
            $result = @( schtasks.exe /query /v /s $computername /fo csv |
                convertfrom-csv |
                ?{$_.taskname -ne "taskname" -and $_.taskname -match $( $folder.replace("\","\\") ) } |
                select @{ label = "ComputerName"; expression = { $computername } },
                    @{ label = "Name"; expression = { $_.TaskName } },
                    @{ label = "Action"; expression = {$_."Task To Run"} },
                    @{ label = "LastRunTime"; expression = {$_."Last Run Time"} },
                    @{ label = "NextRunTime"; expression = {$_."Next Run Time"} },
                    "Status",
                    "Author"
            )

            if($CompatibilityMode){
                #User requested compat mode, don't add props
                $result    
            }
            else{
                #If this was a failback, we don't want to affect display of props for comps that don't fail... include empty props expected for com object
                #We also extract task name and path to parent for the Name and Path props, respectively
                foreach($item in $result){
                    $name = @( $item.Name -split "\\" )[-1]
                    $taskPath = $item.name
                    $item | select ComputerName, @{ label = "Name"; expression = {$name}}, @{ label = "Path"; Expression = {$taskPath}}, Enabled, Action, Arguments, UserId, LastRunTime, NextRunTime, Status, Author, RunLevel, Description, NumberOfMissedRuns
                }
            }
        } #Get-SchTasks
    }    
    Process{
        #loop through computers
        foreach($computer in $computername){
        
            #bool in case com object fails, fall back to schtasks
            $failed = $false
        
            write-verbose "Running against $computer"
            Try {
            
                #use com object unless in compatibility mode.  Set compatibility mode if this fails
                if(-not $compatibilityMode){      

                    Try{
                        #Connect to the computer
                        $sch.Connect($computer)
                        
                        if($recurse)
                        {
                            $AllFolders = Get-AllTaskSubFolders -FolderRef $sch.GetFolder($folder) -recurse -ErrorAction stop
                        }
                        else
                        {
                            $AllFolders = Get-AllTaskSubFolders -FolderRef $sch.GetFolder($folder) -ErrorAction stop
                        }
                        Write-verbose "Looking through $($AllFolders.count) folders on $computer"
                
                        foreach($fold in $AllFolders){
                
                            #Get tasks in this folder
                            $tasks = $fold.GetTasks(0)
                
                            Write-Verbose "Pulling data from $($tasks.count) tasks on $computer in $($fold.name)"
                            foreach($task in $tasks){
                            
                                #extract helpful items from XML
                                $Author = ([regex]::split($task.xml,'<Author>|</Author>'))[1] 
                                $UserId = ([regex]::split($task.xml,'<UserId>|</UserId>'))[1] 
                                $Description =([regex]::split($task.xml,'<Description>|</Description>'))[1]
                                $Action = ([regex]::split($task.xml,'<Command>|</Command>'))[1]
                                $Arguments = ([regex]::split($task.xml,'<Arguments>|</Arguments>'))[1]
                                $RunLevel = ([regex]::split($task.xml,'<RunLevel>|</RunLevel>'))[1]
                                $LogonType = ([regex]::split($task.xml,'<LogonType>|</LogonType>'))[1]
                            
                                #convert state to status
                                Switch ($task.State) { 
                                    0 {$Status = "Unknown"} 
                                    1 {$Status = "Disabled"} 
                                    2 {$Status = "Queued"} 
                                    3 {$Status = "Ready"} 
                                    4 {$Status = "Running"} 
                                }

                                #output the task details
                                if(-not $exclude -or $task.Path -notmatch $Exclude){
                                    $task | select @{ label = "ComputerName"; expression = { $computer } }, 
                                        Name,
                                        Path,
                                        Enabled,
                                        @{ label = "Action"; expression = {$Action} },
                                        @{ label = "Arguments"; expression = {$Arguments} },
                                        @{ label = "UserId"; expression = {$UserId} },
                                        LastRunTime,
                                        NextRunTime,
                                        @{ label = "Status"; expression = {$Status} },
                                        @{ label = "Author"; expression = {$Author} },
                                        @{ label = "RunLevel"; expression = {$RunLevel} },
                                        @{ label = "Description"; expression = {$Description} },
                                        NumberOfMissedRuns
                            
                                    #if specified, output the results in importable XML format
                                    if($path){
                                        $xml = $task.Xml
                                        $taskname = $task.Name
                                        $xml | Out-File $( Join-Path $path "$computer-$taskname.xml" )
                                    }
                                }
                            }
                        }
                    }
                    Catch{
                        Write-Warning "Could not pull scheduled tasks from $computer using COM object, falling back to schtasks.exe"
                        Try{
                            Get-SchTasks -computername $computer -folder $folder -ErrorAction stop
                        }
                        Catch{
                            Write-Error "Could not pull scheduled tasks from $computer using schtasks.exe:`n$_"
                            Continue
                        }
                    }             
                }

                #otherwise, use schtasks
                else{
                
                    Try{
                        Get-SchTasks -computername $computer -folder $folder -CompatibilityMode -ErrorAction stop
                    }
                     Catch{
                        Write-Error "Could not pull scheduled tasks from $computer using schtasks.exe:`n$_"
                        Continue
                     }
                }

            }
            Catch{
                Write-Error "Error pulling Scheduled tasks from $computer`: $_"
                Continue
            }
        }
    }
}

Function Read-SMSTSLog {
    <#
    .DESCRIPTION
    Parses through the SMSTS log and returns the steps which succeeded, steps which failed, comptuer name, timestamp, and log name. 
    .PARAMETER Computer
    To view a remote machine's logs use this parameter to define the machine name. 
    .PARAMETER Path
    If for some reason the SMSTS log is not located in C:\Windows\CCM\Logs, use this parameter to define the folder path (Accepts UNC Paths)

    .NOTES
    Version:        1.0
    Author:         Amar Rathore
    Creation Date:  2019-03-25

    .EXAMPLE
    Read-SMSTSLog.ps1 -Computer PC01

    .EXAMPLE
    Read-SMSTSLog.ps1 -Path X:\Windows\Temp\
    #>

    [CmdletBinding()]

    Param (    
        [string]$Computer = "$env:ComputerName",
        [string]$Path = "\\$computer\c$\Windows\CCM\Logs",
        [pscredential]$Credential
    )

    If (Test-Connection $Computer -Count 1 -ErrorAction  SilentlyContinue) {

        function Read-Log {
            param (
                [Parameter(Mandatory = $true)][ValidateSet ('Success', 'Fail')][string]$status
            )        

            Switch ($status) {
                'Success' { $Pattern = 'Win32 Code 0'; $Regex = '\<\!\[LOG.*\((?<Message>\w+|.*)\).*\]LOG]\!\>\<time=\"(?<Time>.{12}).*date=\"(?<Date>.{10})' }
                'Fail' { $Pattern = 'Failed to run the action'; $Regex = '.*:\s(?<Message>.*|.*\n.*)\]\w+\].{3}time\S{2}(?<Time>.{12}).*date\S{2}(?<Date>.{10})' }
            }

            Get-Content $file | Select-String -Pattern $Pattern -Context 1| ForEach-Object {
                $_ -match $Regex | Out-Null

                [PSCustomObject]@{
                    Computer = $Computer
                    Time     = [datetime]::ParseExact($("$($matches.date) $($matches.time)"), "MM-dd-yyyy HH:mm:ss.fff", $null)
                    Message  = $Matches.Message
                    File     = $File
                }
            } | Format-Table -AutoSize
        }

        If ($PSBoundParameters.ContainsKey('Credential')) {
        New-PSDrive -Name $Computer -PSProvider FileSystem -Root "\\$Computer\c$" -Credential $Credential -ErrorAction Stop | Out-Null
        }

        If (Test-Path $path){
            $smstslog = (Get-ChildItem $path -Recurse -File | Where-Object {$_.Name -match "Smsts"}).FullName
        }
        Else {
        Write-Host "Unable to connect to $Path.`nIf you're attempting to connect to a remote machine try using the UNC path" -ForegroundColor Red -BackgroundColor Black
        return
        }

        $s = ForEach ($file in $smstslog) {Read-log -status 'Success'}
        $f = ForEach ($file in $smstslog) {Read-log -status 'Fail'}

        If ($s) {Write-host "`nCompleted the following steps:" -ForegroundColor Green -BackgroundColor Black; $s}
        If ($f) {Write-host 'Failed the following steps:' -ForegroundColor Red -BackgroundColor Black; $f}

        If (Get-PSDrive -Name $Computer) { 
        try {
            Remove-PSDrive -Name $Computer -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to remove PS drive `"${Computer}:`""
        }
        }
    }
    Else {
        Write-host "$Computer is offline/unreachable" -ForegroundColor Red -BackgroundColor Black
    }
}

function Measure-ChildItem {
    <#
    .SYNOPSIS
        Recursively measures the size of a directory.
    .DESCRIPTION
        Recursively measures the size of a directory.

        Measure-ChildItem uses  win32 functions, returning a minimal amount of information to gain speed. Once started, the operation cannot be interrupted by using Control and C. The more items present in a directory structure the longer this command will take.

        This command supports paths longer than 260 characters.
    .EXAMPLE
        Measure-ChildItem

        Get the size of all items within the current directory.
    .EXAMPLE
        Get-ChildItem c:\users | Measure-ChildItem -Unit MB

        Get the size of all child items of c:\users.
    .EXAMPLE
        Measure-ChildItem c:\windows -ValueOnly -Unit GB

        Return the size of the c:\windows directory and return only the size in GB.
    .EXAMPLE
        Get-ChildItem \\server\share -Directory | Measure-ChildItem -Unit TB -Digits 5

        Return the size of all items in a share.
    .NOTES
        Thanks Chris Dent! https://gist.github.com/indented-automation
    #>

    [CmdletBinding()]
    param (
        # The path to measure the size of. Accepts pipeline input. By default the size of the current working directory is measured.
        [Parameter(Position = 1, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [String]$Path = $pwd,

        # The units sizes should be displayed in. By default, sizes are displayed in Bytes.
        [ValidateSet('B', 'KB', 'MB', 'GB', 'TB')]
        [String]$Unit = 'B',

        # When rounding, the number of digits to display after a decimal point. By defaut sizes are rounded to two decimal places.
        [ValidateRange(0, 28)]
        [Int32]$Digits = 2,

        # Return the size value only, discards file, and directory counts and path information.
        [Switch]$ValueOnly
    )

    begin {
        if (-not ('SC.IO.FileSearcher' -as [Type])) {
            Add-Type '
                using System;
                using System.Collections.Generic;
                using System.IO;
                using System.Runtime.InteropServices;

                namespace SC.IO
                {
                    [StructLayout(LayoutKind.Sequential)]
                    public struct FILETIME
                    {
                        public uint dwLowDateTime;
                        public uint dwHighDateTime;
                    };

                    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
                    public struct WIN32_FIND_DATA
                    {
                        public FileAttributes dwFileAttributes;
                        public FILETIME ftCreationTime;
                        public FILETIME ftLastAccessTime;
                        public FILETIME ftLastWriteTime;
                        public int nFileSizeHigh;
                        public int nFileSizeLow;
                        public int dwReserved0;
                        public int dwReserved1;
                        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)]
                        public string cFileName;
                        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 14)]
                        public string cAlternate;
                    }

                    public class UnsafeNativeMethods
                    {
                        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
                        public static extern IntPtr FindFirstFile(string lpFileName, out WIN32_FIND_DATA lpFindFileData);

                        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
                        public static extern IntPtr FindFirstFileExW(
                            string              lpFileName,
                            int                 fInfoLevelId,
                            out WIN32_FIND_DATA lpFindFileData,
                            int                 fSearchOp,
                            IntPtr              lpSearchFilter,
                            int                 dwAdditionalFlags
                        );

                        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
                        public static extern bool FindNextFile(IntPtr hFindFile, out WIN32_FIND_DATA lpFindFileData);

                        [DllImport("kernel32.dll", SetLastError = true)]
                        [return: MarshalAs(UnmanagedType.Bool)]
                        public static extern bool FindClose(IntPtr hFindFile);
                    }

                    public class FileSearcher
                    {
                        private static uint convertToUInt(int value)
                        {
                            return BitConverter.ToUInt32(
                                BitConverter.GetBytes(value),
                                0
                            );
                        }

                        private static long convertToLong(int value)
                        {
                            return (long)(convertToUInt(value) << 32);
                        }

                        public static long[] MeasureItem(string path, bool recurse, long[] itemData)
                        {
                            if (itemData == null)
                            {
                                itemData = new long[]{ 0, 0, 0 };
                            }

                            string searchPath;
                            if (path.StartsWith(@"\\"))
                            {
                                searchPath = String.Format(@"\\?\UNC\{0}\*", path.Substring(2));
                            }
                            else
                            {
                                searchPath = String.Format(@"\\?\{0}\*", path);
                            }

                            WIN32_FIND_DATA findData = new WIN32_FIND_DATA();
                            IntPtr findHandle = UnsafeNativeMethods.FindFirstFileExW(searchPath, 1, out findData, 0, IntPtr.Zero, 0);
                            do
                            {
                                if (findData.dwFileAttributes.HasFlag(FileAttributes.Directory))
                                {
                                    if (recurse && findData.cFileName != "." && findData.cFileName != "..")
                                    {
                                        itemData[2]++;
                                        itemData = MeasureItem(
                                            Path.Combine(path, findData.cFileName),
                                            recurse,
                                            itemData
                                        );
                                    }
                                }
                                else
                                {
                                    itemData[0] += convertToLong(findData.nFileSizeHigh) + (long)convertToUInt(findData.nFileSizeLow);
                                    itemData[1]++;
                                }
                            } while (UnsafeNativeMethods.FindNextFile(findHandle, out findData));
                            UnsafeNativeMethods.FindClose(findHandle);

                            return itemData;
                        }
                    }
                }
            '
        }

        $power = ('B', 'KB', 'MB', 'GB', 'TB').IndexOf($Unit.ToUpper())
        $denominator = [Math]::Pow(1024, $power)
    }

    process {
        $Path = $pscmdlet.GetUnresolvedProviderPathFromPSPath($Path).TrimEnd('\')

        $itemData = [SC.IO.FileSearcher]::MeasureItem($Path, $true, $null)

        if ($ValueOnly) {
            [Math]::Round(($itemData[0] / $denominator), $Digits)
        } else {
            [PSCustomObject]@{
                Path           = $Path
                Size           = [Math]::Round(($itemData[0] / $denominator), $Digits)
                FileCount      = $itemData[1]
                DirectoryCount = $itemData[2]
            }
        }
    }
}

Function Change-Password ($domain,$samaccountname,$oldPassword,$newpassword){
    ([adsi]"WinNT://$domain/$samaccountname,user").ChangePassword($oldPassword,$newpassword)
}

Function Update-Profile {
    try {
        $R = Invoke-WebRequest https://www.cookadam.co.uk/profile -OutFile $profile.CurrentUserAllHosts -PassThru -ErrorAction Stop
    }
    catch {
        Write-Host "Error: " -ForegroundColor Red -NoNewline
        Write-Host $Error[0].Exception.Message
    }
    If ($R.StatusCode -eq 200) {
        '. $profile.CurrentUserAllHosts' | clip
        Write-Host "Paste your clipboard"
    }
}

Function Upload-Profile {
    <#
    .NOTES
    https://winscp.net/eng/docs/library_powershell
    #>
    Param(
        [Parameter(Mandatory=$true,Position=0)]
        [string]$user,
        [Parameter(Mandatory=$true,Position=1)]
        [string]$pass
    )

    switch ($true) {
        ((Test-Path -LiteralPath ("{0}\WinSCPnet.dll" -f ${env:ProgramFiles(x86)})) -And (Test-Path -LiteralPath ("{0}\WinSCP.exe" -f ${env:ProgramFiles(x86)}))) {
            $dllPath = ("{0}\WinSCPnet.dll" -f ${env:ProgramFiles(x86)})
            break
        }
        ((Test-Path -LiteralPath ("{0}\WinSCPnet.dll" -f $env:ProgramFiles)) -And (Test-Path -LiteralPath ("{0}\WinSCP.exe" -f $env:ProgramFiles))) {
            # Unlikely as WinSCP only 32bit and I don't think I ever touch 32bit systems
            $dllPath = ("{0}\WinSCPnet.dll" -f $env:ProgramFiles)
            break
        }
        ((Test-Path -LiteralPath ("{0}\WinSCP\WinSCPnet.dll" -f [System.Environment]::GetFolderPath("MyDocuments"))) -And (Test-Path -LiteralPath ("{0}\WinSCP\WinSCP.exe" -f [System.Environment]::GetFolderPath("MyDocuments")))) {
            $dllPath = ("{0}\WinSCP\WinSCPnet.dll" -f [System.Environment]::GetFolderPath("MyDocuments"))
            break
        }
        default {
            try {
                New-Item -Path ("{0}\WinSCP" -f [System.Environment]::GetFolderPath("MyDocuments")) -ItemType Directory -Force -ErrorAction Stop
                $zipPath = ("{0}\WinSCP\WinSCP-5.15.3-Automation.zip" -f [System.Environment]::GetFolderPath("MyDocuments"))
                $zipHash = "6FC1B65724665EF094B2CBFE3F2F8F996BAE627A4569F2C25867C98695ACD288"
                Invoke-WebRequest -Uri "https://www.cookadam.co.uk/scripts/WinSCP-5.15.3-Automation.zip" -OutFile $zipPath -ErrorAction Stop
                switch(Get-FileHash -LiteralPath $zipPath -Algorithm SHA256 | Select-Object -ExpandProperty Hash) {
                    $zipHash {
                        Add-Type -AssemblyName System.IO.Compression.FileSystem
                        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, (Split-Path -Path $zipPath))
                        $dllPath = ("{0}\WinSCP\WinSCPnet.dll" -f [System.Environment]::GetFolderPath("MyDocuments"))
                    }
                    default {
                        Throw "Hash mismatch from download"
                    }
                }
            }
            catch {
                Write-Host "Error: " -ForegroundColor Red -NoNewline
                Write-Host $Error[0].Exception.Message
                $problem = $true
            }
        }
    }

    $hostname = "ftp.cookadam.co.uk"
    $dir = "public_html/scripts/"
    switch ($problem) {
        $true {
            $Title = "Won't be able to upload using SFTP, proceed with FTP?"
            $y = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Proceed to upload via FTP"
            $n = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Abort upload"
            $options = [System.Management.Automation.Host.ChoiceDescription[]]($y,$n)
            $UseFTP = $host.ui.PromptForChoice($title, $null, $options, 1)
            switch ($UseFTP) {
                1 {
                    Write-Host "Aborting"
                    return
                }
                default {
                    try {
                        $ftp = ("ftp://{0}/{1}" -f $hostname, $dir)
                        $webclient = New-Object System.Net.WebClient 
                        $webclient.Credentials = New-Object System.Net.NetworkCredential($user,$pass)
                        $uri = New-Object -TypeName System.Uri -ArgumentList ($ftp+(Split-Path $profile.CurrentUserAllHosts -Leaf))
                        $webclient.UploadFile($uri, $profile.CurrentUserAllHosts)
                    }
                    catch {
                        Write-Host "Error: " -ForegroundColor Red -NoNewline
                        Write-Host $Error[0].Exception.Message
                    }
                }
            }
        }
        default {
            try {
                # Load WinSCP .NET assembly
                Add-Type -Path $dllPath
            
                # Setup session options
                $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
                    Protocol = [WinSCP.Protocol]::Sftp
                    HostName = $hostname
                    UserName = $user
                    Password = $pass
                    PortNumber = 722
                    SshHostKeyFingerprint = "ssh-ed25519 256 qzr6Ci1g8gxABaGNVI76RYRfPiVMX14a+1f4a7dxczU="
                }
            
                $session = New-Object WinSCP.Session
            
                try {
                    # Connect
                    $session.Open($sessionOptions)
            
                    # Upload files
                    $transferOptions = New-Object WinSCP.TransferOptions
                    $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary
            
                    $transferResult = $session.PutFiles($profile.CurrentUserAllHosts, $dir, $false, $transferOptions)
            
                    # Throw on any error
                    $transferResult.Check()
            
                    # Print results
                    foreach ($transfer in $transferResult.Transfers)
                    {
                        Write-Host "Success: " -ForegroundColor Green -NoNewline
                        Write-Host ("Upload of {0} [ OK ]" -f $transfer.FileName)
                    }
                }
                finally {
                    # Disconnect, clean up
                    $session.Dispose()
                }
            }
            catch {
                Write-Host "Error: " -ForegroundColor Red -NoNewline
                Write-Host $Error[0].Exception.Message
            }
        }
    }
}

Function Get-WUInstalledUpdates {
    Param(
        [Parameter()]
        [string]$ComputerName,
        [Parameter()]
        [PSCredential]$Credential,
        [Parameter()]
        [Switch]$ResolveKB
    )
    if ($ResolveKB.IsPresent -And (-not(Get-Module kbupdate))) {
        Import-Module "kbupdate" -ErrorAction "Stop"
    }
    $getHotFixSplat = @{
        ErrorAction = "Stop"
    }
    if ($PSBoundParameters.ContainsKey('Credential')) {
        $getHotFixSplat['Credential'] = $Credential
    }
    if ($PSBoundParameters.ContainsKey('ComputerName')) {
        $getHotFixSplat['ComputerName'] = $ComputerName
    }
    $Updates = Get-HotFix @getHotFixSplat
    if ($ResolveKB.IsPresent) {
        $Updates | Select-Object @(
            @{l="Title";e={[String]::Join(", ", (Get-KbUpdate -Pattern $_.HotfixId -Simple).Title)}}
            "Description",
            "HotFixId",
            "InstalledBy",
            @{l="InstalledOn";e={[DateTime]::Parse($_.psbase.properties["installedon"].value,$([System.Globalization.CultureInfo]::GetCultureInfo("en-US")))}}
        )
    }
    else {
        $Updates | Select-Object @(
            "Description",
            "HotFixId",
            "InstalledBy",
            @{l="InstalledOn";e={[DateTime]::Parse($_.psbase.properties["installedon"].value,$([System.Globalization.CultureInfo]::GetCultureInfo("en-US")))}}
        )
    }
}

Function Get-WUEventViewerLogs {
    Param (
        [Parameter()]
        [string]$ComputerName,
        [Parameter()]
        [int]$Days,
        [Parameter()]
        [PSCredential]$Credential,
        [Parameter()]
        [Switch]$ErrorOnly,
        [Parameter()]
        [Switch]$Installs,
        [Parameter()]
        [Switch]$Uninstalls,
        [Parameter()]
        [Switch]$ExcludeAV
    )
    $FilterHashtable = @{
        ProviderName = "Microsoft-Windows-WindowsUpdateClient"
    }
    $GetWinEventSplat = @{
        FilterHashTable = $FilterHashtable
    }
    switch ($true) {
        ($Days -gt 0) {
            $FilterHashtable["StartTime"] = (Get-Date).AddDays(-$Days)
        }
        $ErrorOnly.IsPresent {
            $FilterHashtable["Level"] = 2
        }
        $Installs.IsPresent {
            $FilterHashtable["Id"] = $FilterHashtable["Id"] + @(17,18,19,20,21,22, 43)
        }
        $Uninstalls.IsPresent {
            $FilterHashtable["Id"] = $FilterHashtable["Id"] + @(23,24)
        }
        $PSBoundParameters.ContainsKey("ComputerName") {
            $GetWinEventSplat["ComputerName"] = $ComputerName
        }
        $PSBoundParameters.ContainsKey('Credential') {
            $GetWinEventSplat["Credential"] = $Credential
        }
    }
    if ($ExcludeAV.IsPresent) {
        Get-WinEvent @GetWinEventSplat | Where-Object { $_.Message -notmatch "Definition Update" -And $_.Message -notmatch "Antivirus" }
    }
    else {
        Get-WinEvent @GetWinEventSplat
    }
}

function Get-WUCOMHistory {
    Param(
        [Parameter()]
        [String]$ComputerName,
        [Parameter()]
        [PSCredential]$Credential,
        [Parameter()]
        [Switch]$ExcludeAV
    )
    switch ($ExcludeAV.IsPresent) {
        $true {
            $ScriptBlock = {
                $Session = New-Object -ComObject Microsoft.Update.Session
                $Searcher = $Session.CreateUpdateSearcher()
                $HistoryCount = $Searcher.GetTotalHistoryCount()
                $Searcher.QueryHistory(0, $HistoryCount) | Where-Object { $_.Title -notmatch "Definition Update" -And $_.Title -notmatch "Antivirus" }
            }
        }
        $false {
            $ScriptBlock = {
                $Session = New-Object -ComObject Microsoft.Update.Session
                $Searcher = $Session.CreateUpdateSearcher()
                $HistoryCount = $Searcher.GetTotalHistoryCount()
                $Searcher.QueryHistory(0, $HistoryCount)
            }
        }
    }
    $InvokeCommandSplat = @{
        ScriptBlock = $ScriptBlock
    }
    if ($PSBoundParameters.ContainsKey("ComputerName")) {
        $InvokeCommandSplat.Add("ComputerName", $ComputerName)
    }
    if ($PSBoundParameters.ContainsKey("Credential")) {
        $InvokeCommandSplat.Add("Credential", $Credential)
    }
    Invoke-Command @InvokeCommandSplat
}

Function Get-WUWSUSRegKeys {
    Param( 
        [Parameter()]
        [String[]]$ComputerName,
        [Parameter()]
        [PSCredential]$Credential
    )
    $InvokeCommandSplat = @{
        ScriptBlock = {
            [PSCustomObject]@{
                WUServer = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "WUServer" -ErrorAction "SilentlyContinue").WUServer
                WUStatusServer = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "WUStatusServer" -ErrorAction "SilentlyContinue").WUStatusServer
                UseWUServer = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWUServer" -ErrorAction "SilentlyContinue").UseWUServer
                ComputerName = $env:COMPUTERNAME
            }
        }
    }
    if ($PSBoundParameters.ContainsKey("Credential")) {
        $InvokeCommandSplat["Credential"] = $Credential
    }
    $Jobs = ForEach($Computer in $ComputerName) {
        if ($PSBoundParameters.ContainsKey("ComputerName")) {
            $InvokeCommandSplat["ComputerName"] = $Computer
        }
        Invoke-Command @InvokeCommandSplat -AsJob
    }
    while (Get-Job -State "Running") {
        $TotalJobs = $Jobs.count
        $NotRunning = $Jobs | Where-Object { $_.State -ne "Running" }
        $Running = $Jobs | Where-Object { $_.State -eq "Running" }
        Write-Progress -Activity "Waiting on results" -Status "$($TotalJobs-$NotRunning.count) Jobs Remaining: $($Running.Location)" -PercentComplete ($NotRunning.count/(0.1+$TotalJobs) * 100)
        Start-Sleep -Seconds 2
    }
    Get-Job | Receive-Job
    Get-Job | Remove-Job
}

Function Remove-WUWSUSRegKeys {
    [CmdletBinding()]
    Param( 
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('PSComputerName')]
        [String[]]$ComputerName,
        [Parameter()]
        [PSCredential]$Credential
    )
    Begin {
        [System.Collections.Generic.List[Object]]$Jobs = @{}
    }
    Process {
        $InvokeCommandSplat = @{
            ScriptBlock = {
                $Result = [Ordered]@{}
                if ((Test-Path -LiteralPath "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate") -ne $true) {
                    throw "WindowsUpdate registry key does not exist"
                }
                if ((Test-Path -LiteralPath "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU") -ne $true) {
                    throw "WindowsUpdate registry key does not exist"
                }
                Remove-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "WUServer" -ErrorAction "SilentlyContinue"
                $Result["WUServer"] = $?
                Remove-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "WUStatusServer" -ErrorAction "SilentlyContinue"
                $Result["WUStatusServer"] = $?
                New-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWUServer" -Value 0 -PropertyType "DWord" -Force -ErrorAction "SilentlyContinue"| Out-Null
                $Result["UseWUServer"] = $?
                Get-Service -Name "wuauserv" | Restart-Service -Force -ErrorAction "SilentlyContinue"
                $Result["RestartWU"] = $?
                $Result["ComputerName"] = $env:COMPUTERNAME
                [PSCustomObject]$Result
            }
            ComputerName = $ComputerName
        }
        if ($PSBoundParameters.ContainsKey("Credential")) {
            $InvokeCommandSplat["Credential"] = $Credential
        }
        $Jobs.Add((Invoke-Command @InvokeCommandSplat -AsJob))
    }
    End {
        while (Get-Job -State "Running") {
            $TotalJobs = $Jobs.count
            $NotRunning = $Jobs | Where-Object { $_.State -ne "Running" }
            $Running = $Jobs | Where-Object { $_.State -eq "Running" }
            Write-Progress -Activity "Waiting on results" -Status "$($TotalJobs-$NotRunning.count) Jobs Remaining: $($Running.Location)" -PercentComplete ($NotRunning.count/(0.1+$TotalJobs) * 100)
            Start-Sleep -Seconds 2
        }
        Get-Job | Receive-Job
        Get-Job | Remove-Job
    }    
}

function Get-OS {
    Param (
        [Parameter(Mandatory)]
        [String]$ComputerName,
        [Parameter()]
        [PSCredential]$Credential
    )
    $newCimSessionSplat = @{
        ComputerName = $ComputerName
        ErrorAction = "Stop"
    }
    if ($PSBoundParameters.ContainsKey("Credential")) {
        $newCimSessionSplat["Credential"] = $Credential
    }
    $Session = New-CimSession @newCimSessionSplat 
    $getCimInstanceSplat = @{
        Query = "Select Caption from Win32_OperatingSystem"
        CimSession = $Session
    }
    Get-CimInstance @getCimInstanceSplat | Select-Object -ExpandProperty Caption
    Remove-CimSession $Session
}

Function Invoke-CMClientAction {
    Param( 
        [Parameter()]
        [String[]]$ComputerName,
        [Parameter()]
        [PSCredential]$Credential,
        [Parameter(Mandatory = $true)]
        [ValidateSet('MachinePolicy',
			'DiscoveryData',
			'ComplianceEvaluation',
			'AppDeployment', 
			'HardwareInventory',
			'UpdateDeployment',
			'UpdateScan',
			'SoftwareInventory')]
        [String]$Action
    )
    $ScheduleIDMappings = @{
        'MachinePolicy' = '{00000000-0000-0000-0000-000000000021}'
        'DiscoveryData' = '{00000000-0000-0000-0000-000000000003}'
        'ComplianceEvaluation' = '{00000000-0000-0000-0000-000000000071}'
        'AppDeployment' = '{00000000-0000-0000-0000-000000000121}'
        'HardwareInventory' = '{00000000-0000-0000-0000-000000000001}'
        'UpdateDeployment' = '{00000000-0000-0000-0000-000000000108}'
        'UpdateScan' = '{00000000-0000-0000-0000-000000000113}'
        'SoftwareInventory' = '{00000000-0000-0000-0000-000000000002}'
    }
    $ScheduleID = @{ "sScheduleID" = $ScheduleIDMappings[$Action] }
    $InvokeCommandSplat = @{
        ScriptBlock = {
            Param (
                [Parameter(Mandatory = $true)]
                [hashtable]$ScheduleID
            )
            $Result = @{
                ComputerName = $env:COMPUTERNAME
            }
            Invoke-CimMethod -Namespace "ROOT/CCM" -ClassName "SMS_Client" -MethodName "TriggerSchedule" -Arguments $ScheduleID -ErrorAction "Stop"
            $Result["Result"] = $?
            return [PSCustomObject]$Result
        }
        ArgumentList = $ScheduleID
    }
    if ($PSBoundParameters.ContainsKey("Credential")) {
        $InvokeCommandSplat["Credential"] = $Credential
    }
    $Jobs = ForEach($Computer in $ComputerName) {
        if ($PSBoundParameters.ContainsKey("ComputerName")) {
            $InvokeCommandSplat["ComputerName"] = $Computer
        }
        Invoke-Command @InvokeCommandSplat -AsJob
    }
    while (Get-Job -State "Running") {
        $TotalJobs = $Jobs.count
        $NotRunning = $Jobs | Where-Object { $_.State -ne "Running" }
        $Running = $Jobs | Where-Object { $_.State -eq "Running" }
        Write-Progress -Activity "Waiting on results" -Status "$($TotalJobs-$NotRunning.count) Jobs Remaining: $($Running.Location)" -PercentComplete ($NotRunning.count/(0.1+$TotalJobs) * 100)
        Start-Sleep -Seconds 2
    }
    Get-Job | Receive-Job
    Get-Job | Remove-Job
}

Function Get-Boot {
    Param (
        [Parameter()]
        [String[]]$ComputerName,
        [Parameter()]
        [PSCredential]$Credential
    )
    $HashArguments = @{
        ClassName = "Win32_OperatingSystem"
    }
    if ($PSBoundParameters.ContainsKey("ComputerName")) {
        $HashArguments["ComputerName"] = $ComputerName
    }
    if ($PSBoundParameters.ContainsKey('Credential')) {
        $HashArguments["Credential"] = $Credential
    }
    Get-CimInstance @HashArguments | Select-Object PSComputerName, LastBootUpTime
}

Function Get-Reboots {
    Param(
        [Parameter(Mandatory=$false,Position=0)]
        [string]$ComputerName,
        [Parameter(Mandatory=$false)]
        [PSCredential]$Credential
    )
    $HashArguments = @{
        FilterHashtable = @{
            LogName="System"
            ID=1074
        }
    } 
    if ($PSBoundParameters.ContainsKey("ComputerName")) {
        $HashArguments.Add("ComputerName", $ComputerName)
    }
    else {
        $HashArguments.Add("ComputerName", $env:COMPUTERNAME)
    }
    Get-WinEvent @HashArguments | ForEach-Object {
        [PSCustomObject]@{
            Date = $_.TimeCreated
            User = $_.Properties[6].Value
            Process = $_.Properties[0].Value
            Action = $_.Properties[4].Value
            Reason = $_.Properties[2].Value
            ReasonCode = $_.Properties[3].Value
            Comment = $_.Properties[5].Value
        }
    } | Sort-Object Date -Descending
}

Function Set-CMShortcuts { 
    Param( 
        [Parameter()]
        [String]$ComputerName,
        [Parameter()]
        [PSCredential]$Credential
    )
    Function Add-FileAssociation {
        <#
        .SYNOPSIS
        Set user file associations
        .DESCRIPTION
        Define a program to open a file extension
        .PARAMETER Extension
        The file extension to modify
        .PARAMETER TargetExecutable
        The program to use to open the file extension
        .PARAMETER ftypeName
        Non mandatory parameter used to override the created file type handler value
        .EXAMPLE
        $HT = @{
            Extension = '.txt'
            TargetExecutable = "C:\Program Files\Notepad++\notepad++.exe"
        }
        Add-FileAssociation @HT
        .EXAMPLE
        $HT = @{
            Extension = '.xml'
            TargetExecutable = "C:\Program Files\Microsoft VS Code\Code.exe"
            FtypeName = 'vscode'
        }
        Add-FileAssociation @HT
        .NOTES
        Found here: https://gist.github.com/p0w3rsh3ll/c64d365d15f6f39116dba1a26981dc68#file-add-fileassociation-ps1 https://p0w3rsh3ll.wordpress.com/2018/11/08/about-file-associations/
        #>
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [ValidatePattern('^\.[a-zA-Z0-9]{1,3}')]
            $Extension,
            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [ValidateScript({
                Test-Path -Path $_ -PathType Leaf
            })]
            [string]$TargetExecutable,
            [string]$ftypeName
        )
        Begin {
            $ext = [Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($Extension)
            $exec = [Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($TargetExecutable)
        
            # 2. Create a ftype
            if (-not($PSBoundParameters['ftypeName'])) {
                $ftypeName = '{0}{1}File'-f $($ext -replace '\.',''),
                $((Get-Item -Path "$($exec)").BaseName)
                $ftypeName = [Management.Automation.Language.CodeGeneration]::EscapeFormatStringContent($ftypeName)
            } else {
                $ftypeName = [Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($ftypeName)
            }
            Write-Verbose -Message "Ftype name set to $($ftypeName)"
        }
        Process {
            # 1. remove anti-tampering protection if required
            if (Test-Path -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$($ext)") {
                $ParentACL = Get-Acl -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$($ext)"
                if (Test-Path -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$($ext)\UserChoice") {
                    $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$($ext)\UserChoice",'ReadWriteSubTree','TakeOwnership')
                    $acl  = $k.GetAccessControl()
                    $null = $acl.SetAccessRuleProtection($false,$true)
                    $rule = New-Object System.Security.AccessControl.RegistryAccessRule ($ParentACL.Owner,'FullControl','Allow')
                    $null = $acl.SetAccessRule($rule)
                    $rule = New-Object System.Security.AccessControl.RegistryAccessRule ($ParentACL.Owner,'SetValue','Deny')
                    $null = $acl.RemoveAccessRule($rule)
                    $null = $k.SetAccessControl($acl)
                    Write-Verbose -Message 'Removed anti-tampering protection'
                }
            }
            # 2. add a ftype
            $null = & (Get-Command "$($env:systemroot)\system32\reg.exe") @(
                'add',
                "HKCU\Software\Classes\$($ftypeName)\shell\open\command"
                '/ve','/d',"$('\"{0}\" \"%1\"'-f $($exec))",
                '/f','/reg:64'
            )
            Write-Verbose -Message "Adding command under HKCU\Software\Classes\$($ftypeName)\shell\open\command"
            # 3. Update user file association

            # Reg2CI (c) 2019 by Roger Zander
            $eap = "SilentlyContinue"
            Remove-Item -LiteralPath ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\OpenWithList" -f $ext) -Force
            if((Test-Path -LiteralPath ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\OpenWithList" -f $ext)) -ne $true) { 
                New-Item ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\OpenWithList" -f $ext) -Force -ErrorAction $eap | Out-Null
            }
            Remove-Item -LiteralPath ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\OpenWithProgids" -f $ext) -Force
            if((Test-Path -LiteralPath ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\OpenWithProgids" -f $ext)) -ne $true) { 
                New-Item ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\OpenWithProgids" -f $ext) -Force -ErrorAction $eap | Out-Null
            }
            if((Test-Path -LiteralPath ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\UserChoice" -f $ext)) -ne $true) {
                New-Item ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\UserChoice" -f $ext) -Force -ErrorAction $eap | Out-Null
            }
            New-ItemProperty -LiteralPath ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\OpenWithList" -f $ext) -Name "MRUList" -Value "a" -PropertyType String -Force -ErrorAction $eap | Out-Null
            New-ItemProperty -LiteralPath ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\OpenWithList" -f $ext) -Name "a" -Value ("{0}" -f (Get-Item -Path $exec | Select-Object -ExpandProperty Name)) -PropertyType String -Force -ErrorAction $eap | Out-Null
            New-ItemProperty -LiteralPath ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\OpenWithProgids" -f $ext) -Name $ftypeName -Value (New-Object Byte[] 0) -PropertyType None -Force -ErrorAction $eap | Out-Null
            Remove-ItemProperty -LiteralPath ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\UserChoice" -f $ext) -Name "Hash" -Force -ErrorAction $eap
            Remove-ItemProperty -LiteralPath ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\UserChoice" -f $ext) -Name "Progid" -Force  -ErrorAction $eap
        }
    }

    Function New-Shortcut {
        Param(
            [Parameter(Mandatory=$true)]
            [string]$Target,
            [Parameter(Mandatory=$false)]
            [string]$TargetArguments,
            [Parameter(Mandatory=$true)]
            [string]$ShortcutName
        )
        $Path = Join-Path -Path ([System.Environment]::GetFolderPath("Desktop")) -ChildPath $ShortcutName
        switch ($ShortcutName.EndsWith(".lnk")) {
            $false {
                $ShortcutName = $ShortcutName + ".lnk"
            }
        }
        switch (Test-Path -LiteralPath $Path) {
            $true {
                Write-Warning ("Shortcut already exists: {0}" -f (Split-Path $Path -Leaf))
            }
            $false {
                $WshShell = New-Object -comObject WScript.Shell
                $Shortcut = $WshShell.CreateShortcut($Path)
                $Shortcut.TargetPath = $Target
                If ($null -ne $TargetArguments) {
                    $Shortcut.Arguments = $TargetArguments
                }
                $Shortcut.Save()
            }
        }
    }

    switch (Test-Path -LiteralPath ("{0}\CCM" -f $env:windir)) {
        $true {
            $client = $true
        }
        $false {
            $client = $false
        }
    }
    try {
        switch ($true) {
            (Test-Path -LiteralPath ("{0}\CCM\CMTrace.exe" -f $env:windir)) {
                $CMTracePath = ("{0}\CCM\CMTrace.exe" -f $env:windir)
                break
            }
            (Test-Path -LiteralPath ("{0}\CMTrace.exe" -f [System.Environment]::GetFolderPath("MyDocuments"))) {
                $CMTracePath = ("{0}\CMTrace.exe" -f [System.Environment]::GetFolderPath("MyDocuments"))
                break
            }
            default {
                $CMTracePath = ("{0}\CMTrace.exe" -f [System.Environment]::GetFolderPath("MyDocuments"))
                $Hash = "81F725E8A89A87A1D4A4487905381EE173C2AF54511A47E659ABC2D56DFFB6F9"
                Invoke-WebRequest -Uri "https://www.cookadam.co.uk/scripts/CMTrace.exe" -OutFile $CMTracePath -ErrorAction Stop
                If ((Get-FileHash -LiteralPath $CMTracePath -Algorithm SHA256 | Select-Object -ExpandProperty Hash) -ne $Hash) {
                    Throw "Hash mismatch from download"
                }
            }
        }

        Add-FileAssociation -Extension ".log" -TargetExecutable $CMTracePath
        Add-FileAssociation -Extension ".lo_" -TargetExecutable $CMTracePath
        
        switch ($client) {  
            $true {
                New-Shortcut -Target ("{0}\System32\control.exe" -f $env:windir) -TargetArguments "smscfgrc" -ShortcutName "smscfgrc.lnk"
                New-Shortcut -Target ("{0}\Programs\Microsoft System Center\Configuration Manager\Software Center.lnk" -f [Environment]::GetFolderPath("CommonStartMenu")) -ShortcutName "Software Center.lnk"
                New-Shortcut -Target ("{0}\CCM" -f $env:windir) -ShortcutName "CCM.lnk"
                New-Shortcut -Target ("{0}\ccmsetup" -f $env:windir) -ShortcutName "ccmsetup.lnk"
                New-Shortcut -Target ("{0}\ccmcache" -f $env:windir) -ShortcutName "ccmcache.lnk"
            }
            $false {
                # tbc
            }
        }

        switch($null -ne $ENV:SMS_ADMIN_UI_PATH) {
            $true {
                New-Shortcut -Target ("{0}\Programs\Microsoft System Center\Configuration Manager\Configuration Manager Console.lnk" -f [Environment]::GetFolderPath("CommonStartMenu")) -ShortcutName "Configuration Manager Console.lnk"
            }
        }

    }
    catch {
        Write-Host "Error: " -ForegroundColor Red -NoNewline
        Write-Host $_.Exception.Message -NoNewline
        Write-Host (" (line {0})" -f $_.InvocationInfo.ScriptLineNumber)
    }
}

Function Search-History {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$String
    )
    Get-Content (Get-PSReadlineOption).HistorySavePath | Where-Object { $_ -like ("*{0}*" -f $string) -and $_ -notlike "Search-History*" } | Select-Object -Unique
}

Function Get-PSTools {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Function Unzip {
        Param(
            [string]$zipfile, 
            [string]$outpath
        )
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
    }
    try {
        $Path = (Join-Path -Path $env:LOCALAPPDATA -ChildPath "Microsoft\WindowsApps")
        (New-Object System.Net.WebClient).DownloadFile("https://download.sysinternals.com/files/PSTools.zip", (Join-Path -Path $Path -ChildPath "PSTools.zip"))
        Unzip -zipfile (Join-Path -Path $Path -ChildPath "PSTools.zip") -outpath $Path
        Rename-Item -LiteralPath (Join-Path -Path $Path -ChildPath "PSexec.exe") -NewName (Join-Path -Path $Path -ChildPath "PSexec_.exe") -ErrorAction Stop
    }
    catch {
        Write-Host "Error: " -ForegroundColor Red -NoNewline
        Write-Host $_.Exception.Message -NoNewline
        Write-Host (" (line {0})" -f $_.InvocationInfo.ScriptLineNumber)
    }
}

function Add-FunctionToProfile {
    <#
.SYNOPSIS
    Add a function to your profile
.DESCRIPTION
    This function is used to append a function to your PowerShell profile. You provide a function name, and if it has a script block
    then it will be appended to your PowerShell profile with the function name provided.
.PARAMETER FunctionToAdd
    The name of the function(s) you wish to add to your profile. You can provide multiple. 
.EXAMPLE
    PS C:\> Add-FunctionToProfile -FunctionToAdd 'Get-CMClientMaintenanceWindow'
.NOTES
    If a function doesn't have a script block, then it cannot be added to your profile
    Cody is the man: https://github.com/CodyMathis123/CM-Ramblings/blob/master/Add-FunctionToProfile.ps1
#>
    param(
        [Parameter(Mandatory = $True)]
        [string[]]$FunctionToAdd
    )
    foreach ($FunctionName in $FunctionToAdd) {
        try {
            $Function = Get-Command -Name $FunctionName -CommandType Function -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to find the specified function [Name = '$FunctionName']"
            continue
        }    
        $ScriptBlock = $Function | Select-Object -ExpandProperty ScriptBlock
        if ($null -ne $ScriptBlock) {
            $FuncToAdd = [string]::Format("`r`nfunction {0} {{{1}}}", $FunctionName, $ScriptBlock)
            ($FuncToAdd -split "`n") | Add-Content -Path $PROFILE 
        }
        else {
            Write-Error "Function $FunctionName does not have a Script Block and cannot be added to your profile."
        }
    }
}



Function Enable-RemoteRegistry {
    # if disabled, set to manual and start
}

Function Shamefully-ResetBITS {
    Param( 
        [Parameter()]
        [String[]]$ComputerName,
        [Parameter()]
        [PSCredential]$Credential
    )
    $InvokeCommandSplat = @{
        ScriptBlock = {
            $Result = @{
                ComputerName = $env:COMPUTERNAME
            }
            try {
                Get-Service -Name "bits" -ErrorAction "Stop" | Stop-Service -Force -ErrorAction "Stop" -WarningAction "SilentlyContinue"
                Start-Process "ipconfig" -ArgumentList "/flushdns" -ErrorAction "Stop"
                $path = "{0}\Application Data\Microsoft\Network\Downloader" -f $env:ProgramData
                Move-Item -LiteralPath $path\qmgr0.dat -Destination $path\qmgr0.dat.bak -Force -ErrorAction "Stop"
                Move-Item -LiteralPath $path\qmgr1.dat -Destination $path\qmgr1.dat.bak -Force -ErrorAction "Stop"
                Get-Service -Name "bits" -ErrorAction "Stop" | Start-Service -ErrorAction "Stop"
                $Result["Result"] = "Success"
            }
            catch {
                $Result["Result"] = $error[0].Exception.Message
            }
            [PSCustomObject]$Result
        }
    }
    if ($PSBoundParameters.ContainsKey("Credential")) {
        $InvokeCommandSplat["Credential"] = $Credential
    }
    $Jobs = ForEach ($Computer in $ComputerName) {
        if ($PSBoundParameters.ContainsKey("ComputerName")) {
            $InvokeCommandSplat["ComputerName"] = $Computer
        }
        Invoke-Command @InvokeCommandSplat -AsJob
    }
    while (Get-Job -State "Running") {
        $TotalJobs = $Jobs.count
        $NotRunning = $Jobs | Where-Object { $_.State -ne "Running" }
        $Running = $Jobs | Where-Object { $_.State -eq "Running" }
        Write-Progress -Activity "Waiting on results" -Status "$($TotalJobs-$NotRunning.count) Jobs Remaining: $($Running.Location)" -PercentComplete ($NotRunning.count/(0.1+$TotalJobs) * 100)
        Start-Sleep -Seconds 2
    }
    Get-Job | Receive-Job
    Get-Job | Remove-Job    
}

Function Shamefully-ClearSoftwareDistributionFolder {
    Param( 
        [Parameter()]
        [String[]]$ComputerName,
        [Parameter()]
        [PSCredential]$Credential
    )
    $InvokeCommandSplat = @{
        ScriptBlock = {
            $Result = @{
                ComputerName = $env:COMPUTERNAME
            }
            try {
                Get-Service -Name "bits","Windows Update" -ErrorAction "Stop" | Stop-Service -Force -ErrorAction "Stop"
                Start-Process "ipconfig" -ArgumentList "/flushdns" -ErrorAction "Stop"
                $path = "{0}\Application Data\Microsoft\Network\Downloader" -f $env:ProgramData
                Move-Item -LiteralPath $path\qmgr0.dat -Destination $path\qmgr0.dat.bak -Force -ErrorAction "Stop"
                Move-Item -LiteralPath $path\qmgr1.dat -Destination $path\qmgr1.dat.bak -Force -ErrorAction "Stop"
                $path = "{0}\SoftwareDistribution" -f $env:windir
                Move-Item -LiteralPath $path -Destination ("{0}.old" -f $path) -Force -ErrorAction "Stop"
                Get-Service -Name "bits","Windows Update" -ErrorAction "Stop" | Start-Service -ErrorAction "Stop"
                $Result["Result"] = "Success"
            }
            catch {
                $Result["Result"] = $error[0].Exception.Message
            }
            [PSCustomObject]$Result
        }
    }
    if ($PSBoundParameters.ContainsKey("Credential")) {
        $InvokeCommandSplat["Credential"] = $Credential
    }
    $Jobs = ForEach ($Computer in $ComputerName) {
        if ($PSBoundParameters.ContainsKey("ComputerName")) {
            $InvokeCommandSplat["ComputerName"] = $Computer
        }
        Invoke-Command @InvokeCommandSplat -AsJob
    }
    while (Get-Job -State "Running") {
        $TotalJobs = $Jobs.count
        $NotRunning = $Jobs | Where-Object { $_.State -ne "Running" }
        $Running = $Jobs | Where-Object { $_.State -eq "Running" }
        Write-Progress -Activity "Waiting on results" -Status "$($TotalJobs-$NotRunning.count) Jobs Remaining: $($Running.Location)" -PercentComplete ($NotRunning.count/(0.1+$TotalJobs) * 100)
        Start-Sleep -Seconds 2
    }
    Get-Job | Receive-Job
    Get-Job | Remove-Job  
    
}

Function New-RebootScheduledTask {
    Param(
        [Parameter()]
        [String]$ComputerName,
        [Parameter(Mandatory)]
        [Datetime]$Time,
        [Parameter(Mandatory)]
        [String]$Description,
        [Parameter()]
        [String]$TaskName = "Itergy - Reboot",
        [Parameter()]
        [String]$TaskPath = "\",
        [Parameter()]
        [PSCredential]$Credential,
        [Parameter()]
        [Switch]$Force
    )

    $GetScheduledTaskSplat = @{
        TaskName = $TaskName
        TaskPath = $TaskPath
        ErrorAction = "SilentlyContinue"
    }

    if ($PSBoundParameters.ContainsKey("ComputerName")) {
        $NewCimSession = @{
            ComputerName = $ComputerName
            ErrorAction = "Stop"
        }
        if ($PSBoundParameters.ContainsKey("Credential")) {
            $NewCimSession["Credential"] = $Credential
        }
        $Session = New-CimSession @NewCimSession
        $GetScheduledTaskSplat["CimSession"] = $Session
    }

    if (Get-ScheduledTask @GetScheduledTaskSplat) {
        if ($Force.IsPresent) {
            $UnregisterScheduledTaskSplat = @{
                TaskName = $TaskName
                TaskPath = $TaskPath
                Confirm = $false
                ErrorAction = "Stop"
            } 
            if ($PSBoundParameters.ContainsKey("ComputerName")) {
                $UnregisterScheduledTaskSplat["CimSession"] = $Session
            }
            Unregister-ScheduledTask @UnregisterScheduledTaskSplat
        }
        else {
            Write-Warning "Scheduled task already exists, use -Force to recreate"
            return
        }
    }

    $Description = "{0} - created by {1} on {2}" -f $Description, $env:USERNAME, (Get-Date)

    $Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NonInteractive -NoLogo -NoProfile -Command 'Restart-Computer -Force'"
    $Trigger = New-ScheduledTaskTrigger -Once -At $Time
    $Settings = New-ScheduledTaskSettingsSet
    $Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Settings $Settings -Description $Description
    Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -InputObject $Task -User "System" -CimSession $Session
}

Function Get-Dns {
    Param( 
        [Parameter()]
        [String[]]$ComputerName,
        [Parameter(Mandatory)]
        [String]$FirstOctet,
        [Parameter()]
        [PSCredential]$Credential
    )
    $InvokeCommandSplat = @{
        ScriptBlock = {
            $InterfaceIndex = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress.StartsWith($FirstOctet) } | Select-Object -ExpandProperty InterfaceIndex
            [PSCustomObject]@{
                ComputerName = $env:COMPUTERNAME
                DNSAddresses = [String]::Join(", ", (Get-DnsClientServerAddress -InterfaceIndex $InterfaceIndex -AddressFamily IPv4).ServerAddresses)
            }
        }
    }
    if ($PSBoundParameters.ContainsKey("Credential")) {
        $InvokeCommandSplat["Credential"] = $Credential
    }
    $Jobs = ForEach ($Computer in $ComputerName) {
        if ($PSBoundParameters.ContainsKey("ComputerName")) {
            $InvokeCommandSplat["ComputerName"] = $Computer
        }
        Invoke-Command @InvokeCommandSplat -AsJob
    }
    while (Get-Job -State "Running") {
        $TotalJobs = $Jobs.count
        $NotRunning = $Jobs | Where-Object { $_.State -ne "Running" }
        $Running = $Jobs | Where-Object { $_.State -eq "Running" }
        Write-Progress -Activity "Waiting on results" -Status "$($TotalJobs-$NotRunning.count) Jobs Remaining: $($Running.Location)" -PercentComplete ($NotRunning.count/(0.1+$TotalJobs) * 100)
        Start-Sleep -Seconds 2
    }
    Get-Job | Receive-Job
    Get-Job | Remove-Job    
}

Function WmiExec {
    <#        
        .SYNOPSIS
        Execute command remotely and capture output, using only WMI.
        Copyright (c) Noxigen LLC. All rights reserved.
        Licensed under GNU GPLv3.

        .DESCRIPTION
        This is proof of concept code. Use at your own risk!
        
        Execute command remotely and capture output, using only WMI.
        Does not reply on PowerShell Remoting, WinRM, PsExec or anything
        else outside of WMI connectivity.
        
        .LINK
        https://github.com/OneScripter/WmiExec
        
        .EXAMPLE
        PS C:\> .\WmiExec.ps1 -ComputerName SFWEB01 -Command "gci c:\; hostname"

        .NOTES
        ========================================================================
            NAME:		WmiExec.ps1
            
            AUTHOR:	Jay Adams, Noxigen LLC
                        
            DATE:		6/11/2019
            
            Create secure GUIs for PowerShell with System Frontier.
            https://systemfrontier.com/powershell
        ==========================================================================
    #>
    Param(
        [string]$ComputerName,
        [Parameter(ValueFromPipeline=$true)]
        [string]$Command
    )

    function CreateScriptInstance([string]$ComputerName)
    {
        # Check to see if our custom WMI class already exists
        $classCheck = Get-WmiObject -Class Noxigen_WmiExec -ComputerName $ComputerName -List -Namespace "root\cimv2"
        
        if ($classCheck -eq $null)
        {
            # Create a custom WMI class to store data about the command, including the output.
            Write-Host "Creating WMI class..."
            $newClass = New-Object System.Management.ManagementClass("\\$ComputerName\root\cimv2",[string]::Empty,$null)
            $newClass["__CLASS"] = "Noxigen_WmiExec"
            $newClass.Qualifiers.Add("Static",$true)
            $newClass.Properties.Add("CommandId",[System.Management.CimType]::String,$false)
            $newClass.Properties["CommandId"].Qualifiers.Add("Key",$true)
            $newClass.Properties.Add("CommandOutput",[System.Management.CimType]::String,$false)
            $newClass.Put() | Out-Null
        }
        
        # Create a new instance of the custom class so we can reference it locally and remotely using this key
        $wmiInstance = Set-WmiInstance -Class Noxigen_WmiExec -ComputerName $ComputerName
        $wmiInstance.GetType() | Out-Null
        $commandId = ($wmiInstance | Select-Object -Property CommandId -ExpandProperty CommandId)
        $wmiInstance.Dispose()
        
        # Return the GUID for this instance
        return $CommandId
    }

    function GetScriptOutput([string]$ComputerName, [string]$CommandId)
    {
        $wmiInstance = Get-WmiObject -Class Noxigen_WmiExec -ComputerName $ComputerName -Filter "CommandId = '$CommandId'"
        $result = ($wmiInstance | Select-Object CommandOutput -ExpandProperty CommandOutput)
        $wmiInstance | Remove-WmiObject
        return $result
    }

    function ExecCommand([string]$ComputerName, [string]$Command)
    {
        #Pass the entire remote command as a base64 encoded string to powershell.exe
        $commandLine = "powershell.exe -NoLogo -NonInteractive -ExecutionPolicy Unrestricted -WindowStyle Hidden -EncodedCommand " + $Command
        $process = Invoke-WmiMethod -ComputerName $ComputerName -Class Win32_Process -Name Create -ArgumentList $commandLine
        
        if ($process.ReturnValue -eq 0)
        {
            $started = Get-Date
            
            Do
            {
                if ($started.AddMinutes(2) -lt (Get-Date))
                {
                    Write-Host "PID: $($process.ProcessId) - Response took too long."
                    break
                }
                
                # TODO: Add timeout
                $watcher = Get-WmiObject -ComputerName $ComputerName -Class Win32_Process -Filter "ProcessId = $($process.ProcessId)"
                
                Write-Host "PID: $($process.ProcessId) - Waiting for remote command to finish..."
                
                Start-Sleep -Seconds 1
            }
            While ($watcher -ne $null)
            
            # Once the remote process is done, retrieve the output
            $scriptOutput = GetScriptOutput $ComputerName $scriptCommandId
            
            return $scriptOutput
        }
    }

    function Main()
    {
        $commandString = $Command
        
        # The GUID from our custom WMI class. Used to get only results for this command.
        $scriptCommandId = CreateScriptInstance $ComputerName
        
        if ($scriptCommandId -eq $null)
        {
            Write-Error "Error creating remote instance."
            exit
        }
        
        # Meanwhile, on the remote machine...
        # 1. Execute the command and store the output as a string
        # 2. Get a reference to our current custom WMI class instance and store the output there!
            
        $encodedCommand = "`$result = Invoke-Command -ScriptBlock {$commandString} | Out-String; Get-WmiObject -Class Noxigen_WmiExec -Filter `"CommandId = '$scriptCommandId'`" | Set-WmiInstance -Arguments `@{CommandOutput = `$result} | Out-Null"
        
        $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($encodedCommand))
        
        Write-Host "Running the below command on: $ComputerName..."
        Write-Host $commandString
        
        $result = ExecCommand $ComputerName $encodedCommand
        
        Write-Host "Result..."
        Write-Output $result
    }

    Main

}

<#
This is no longer beneificial for me but keeping it as an example.
Function Start-SetupDiag {
    param (
        # Parameter help description
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]
        $ComputerName
    )
    'New-Item -ItemType Directory -Path $env:SystemDrive\SetupDiag' | WmiExec -ComputerName $ComputerName
    'Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=870142" -OutFile $env:SystemDrive\SetupDiag\SetupDiag.exe' | WmiExec -ComputerName $ComputerName
    '$path = "{0}\SetupDiag" -f $env:SystemDrive; Start-Process -FilePath $path\SetupDiag.exe -ArgumentList @("/Output:$path\Results.log") -Wait' | WmiExec -ComputerName $ComputerName
    '$path = "{0}\SetupDiag" -f $env:SystemDrive; Get-Content -Path $path\results.log' | WmiExec -ComputerName $ComputerName
}
#>

Function Start-SetupDiag {
    param (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [Alias('Computer', 'PSComputerName', 'Name', 'HostName')]
        [String[]]$ComputerName,
        [Parameter(Mandatory=$false)]
        [PSCredential]$Credential
    )

    $InvokeCommandSplat = @{
        ComputerName    = $ComputerName
        ScriptBlock     = {
            New-Item -ItemType Directory -Path $env:SystemDrive\SetupDiag
            Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=870142" -OutFile $env:SystemDrive\SetupDiag\SetupDiag.exe
            $path = "{0}\SetupDiag" -f $env:SystemDrive; Start-Process -FilePath $path\SetupDiag.exe -ArgumentList @("/Output:$path\Results.log") -Wait
            $path = "{0}\SetupDiag" -f $env:SystemDrive; Get-Content -Path $path\results.log
        }
    }

    if ($PSBoundParameters.ContainsKey('Credential')) {
        $InvokeCommandSplat.Add('Credential', $Credential)
    }

    Invoke-Command @InvokeCommandSplat
}

Function Connect-CMDrive {
    param(
        # SMS provider or site server
        [Parameter(Mandatory=$false, Position = 0)]
        [ValidateScript({
            If(!(Test-Connection -ComputerName $_ -Count 1 -ErrorAction SilentlyContinue)) {
                throw "Host `"$($_)`" is unreachable"
            } Else {
                return $true
            }
        })]
        [string]
        $Server,
        [Parameter(Mandatory=$false, Position = 1)]
        [string]
        $SiteCode,
        [Parameter(Mandatory=$false, Position = 2)]
        [string]
        $Path = (Get-Location | Select-Object -ExpandProperty Path)
    )
    if ([string]::IsNullOrEmpty($Server)) {
        try {
            $Server = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\ConfigMgr10\AdminUI\Connection" -ErrorAction Stop | Select-Object -ExpandProperty Server
        }
        catch [System.Management.Automation.ItemNotFoundException] {
            throw "Console must be installed. If it is installed, then fix your code but for now specify -Server"
        }
    }
    if ([string]::IsNullOrEmpty($SiteCode)) {
        try {
            $SiteCode = Get-WmiObject -Class "SMS_ProviderLocation" -Name "ROOT\SMS" -ComputerName $Server -ErrorAction Stop | Select-Object -ExpandProperty SiteCode
        }
        catch {
            switch -regex ($_.Exception.Message) {
                "Invalid namespace" {
                    throw ("No SMS provider installed on {0}" -f $Server)
                }
                default {
                    throw "Could not determine SiteCode, please pass -SiteCode"
                }
            }
        }
    }

    # Import the ConfigurationManager.psd1 module 
    If((Get-Module ConfigurationManager) -eq $null) {
        try {
            Import-Module ("{0}\..\ConfigurationManager.psd1" -f $ENV:SMS_ADMIN_UI_PATH)
        }
        catch {
            throw ("Failed to import ConfigMgr module: {0}" -f $_.Exception.Message)
        }
    }
    try {
        # Connect to the site's drive if it is not already present
        If((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
            New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $Server -ErrorAction Stop | Out-Null
        }
        # Set the current location to be the site code.
        Set-Location ("{0}:\" -f $SiteCode) -ErrorAction Stop

        # Verify given sitecode
        If((Get-CMSite -SiteCode $SiteCode | Select-Object -ExpandProperty SiteCode) -ne $SiteCode) { throw }

    } 
    catch {
        If((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -ne $null) {
            Set-Location $Path
            Remove-PSDrive -Name $SiteCode -Force
        }
        throw ("Failed to create New-PSDrive with site code `"{0}`" and server `"{1}`"" -f $SiteCode, $Server)
    }
}

function Get-Secure {
    <#
    .SYNOPSIS
        Get a stored credential.
    .DESCRIPTION
        Get a stored credential.
        https://github.com/indented-automation/Indented.Profile/blob/master/Indented.Profile/public/Get-Secure.ps1
    #>

    [CmdletBinding(DefaultParameterSetName = 'Get')]
    param (
        # The name which identifies a credential.
        [Parameter(Mandatory, Position = 1, ValueFromPipeline, ParameterSetName = 'Get')]
        [String]$Name,

        # List all available credentials.
        [Parameter(Mandatory, ParameterSetName = 'List')]
        [Switch]$List,

        # Do not copy the password to the clipboard.
        [Switch]$Clipboard,

        # Store the password in an environment variable instead of returning a credential.
        [Switch]$AsEnvironmentVariable
    )

    begin {
        if ($List) {
            Get-ChildItem $home\Documents\Keys | Select-Object @(
                @{n='Name';e={ $_.BaseName }},
                @{n='Created';e={ $_.CreationTime }}
            )
        }
    }

    process {
        if ($pscmdlet.ParameterSetName -eq 'Get') {
            $path = '{0}\Documents\Keys\{1}.xml' -f $home, $Name
            if (Test-Path $path) {
                $credential = Import-CliXml ('{0}\Documents\Keys\{1}.xml' -f $home, $Name)
                if ($AsEnvironmentVariable) {
                    Set-Item env:$Name -Value $credential.GetNetworkCredential().Password
                } else {
                    if ($Clipboard) {
                        $credential.GetNetworkCredential().Password | Set-Clipboard
                    }
                    $credential
                }
            }
        }
    }
}

function Set-Secure {
    <#
    .SYNOPSIS
        Store a credential.
    .DESCRIPTION
        Store a credential in an xml file created
        https://github.com/indented-automation/Indented.Profile/blob/master/Indented.Profile/public/Set-Secure.ps1
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The name of the credential to set.
        [Parameter(Mandatory, Position = 1)]
        [String]$Name
    )

    $path = '{0}\Documents\Keys\{1}.xml' -f $home, $Name
    $folder = Split-Path -Path $path -Parent
    if (Test-Path $path) {
        $credential = Get-Credential (Get-Secure $Name).Username
    } else {
        if (-not(Test-Path $folder)) {
            New-Item -Path $folder -ItemType "Directory" -ErrorAction Stop
        }
        $credential = Get-Credential
        if ($null -eq $credential) { return }
    }
    $credential | Export-CliXml $path
}

Function New-ModuleDirStructure {
    <#
    .NOTES
        http://ramblingcookiemonster.github.io/Building-A-PowerShell-Module/
    #>
    Param (
        [Parameter(Mandatory)]
        [String]$Path,
        [Parameter(Mandatory)]
        [String]$ModuleName,
        [Parameter(Mandatory)]
        [String]$Author,
        [Parameter(Mandatory)]
        [String]$Description,
        [Parameter()]
        [String]$PowerShellVersion = 5.1
    )

    # Create the module and private function directories
    New-Item -Path $Path\$ModuleName -ItemType Directory -Force
    New-Item -Path $Path\$ModuleName\Private -ItemType Directory -Force
    New-Item -Path $Path\$ModuleName\Public -ItemType Directory -Force
    New-Item -Path $Path\$ModuleName\en-US -ItemType Directory -Force # For about_Help files
    #New-Item -Path $Path\Tests -ItemType Directory -Force

    #Create the module and related files
    New-Item "$Path\$ModuleName\$ModuleName.psm1" -ItemType File -Force
    #New-Item "$Path\$ModuleName\$ModuleName.Format.ps1xml" -ItemType File -Force
    New-Item "$Path\$ModuleName\en-US\about_$ModuleName.help.txt" -ItemType File -Force
    #New-Item "$Path\Tests\$ModuleName.Tests.ps1" -ItemType File -Force
    $NewModuleManifestSplat = @{
        Path                = Join-Path -Path $Path -ChildPath $ModuleName | Join-Path -ChildPath "$ModuleName.psd1"
        RootModule          = $ModuleName.psm1
        Description         = $Description
        PowerShellVersion   = $PowerShellVersion
        Author              = $Author
        # FormatsToProcess    = "$ModuleName.Format.ps1xml"
    }
    New-ModuleManifest @NewModuleManifestSplat

    # Copy the public/exported functions into the public folder, private functions into private folder
}

function ConvertTo-HexString {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$String
    )
    begin { }
    process {
        foreach ($char in $String.ToCharArray()) {
            [System.String]::Format("{0:X}", [System.Convert]::ToUInt32($char))
        }
    }
}

function ConvertTo-ByteArrayHex {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$String
    )
    begin { }
    process {
        [Byte[]]$bytes = for ($i = 0; $i -lt $String.Length; $i += 2) {
            '0x{0}{1}' -f $String[$i], $String[$i + 1]
        }
        $bytes
    }
}

function ConvertTo-ByteArrayString {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$String
    )
    begin { }
    process {
        [System.Text.Encoding]::UTF8.GetBytes($String)
    }
}

Function Get-MyCommands {
    Get-Content -Path $profile.CurrentUserAllHosts | Select-String -Pattern "^function.+" | ForEach-Object {
        [Regex]::Matches($_, "^function ([a-z.-]+)","IgnoreCase").Groups[1].Value
    } | Where-Object { $_ -ine "prompt" } | Sort-Object
}

Set-Alias -Name "Get-MyFunctions" -Value "Get-MyCommands"
Set-Alias -Name "setmeup" -Value "Set-CMShortcuts"
Set-Alias -Name "l" -Value "Get-ChildItem"

Set-Location ([Environment]::GetFolderPath("MyDocuments"))
