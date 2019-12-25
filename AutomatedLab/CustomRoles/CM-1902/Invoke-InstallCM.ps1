<#
    .SYNOPSIS
    Install a functional SCCM Primary Site using the Automated-Lab tookit with SCCM being installed using the "CustomRoles" approach
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
    To do :
        - Do not checks if stuff has already been done before kicking off e.g. ADK install etc
        - Offer target site version
        - Set CMTrace as default log viewer, or OneTrace, or register them with .log and .lo_ so user is prompted to choose
        - Shortcuts
        - Grab WMI explorer
        - Notifications when complete
        - Remove lab command jobs for site install pre-reqs
        - Standardise on how to throw terminator errors and/or just using "exit" (e.g. within New-LoopAction)
        - I think some New-LoopAction need to return variable used in scriptblock
        - Update console post update install
        - Figure out disk label issue
#>

param(

    [Parameter(Mandatory)]
    [string]$ComputerName,

    [Parameter(Mandatory)]
    [string]$SccmBinariesDirectory,

    [Parameter(Mandatory)]
    [string]$SccmPreReqsDirectory,

    [Parameter(Mandatory)]
    [string]$SccmSiteCode,

    [Parameter(Mandatory)]
    [string]$SccmSiteName,

    [Parameter(Mandatory)]
    [string]$SccmProductId,
        
    [Parameter(Mandatory)]
    [string]$SqlServerName
)

#region Functions
function New-LoopAction {
    <#
    .SYNOPSIS
        Function to loop a specified scriptblock until certain conditions are met
    .DESCRIPTION
        This function is a wrapper for a ForLoop or a DoUntil loop. This allows you to specify if you want to exit based on a timeout, or a number of iterations.
            Additionally, you can specify an optional delay between loops, and the type of dealy (Minutes, Seconds). If needed, you can also perform an action based on
            whether the 'Exit Condition' was met or not. This is the IfTimeoutScript and IfSucceedScript. 
    .PARAMETER LoopTimeout
        A time interval integer which the loop should timeout after. This is for a DoUntil loop.
    .PARAMETER LoopTimeoutType
         Provides the time increment type for the LoopTimeout, defaulting to Seconds. ('Seconds', 'Minutes', 'Hours', 'Days')
    .PARAMETER LoopDelay
        An optional delay that will occur between each loop.
    .PARAMETER LoopDelayType
        Provides the time increment type for the LoopDelay between loops, defaulting to Seconds. ('Milliseconds', 'Seconds', 'Minutes')
    .PARAMETER Iterations
        Implies that a ForLoop is wanted. This will provide the maximum number of Iterations for the loop. [i.e. "for ($i = 0; $i -lt $Iterations; $i++)..."]
    .PARAMETER ScriptBlock
        A script block that will run inside the loop. Recommend encapsulating inside { } or providing a [scriptblock]
    .PARAMETER ExitCondition
        A script block that will act as the exit condition for the do-until loop. Will be evaluated each loop. Recommend encapsulating inside { } or providing a [scriptblock]
    .PARAMETER IfTimeoutScript
        A script block that will act as the script to run if the timeout occurs. Recommend encapsulating inside { } or providing a [scriptblock]
    .PARAMETER IfSucceedScript
        A script block that will act as the script to run if the exit condition is met. Recommend encapsulating inside { } or providing a [scriptblock]
    .EXAMPLE
        C:\PS> $newLoopActionSplat = @{
                    LoopTimeoutType = 'Seconds'
                    ScriptBlock = { 'Bacon' }
                    ExitCondition = { 'Bacon' -Eq 'eggs' }
                    IfTimeoutScript = { 'Breakfast'}
                    LoopDelayType = 'Seconds'
                    LoopDelay = 1
                    LoopTimeout = 10
                }
                New-LoopAction @newLoopActionSplat
                Bacon
                Bacon
                Bacon
                Bacon
                Bacon
                Bacon
                Bacon
                Bacon
                Bacon
                Bacon
                Bacon
                Breakfast
    .EXAMPLE
        C:\PS> $newLoopActionSplat = @{
                    ScriptBlock = { if($Test -eq $null){$Test = 0};$TEST++ }
                    ExitCondition = { $Test -eq 4 }
                    IfTimeoutScript = { 'Breakfast' }
                    IfSucceedScript = { 'Dinner'}
                    Iterations  = 5
                    LoopDelay = 1
                }
                New-LoopAction @newLoopActionSplat
                Dinner
        C:\PS> $newLoopActionSplat = @{
                    ScriptBlock = { if($Test -eq $null){$Test = 0};$TEST++ }
                    ExitCondition = { $Test -eq 6 }
                    IfTimeoutScript = { 'Breakfast' }
                    IfSucceedScript = { 'Dinner'}
                    Iterations  = 5
                    LoopDelay = 1
                }
                New-LoopAction @newLoopActionSplat
                Breakfast
    .NOTES
            Play with the conditions a bit. I've tried to provide some examples that demonstrate how the loops, timeouts, and scripts work!
            Author: @CodyMathis123
            Link: https://github.com/CodyMathis123/CM-Ramblings
    #>
    param
    (
        [parameter(Mandatory = $true, ParameterSetName = 'DoUntil')]
        [int32]$LoopTimeout,
        [parameter(Mandatory = $true, ParameterSetName = 'DoUntil')]
        [ValidateSet('Seconds', 'Minutes', 'Hours', 'Days')]
        [string]$LoopTimeoutType,
        [parameter(Mandatory = $true)]
        [int32]$LoopDelay,
        [parameter(Mandatory = $false, ParameterSetName = 'DoUntil')]
        [ValidateSet('Milliseconds', 'Seconds', 'Minutes')]
        [string]$LoopDelayType = 'Seconds',
        [parameter(Mandatory = $true, ParameterSetName = 'ForLoop')]
        [int32]$Iterations,
        [parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        [parameter(Mandatory = $true, ParameterSetName = 'DoUntil')]
        [parameter(Mandatory = $false, ParameterSetName = 'ForLoop')]
        [scriptblock]$ExitCondition,
        [parameter(Mandatory = $false)]
        [scriptblock]$IfTimeoutScript,
        [parameter(Mandatory = $false)]
        [scriptblock]$IfSucceedScript
    )
    begin {
        switch ($PSCmdlet.ParameterSetName) {
            'DoUntil' {
                $paramNewTimeSpan = @{
                    $LoopTimeoutType = $LoopTimeout
                }    
                $TimeSpan = New-TimeSpan @paramNewTimeSpan
                $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
                $FirstRunDone = $false        
            }
        }
    }
    process {
        switch ($PSCmdlet.ParameterSetName) {
            'DoUntil' {
                do {
                    switch ($FirstRunDone) {
                        $false {
                            $FirstRunDone = $true
                        }
                        Default {
                            $paramStartSleep = @{
                                $LoopDelayType = $LoopDelay
                            }
                            Start-Sleep @paramStartSleep
                        }
                    }
                    . $ScriptBlock
                }
                until ((. $ExitCondition) -or $StopWatch.Elapsed -ge $TimeSpan)
            }
            'ForLoop' {
                for ($i = 0; $i -lt $Iterations; $i++) {
                    switch ($FirstRunDone) {
                        $false {
                            $FirstRunDone = $true
                        }
                        Default {
                            $paramStartSleep = @{
                                $LoopDelayType = $LoopDelay
                            }
                            Start-Sleep @paramStartSleep
                        }
                    }
                    . $ScriptBlock
                    if ($PSBoundParameters.ContainsKey('ExitCondition')) {
                        if (. $ExitCondition) {
                            break
                        }
                    }
                }
            }
        }
    }
    end {
        switch ($PSCmdlet.ParameterSetName) {
            'DoUntil' {
                if ((-not (. $ExitCondition)) -and $StopWatch.Elapsed -ge $TimeSpan -and $PSBoundParameters.ContainsKey('IfTimeoutScript')) {
                    . $IfTimeoutScript
                }
                if ((. $ExitCondition) -and $PSBoundParameters.ContainsKey('IfSucceedScript')) {
                    . $IfSucceedScript
                }
                $StopWatch.Reset()
            }
            'ForLoop' {
                if ($PSBoundParameters.ContainsKey('ExitCondition')) {
                    if ((-not (. $ExitCondition)) -and $i -ge $Iterations -and $PSBoundParameters.ContainsKey('IfTimeoutScript')) {
                        . $IfTimeoutScript
                    }
                    elseif ((. $ExitCondition) -and $PSBoundParameters.ContainsKey('IfSucceedScript')) {
                        . $IfSucceedScript
                    }
                }
                else {
                    if ($i -ge $Iterations -and $PSBoundParameters.ContainsKey('IfTimeoutScript')) {
                        . $IfTimeoutScript
                    }
                    elseif ($i -lt $Iterations -and $PSBoundParameters.ContainsKey('IfSucceedScript')) {
                        . $IfSucceedScript
                    }
                }
            }
        }
    }
}

function Add-FileAssociation {
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
        Remove-Item -LiteralPath ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\OpenWithList" -f $ext) -ErrorAction "SilentlyContinue" -Force
        if((Test-Path -LiteralPath ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\OpenWithList" -f $ext)) -ne $true) { 
            New-Item ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\OpenWithList" -f $ext) -Force -ErrorAction "SilentlyContinue" | Out-Null
        }
        Remove-Item -LiteralPath ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\OpenWithProgids" -f $ext) -ErrorAction "SilentlyContinue" -Force
        if((Test-Path -LiteralPath ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\OpenWithProgids" -f $ext)) -ne $true) { 
            New-Item ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\OpenWithProgids" -f $ext) -Force -ErrorAction "SilentlyContinue" | Out-Null
        }
        if((Test-Path -LiteralPath ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\UserChoice" -f $ext)) -ne $true) {
            New-Item ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\UserChoice" -f $ext) -Force -ErrorAction "SilentlyContinue" | Out-Null
        }
        New-ItemProperty -LiteralPath ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\OpenWithList" -f $ext) -Name "MRUList" -Value "a" -PropertyType String -Force -ErrorAction "SilentlyContinue" | Out-Null
        New-ItemProperty -LiteralPath ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\OpenWithList" -f $ext) -Name "a" -Value ("{0}" -f (Get-Item -Path $exec | Select-Object -ExpandProperty Name)) -PropertyType String -Force -ErrorAction "SilentlyContinue" | Out-Null
        New-ItemProperty -LiteralPath ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\OpenWithProgids" -f $ext) -Name $ftypeName -Value (New-Object Byte[] 0) -PropertyType None -Force -ErrorAction "SilentlyContinue" | Out-Null
        Remove-ItemProperty -LiteralPath ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\UserChoice" -f $ext) -Name "Hash" -Force -ErrorAction "SilentlyContinue"
        Remove-ItemProperty -LiteralPath ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\{0}\UserChoice" -f $ext) -Name "Progid" -Force  -ErrorAction "SilentlyContinue"
    }
}

function New-Shortcut {
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

function Install-CMSite {
    param (
        [Parameter(Mandatory)]
        [string]$SccmServerName,

        [Parameter(Mandatory)]
        [string]$SccmBinariesDirectory,

        [Parameter(Mandatory)]
        [string]$SccmPreReqsDirectory,

        [Parameter(Mandatory)]
        [string]$SccmSiteCode,

        [Parameter(Mandatory)]
        [string]$SccmSiteName,

        [Parameter(Mandatory)]
        [string]$SccmProductId,
        
        [Parameter(Mandatory)]
        [string]$SqlServerName
    )

    $sccmServer = Get-LabVM -ComputerName $SccmServerName
    $sccmServerFqdn = $sccmServer.FQDN
    $sqlServer = Get-LabVM -Role SQLServer | Where-Object Name -eq $SqlServerName
    $sqlServerFqdn = $sqlServer.FQDN
    $DCServerName = Get-LabVM -Role RootDC | Where-Object { $_.DomainName -eq  $sccmServer.DomainName } | Select-Object -ExpandProperty Name
    
    if (-not $sqlServer) {
        Write-LogFunctionExitWithError -Message "The specified SQL Server '$SqlServerName' does not exist in the lab."
        return
    }

    $InstalledSite = Invoke-LabCommand -ActivityName "Checking if site is already installed" -ComputerName $SccmServerName -ScriptBlock {
        $Query = "SELECT * FROM SMS_Site WHERE SiteCode='{0}'" -f $SccmSiteCode
        try {
            Get-CimInstance -Namespace "ROOT/SMS/site_$($SccmSiteCode)" -Query $Query -ErrorAction Stop -ErrorVariable GetCimInstanceErr
        }
        catch {
            if ($GetCimInstanceErr.Message -notlike "*Invalid namespace*") {
                throw ("Could not query SMS_Site ({0})" -f $GetCimInstanceErr.Message)
            }
        }
    } -Variable (Get-Variable -Name SccmSiteCode) -PassThru

    if ($InstalledSite.SiteCode -eq $SccmSiteCode) {
        Write-ScreenInfo ("Site '{0}' already installed on '{1}', skipping installation" -f $SccmSiteCode, $SccmServerName) -Type "Warning"
        return
    }
    
    $downloadTargetFolder = "$labSources\SoftwarePackages"
    $VMInstallDirectory = "C:\Install"
    $VMSccmBinariesDirectory = Join-Path -Path $VMInstallDirectory -ChildPath (Split-Path -Leaf $SccmBinariesDirectory)
    $VMSccmPreReqsDirectory = Join-Path -Path $VMInstallDirectory -ChildPath (Split-Path -Leaf $SccmPreReqsDirectory)
    
    #Do Some quick checks before we get going    
    #Check for existance of ADK Installation Files
    if (-not (Test-Path -Path "$downloadTargetFolder\ADK")) {
        Write-LogFunctionExitWithError -Message "ADK Installation files not located at '$downloadTargetFolder\ADK'"
        return
    }

    if (-not (Test-Path -Path "$downloadTargetFolder\WinPE")) {
        Write-LogFunctionExitWithError -Message "WinPE Installation files not located at '$downloadTargetFolder\WinPE'"
        return
    }

    if (-not (Test-Path -Path $SccmBinariesDirectory)) {
        Write-LogFunctionExitWithError -Message "SCCM Installation files not located at '$($SccmBinariesDirectory)'"
        return
    }

    if (-not (Test-Path -Path $SccmPreReqsDirectory)) {
        Write-LogFunctionExitWithError -Message "SCCM PreRequisite files not located at '$($SccmPreReqsDirectory)'"
        return
    }

    #Bring all available disks online (this is to cater for the secondary drive)
    #For some reason, cant make the disk online and RW in the one command, need to perform two seperate actions
    Invoke-LabCommand -ActivityName 'Bring Disks Online' -ComputerName $SccmServerName -ScriptBlock {
        $dataVolume = Get-Disk | Where-Object -Property OperationalStatus -eq Offline
        $dataVolume | Set-Disk -IsOffline $false
        $dataVolume | Set-Disk -IsReadOnly $false
    }

    #Set NO_SMS_ON_DRIVE.SMS
    Invoke-LabCommand -ActivityName 'Creating NO_SMS_ON_DRIVE.SMS files' -ComputerName $SccmServerName -ScriptBlock {
        switch ($true) {
            (-not(Test-Path -LiteralPath "C:\NO_SMS_ON_DRIVE.SMS")) {
                try {
                    New-Item -Path "C:\" -Name "NO_SMS_ON_DRIVE.SMS" -ItemType "File" -ErrorAction Stop -ErrorVariable NewItemErr
                }
                catch {
                    throw ("Could not create NO_SMS_ON_DRIVE.SMS on C: ({0})" -f $NewItemErr.Message)
                }
            }
            (-not(Test-Path -LiteralPath "F:\NO_SMS_ON_DRIVE.SMS")) {
                try {
                    New-Item -Path "F:\" -Name "NO_SMS_ON_DRIVE.SMS" -ItemType "File" -ErrorAction Stop -ErrorVariable NewItemErr
                }
                catch {
                    throw ("Could not create NO_SMS_ON_DRIVE.SMS on F: ({0})" -f $NewItemErr.Message)
                }
            }
        }
    }
    
    #Copy the SCCM Binaries
    Copy-LabFileItem -Path $SccmBinariesDirectory -DestinationFolderPath $VMInstallDirectory -ComputerName $SccmServerName -Recurse
    #Copy the SCCM Prereqs (must have been previously downloaded)
    Copy-LabFileItem -Path $SccmPreReqsDirectory -DestinationFolderPath $VMInstallDirectory -ComputerName $SccmServerName -Recurse

    #Extend the AD Schema
    Write-ScreenInfo -Message "VMSccmBinariesDirectory variable is: $($VMSccmBinariesDirectory)"
    Invoke-LabCommand -ActivityName 'Extend AD Schema' -ComputerName $SccmServerName -ScriptBlock {
        $path = Join-Path -Path $VMSccmBinariesDirectory -ChildPath "SMSSETUP\BIN\X64\extadsch.exe"
        Start-Process $path -Wait -PassThru
    } -Variable (Get-Variable -Name VMSccmBinariesDirectory)

    #Need to execute this command on the Domain Controller, since it has the AD Powershell cmdlets available
    #Create the Necessary OU and permissions for the SCCM container in AD
    Invoke-LabCommand -ActivityName 'Configure SCCM Systems Management Container' -ComputerName $DCServerName -ScriptBlock {
        param  
        (
            [Parameter(Mandatory)]
            [string]$SCCMServerName
        )

        Import-Module ActiveDirectory
        # Figure out our domain
        $rootDomainNc = (Get-ADRootDSE).defaultNamingContext

        # Get or create the System Management container
        $ou = $null
        try
        {
            $ou = Get-ADObject "CN=System Management,CN=System,$rootDomainNc"
        }
        catch
        {   
            Write-Verbose "System Management container does not currently exist."
            $ou = New-ADObject -Type Container -name "System Management" -Path "CN=System,$rootDomainNc" -Passthru
        }

        # Get the current ACL for the OU
        $acl = Get-ACL -Path "ad:CN=System Management,CN=System,$rootDomainNc"

        # Get the computer's SID (we need to get the computer object, which is in the form <ServerName>$)
        $sccmComputer = Get-ADComputer "$SCCMServerName$"
        $sccmServerSId = [System.Security.Principal.SecurityIdentifier] $sccmComputer.SID

        $ActiveDirectoryRights = "GenericAll"
        $AccessControlType = "Allow"
        $Inherit = "SelfAndChildren"
        $nullGUID = [guid]'00000000-0000-0000-0000-000000000000'
 
        # Create a new access control entry to allow access to the OU
        $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $sccmServerSId, $ActiveDirectoryRights, $AccessControlType, $Inherit, $nullGUID
        
        # Add the ACE to the ACL, then set the ACL to save the changes
        $acl.AddAccessRule($ace)
        Set-ACL -AclObject $acl "ad:CN=System Management,CN=System,$rootDomainNc"

    } -ArgumentList $SccmServerName
   
    Write-ScreenInfo -Message "Copying ADK install files to server '$SccmServerName'" -TaskStart
    Copy-LabFileItem -Path "$downloadTargetFolder\ADK" -DestinationFolderPath $VMInstallDirectory -ComputerName $SccmServerName -Recurse
    Write-ScreenInfo -Message "Activity done" -TaskEnd
    
    Write-ScreenInfo -Message "Installing ADK on server '$SccmServerName'" -TaskStart
    $job = Install-LabSoftwarePackage -LocalPath $VMInstallDirectory\ADK\adksetup.exe -CommandLine "/norestart /q /ceip off /features OptionId.DeploymentTools OptionId.UserStateMigrationTool OptionId.ImagingAndConfigurationDesigner" -ComputerName $SccmServerName -NoDisplay -AsJob -PassThru
    Wait-LWLabJob -Job $job -NoDisplay
    Write-ScreenInfo -Message "Activity done" -TaskEnd

    Write-ScreenInfo -Message "Copying WinPE install files to '$SccmServerName'" -TaskStart
    Copy-LabFileItem -Path "$downloadTargetFolder\WinPE" -DestinationFolderPath $VMInstallDirectory -ComputerName $SccmServerName -Recurse
    Write-ScreenInfo -Message "Activity done" -TaskEnd

    Write-ScreenInfo -Message "Installing WinPE on '$SccmServerName'" -TaskStart
    $job = Install-LabSoftwarePackage -LocalPath $VMInstallDirectory\WinPE\adkwinpesetup.exe -CommandLine "/norestart /q /ceip off /features OptionId.WindowsPreinstallationEnvironment" -ComputerName $SccmServerName -NoDisplay -AsJob -PassThru
    Wait-LWLabJob -Job $job -NoDisplay
    Write-ScreenInfo -Message "Activity done" -TaskEnd

    Write-ScreenInfo -Message "Installing .NET 3.5 on '$SccmServerName'" -TaskStart
    $job = Install-LabWindowsFeature -ComputerName $SccmServerName -FeatureName NET-Framework-Core -NoDisplay -AsJob -PassThru
    Wait-LWLabJob -Job $job -NoDisplay
    Write-ScreenInfo -Message "Activity done" -TaskEnd
    
    Write-ScreenInfo -Message "Installing WDS on '$SccmServerName'" -TaskStart
    $job = Install-LabWindowsFeature -ComputerName $SccmServerName -FeatureName WDS -NoDisplay -AsJob -PassThru
    Wait-LWLabJob -Job $job -NoDisplay
    Write-ScreenInfo -Message "Activity done" -TaskEnd
    
    Invoke-LabCommand -ActivityName 'Configure WDS' -ComputerName $SccmServerName -ScriptBlock {
        Start-Process -FilePath "C:\Windows\System32\WDSUTIL.EXE" -ArgumentList "/Initialize-Server /RemInst:G:\RemoteInstall" -Wait
        Start-Sleep -Seconds 10
        Start-Process -FilePath "C:\Windows\System32\WDSUTIL.EXE" -ArgumentList "/Set-Server /AnswerClients:All" -Wait
    }

    #SCCM Needs a ton of additional features installed...
    Write-ScreenInfo -Message "Installing additional features on server '$SccmServerName'" -TaskStart
    $job = Install-LabWindowsFeature -ComputerName $SccmServerName -FeatureName 'FS-FileServer,Web-Mgmt-Tools,Web-Mgmt-Console,Web-Mgmt-Compat,Web-Metabase,Web-WMI,Web-WebServer,Web-Common-Http,Web-Default-Doc,Web-Dir-Browsing,Web-Http-Errors,Web-Static-Content,Web-Http-Redirect,Web-Health,Web-Http-Logging,Web-Log-Libraries,Web-Request-Monitor,Web-Http-Tracing,Web-Performance,Web-Stat-Compression,Web-Dyn-Compression,Web-Security,Web-Filtering,Web-Windows-Auth,Web-App-Dev,Web-Net-Ext,Web-Net-Ext45,Web-Asp-Net,Web-Asp-Net45,Web-ISAPI-Ext,Web-ISAPI-Filter' -NoDisplay -AsJob -PassThru
    Wait-LWLabJob -Job $job -NoDisplay
    Write-ScreenInfo -Message "Activity done" -TaskEnd
    
    Write-ScreenInfo -Message "Installing more additional features on server '$SccmServerName'" -TaskStart
    $job = Install-LabWindowsFeature -ComputerName $SccmServerName -FeatureName 'NET-HTTP-Activation,NET-Non-HTTP-Activ,NET-Framework-45-ASPNET,NET-WCF-HTTP-Activation45,BITS,RDC' -NoDisplay -AsJob -PassThru
    Wait-LWLabJob -Job $job -NoDisplay
    Write-ScreenInfo -Message "Activity done" -TaskEnd

    #Before we start the SCCM Install, restart the computer
    Write-ScreenInfo -Message "Restarting server '$SccmServerName'" -TaskStart
    Restart-LabVM -ComputerName $SccmServerName -Wait -NoDisplay
    Write-ScreenInfo -Message "Activity done" -TaskEnd

    #Build the Installation unattended .INI file
    $setupConfigFileContent = @"
[Identification]
Action=InstallPrimarySite
      
[Options]
ProductID=$SccmProductId
SiteCode=$SccmSiteCode
SiteName=$SccmSiteName
SMSInstallDir=C:\Program Files\Microsoft Configuration Manager
SDKServer=$sccmServerFqdn
RoleCommunicationProtocol=HTTPorHTTPS
ClientsUsePKICertificate=0
PrerequisiteComp=1
PrerequisitePath=$VMSccmPreReqsDirectory
MobileDeviceLanguage=0
ManagementPoint=$sccmServerFqdn
ManagementPointProtocol=HTTP
DistributionPoint=$sccmServerFqdn
DistributionPointProtocol=HTTP
DistributionPointInstallIIS=1
AdminConsole=1
JoinCEIP=0
       
[SQLConfigOptions]
SQLServerName=$SqlServerFqdn
DatabaseName=CM_$SccmSiteCode
SQLDataFilePath=F:\SQL\DATA\
SQLLogFilePath=F:\SQL\LOGS\
       
[CloudConnectorOptions]
CloudConnector=1
CloudConnectorServer=$sccmServerFqdn
UseProxy=0
       
[SystemCenterOptions]
       
[HierarchyExpansionOption]
"@

    #Save the config file to disk, and copy it to the SCCM Server
    $setupConfigFileContent | Out-File -FilePath "$($lab.LabPath)\ConfigMgrUnattend.ini" -Encoding ascii

    Copy-LabFileItem -Path "$($lab.LabPath)\ConfigMgrUnattend.ini" -DestinationFolderPath $VMInstallDirectory -ComputerName $SccmServerName
    
    $sccmComputerAccount = '{0}\{1}$' -f @(
        $sccmServer.DomainName.Substring(0, $sccmServer.DomainName.IndexOf('.')),
        $SccmServerName
    )
    
    if ($SccmServerName -ne $sqlServerName) {
        Invoke-LabCommand -ActivityName 'Add CM system account to local administrators group' -ComputerName $sqlServerName -ScriptBlock {
            if (-not (Get-LocalGroupMember -Group Administrators -Member $sccmComputerAccount -ErrorAction SilentlyContinue))
            {
                Add-LocalGroupMember -Group Administrators -Member $sccmComputerAccount
            }
        } -Variable (Get-Variable -Name "sccmComputerAccount") -NoDisplay
    }

    Invoke-LabCommand -ActivityName 'Create Folders for SQL DB' -ComputerName $sqlServer -ScriptBlock {
        #SQL Server does not like creating databases without the directories already existing, so make sure to create them first
        New-Item -Path 'F:\SQL\DATA\' -ItemType Directory -Force | Out-Null
        New-Item -Path 'F:\SQL\LOGS\' -ItemType Directory -Force | Out-Null
    } -Variable (Get-Variable -Name sccmComputerAccount) -NoDisplay
    
    Write-ScreenInfo "Installing Configuration Manager" -TaskStart
    $exePath = Join-Path -Path $VMSccmBinariesDirectory -ChildPath "SMSSETUP\BIN\X64\setup.exe"
    $iniPath = Join-Path -Path $VMInstallDirectory -ChildPath "ConfigMgrUnattend.ini"
    $cmd = "/Script `"{0}`" /NoUserInput" -f $iniPath
    $job = Install-LabSoftwarePackage -ComputerName $SccmServerName -LocalPath $exePath -CommandLine $cmd -AsJob -PassThru
    Wait-LWLabJob -Job $job -NoDisplay
    Write-ScreenInfo -Message "Activity done" -TaskEnd

    Write-ScreenInfo "Validating install" -TaskStart
    $InstalledSite = Invoke-LabCommand -ActivityName "Validating install" -ComputerName $SccmServerName -ScriptBlock {
        $Query = "SELECT * FROM SMS_Site WHERE SiteCode='{0}'" -f $SccmSiteCode
        Get-CimInstance -Namespace "ROOT/SMS/site_$($SccmSiteCode)" -Query $Query -ErrorAction Stop -ErrorVariable GetCimInstanceErr

    } -Variable (Get-Variable -Name SccmSiteCode) -NoDisplay -PassThru
    Write-ScreenInfo -Message "Activity done" -TaskEnd

    Write-ScreenInfo "Setting file associations and creating shortcuts" -TaskStart
    Invoke-LabCommand -ActivityName "Setting file associations for CMTrace and creating desktop shortcuts" -ComputerName $SccmServerName -ScriptBlock {
        Add-FileAssociation -Extension ".log" -TargetExecutable "C:\Program Files\Microsoft Configuration Manager\tools\cmtrace.exe"
        Add-FileAssociation -Extension ".lo_" -TargetExecutable "C:\Program Files\Microsoft Configuration Manager\tools\cmtrace.exe"
        New-Shortcut -Target "C:\Program Files\Microsoft Configuration Manager\Logs" -ShortcutName "Logs.lnk"
    } -Function (Get-Command "Add-FileAssociation", "New-Shortcut") -NoDisplay
    Write-ScreenInfo -Message "Activity done" -TaskEnd

    Write-ScreenInfo -Message "Restarting" -TaskStart
    try {
        Restart-LabVM -ComputerName $SccmServerName -Wait -ShutdownTimeoutInMinutes 15 -ErrorAction Stop -ErrorVariable RestartLabVMErr
    }
    catch {
        Write-ScreenInfo -Message ("Failed to restart '{0}' ({1})" -f $SccmServerName, $RestartLabVMErr.Exception.Message) -TaskEnd -Type Error
        return
    }
    Write-ScreenInfo -Message "Activity done" -TaskEnd
}

function Update-CMSite {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$SccmSiteCode,

        [Parameter(Mandatory)]
        [string]$SccmServerName
    )

    $InvokeLabCommandSplat = @{
        ComputerName  = $SccmServerName
        PassThru      = $true
    }

    #region Define enums
    enum SMS_CM_UpdatePackages_State {
        AvailableToDownload = 327682
        ReadyToInstall = 262146
        Downloading = 262145
        Installed = 196612
    }
    #endregion

    #region Get latest available update
    Write-ScreenInfo -Message "Getting latest available update" -TaskStart
    try {
        Invoke-LabCommand @InvokeLabCommandSplat -ActivityName "Ensuring CONFIGURATION_MANAGER_UPDATE service is running" -ErrorAction Stop -ErrorVariable InvokeLabCommandErr -ScriptBlock {
            $service = "CONFIGURATION_MANAGER_UPDATE"
            if ((Get-Service $service | Select-Object -ExpandProperty Status) -ne "Running") {
                Start-Service "CONFIGURATION_MANAGER_UPDATE" -ErrorAction Stop
            }
        }
    }
    catch {
        Write-ScreenInfo -Message ("Could not start CONFIGURATION_MANAGER_UPDATE service ({0})" -f $InvokeLabCommandErr.Exception.Message) -TaskEnd -Type "Error"
        return
    }
    $Update = New-LoopAction -LoopTimeout 30 -LoopTimeoutType "Minutes" -LoopDelay 60 -LoopDelayType "Seconds" -ExitCondition {
        $null -ne $Update
    } -IfTimeoutScript {
        Write-ScreenInfo -Message "No updates available" -TaskEnd
        exit
    } -IfSucceedScript {
        return $Update
    } -ScriptBlock {
        try {
            $Update = Invoke-LabCommand @InvokeLabCommandSplat -ActivityName "Getting latest available update" -Variable (Get-Variable -Name "SccmSiteCode") -NoDisplay -ErrorAction Stop -ErrorVariable InvokeLabCommandErr -ScriptBlock {
                Get-CimInstance -Namespace "ROOT/SMS/site_$SccmSiteCode" -Query "SELECT * FROM SMS_CM_UpdatePackages WHERE Impact = '31'" -ErrorAction Stop | Sort-object -Property FullVersion -Descending | Select-Object -First 1
            }
        }
        catch {
            Write-ScreenInfo -Message ("Could not query SMS_CM_UpdatePackages to find latest update ({0})" -f $InvokeLabCommandErr.Exception.Message) -TaskEnd -Type "Error"
            exit
        }
    }
    Write-ScreenInfo -Message ("Found update: '{0}' {1} ({2})" -f $Update.Name, $Update.FullVersion, $Update.PackageGuid)
    $UpdatePackageGuid = $Update.PackageGuid
    Write-ScreenInfo -Message "Activity done" -TaskEnd
    #endregion

    #region Get update download status
    Write-ScreenInfo -Message "Getting update's download status" -TaskStart
    try {
        $Update = Invoke-LabCommand @InvokeLabCommandSplat -ActivityName "Getting update's download status" -NoDisplay -Variable (Get-Variable -Name "Update", "SccmSiteCode") -ErrorAction Stop -ErrorVariable InvokeLabCommandErr -ScriptBlock {
            $Query = "SELECT * FROM SMS_CM_UPDATEPACKAGES WHERE PACKAGEGUID = '{0}'" -f $Update.PackageGuid
            Get-CimInstance -Namespace "ROOT/SMS/site_$SccmSiteCode" -Query $Query -ErrorAction Stop
        }
    }
    catch {
        Write-ScreenInfo -Message ("Failed to query SMS_CM_UpdatePackages after initiating download (2) ({0})" -f $InvokeLabCommandErr.Exception.Message) -TaskEnd -Type "Error"
        exit
    }
    #endregion

    #region Initiate download and wait for state to change to Downloading
    if ($Update.State -eq [SMS_CM_UpdatePackages_State]::AvailableToDownload) {

        Write-ScreenInfo -Message "Initiating download" -TaskStart
        if ($Update.State -eq [SMS_CM_UpdatePackages_State]::AvailableToDownload) {
            try {
                Invoke-LabCommand @InvokeLabCommandSplat -ActivityName "Initiating download" -Variable (Get-Variable -Name "Update") -ErrorAction Stop -ErrorVariable InvokeLabCommandErr -ScriptBlock {
                    Invoke-CimMethod -InputObject $Update -MethodName "SetPackageToBeDownloaded" -ErrorAction Stop
                }
            }
            catch {
                Write-ScreenInfo -Message ("Failed to initiate download ({0})" -f $InvokeLabCommandErr.Exception.Message) -TaskEnd -Type "Error"
                return
            }
        }
        Write-ScreenInfo -Message "Activity done" -TaskEnd

        # If State doesn't change after 5 minutes, restart SMS_EXECUTIVE service and repeat this 3 times, otherwise quit.
        Write-ScreenInfo -Message "Verifying update download initiated OK" -TaskStart
        $Update = New-LoopAction -Iterations 3 -LoopDelay 1 -ExitCondition {
            $Update.State -eq [SMS_CM_UpdatePackages_State]::Downloading
        } -IfTimeoutScript {
            Write-ScreenInfo -Message "Could not initiate download (timed out)" -TaskEnd -Type "Error"
            exit
        } -IfSucceedScript {
            return $Update
        } -ScriptBlock {
            $Update = New-LoopAction -LoopTimeout 300 -LoopTimeoutType "Seconds" -LoopDelay 5 -ExitCondition {
                $Update.State -eq [SMS_CM_UpdatePackages_State]::Downloading
            } -IfSucceedScript {
                return $Update
            } -IfTimeoutScript {
                Write-ScreenInfo -Message "Download did not start, restarting SMS_EXECUTIVE" -TaskStart -Type "Warning"
                try {
                    Restart-ServiceResilient -ComputerName $SccmServerName -ServiceName "SMS_EXECUTIVE" -ErrorAction Stop -ErrorVariable RestartServiceResilientErr
                }
                catch {
                    Write-ScreenInfo -Message ("Could not restart SMS_EXECUTIVE ({0})" -f $RestartServiceResilientErr.Exception.Message) -TaskEnd -Type "Error"
                    exit
                }
                Write-ScreenInfo -Message "Activity done" -TaskEnd
                return $Update
            } -ScriptBlock {
                try {
                    $Update = Invoke-LabCommand @InvokeLabCommandSplat -ActivityName "Verifying update download initiated OK" -NoDisplay -Variable (Get-Variable -Name "Update", "SccmSiteCode") -ErrorAction Stop -ErrorVariable InvokeLabCommandErr -ScriptBlock {
                        $Query = "SELECT * FROM SMS_CM_UPDATEPACKAGES WHERE PACKAGEGUID = '{0}'" -f $Update.PackageGuid
                        Get-CimInstance -Namespace "ROOT/SMS/site_$SccmSiteCode" -Query $Query -ErrorAction Stop
                    }
                }
                catch {
                    Write-ScreenInfo -Message ("Failed to query SMS_CM_UpdatePackages after initiating download (2) ({0})" -f $InvokeLabCommandErr.Exception.Message) -TaskEnd -Type "Error"
                    exit
                }
            }
        }
        Write-ScreenInfo -Message "Download started"
        Write-ScreenInfo -Message "Activity done" -TaskEnd

    }
    #endregion
    
    #region Wait for update to finish download
    if ($Update.State -eq [SMS_CM_UpdatePackages_State]::Downloading) {

        Write-ScreenInfo -Message "Waiting for update to finish downloading" -TaskStart
        $Update = New-LoopAction -LoopTimeout 604800 -LoopTimeoutType "Seconds" -LoopDelay 15 -ExitCondition {
            $Update.State -eq [SMS_CM_UpdatePackages_State]::ReadyToInstall
        } -IfTimeoutScript {
            Write-ScreenInfo -Message "Download timed out" -TaskEnd -Type "Error"
            exit
        } -IfSucceedScript {
            return $Update
        } -ScriptBlock {
            try {
                $Update = Invoke-LabCommand @InvokeLabCommandSplat -ActivityName "Querying update download status" -NoDisplay -Variable (Get-Variable -Name "Update", "SccmSiteCode") -ErrorAction Stop -ErrorVariable InvokeLabCommandErr -ScriptBlock {
                    $Query = "SELECT * FROM SMS_CM_UPDATEPACKAGES WHERE PACKAGEGUID = '{0}'" -f $Update.PackageGuid
                    Get-CimInstance -Namespace "ROOT/SMS/site_$SccmSiteCode" -Query $Query -ErrorAction Stop
                }
            }
            catch {
                Write-ScreenInfo -Message ("Failed to query SMS_CM_UpdatePackages waiting for download to complete ({0})" -f $InvokeLabCommandErr.Exception.Message) -TaskEnd -Type "Error"
                exit
            }
        }
        Write-ScreenInfo -Message "Download complete"
        Write-ScreenInfo -Message "Activity done" -TaskEnd

    }
    #endregion
    
    #region Initiate update install and wait for state to change to Installed
    if ($Update.State -eq [SMS_CM_UpdatePackages_State]::ReadyToInstall) {

        Write-ScreenInfo -Message "Initiating update" -TaskStart
        try {
            Invoke-LabCommand @InvokeLabCommandSplat -ActivityName "Initiating update" -Variable (Get-Variable -Name "Update") -ErrorAction Stop -ErrorVariable InvokeLabCommandErr -ScriptBlock {
                Invoke-CimMethod -InputObject $Update -MethodName "InitiateUpgrade" -Arguments @{PrereqFlag = $Update.PrereqFlag}
            }
        }
        catch {
            Write-ScreenInfo -Message ("Could not initiate update ({0})" -f $InvokeLabCommandErr.Exception.Message) -TaskEnd -Type "Error"
            return
        }
        Write-ScreenInfo -Message "Activity done" -TaskEnd

        Write-ScreenInfo -Message "Waiting for update to finish installing" -TaskStart
        $Update = New-LoopAction -LoopTimeout 43200 -LoopTimeoutType "Seconds" -LoopDelay 5 -LoopDelayType "Seconds" -ExitCondition {
            $Update.State -eq [SMS_CM_UpdatePackages_State]::Installed
        } -IfTimeoutScript {
            Write-ScreenInfo -Message "Install timed out" -TaskEnd -Type "Error"
            exit
        } -IfSucceedScript {
            return $Update
        } -ScriptBlock {
            $Update = Invoke-LabCommand @InvokeLabCommandSplat -ActivityName "Querying update install state" -NoDisplay -Variable (Get-Variable -Name "UpdatePackageGuid", "SccmSiteCode") -ScriptBlock {
                $Query = "SELECT * FROM SMS_CM_UPDATEPACKAGES WHERE PACKAGEGUID = '{0}'" -f $UpdatePackageGuid
                # No error handling since WMI can become unavailabile with "generic error" exception multiple times throughout the update. Not ideal
                Get-CimInstance -Namespace "ROOT/SMS/site_$SccmSiteCode" -Query $Query -ErrorAction SilentlyContinue
            }
        }
        Write-ScreenInfo -Message "Update installed"
        Write-ScreenInfo -Message "Activity done" -TaskEnd
        
    }
    #endregion

    #region Validate update
    Write-ScreenInfo -Message "Validating update" -TaskStart
    try {
        $InstalledSite = Invoke-LabCommand @InvokeLabCommandSplat -ActivityName "Validating update" -Variable (Get-Variable -Name "SccmSiteCode") -ErrorAction Stop -ErrorVariable InvokeLabCommandErr -ScriptBlock {
            Get-CimInstance -Namespace "ROOT/SMS/site_$($SccmSiteCode)" -ClassName "SMS_Site" -ErrorAction "Stop"
        }
    }
    catch {
        Write-ScreenInfo -message ("Could not query SMS_Site to validate update install ({0})" -f $InvokeLabCommandErr.Exception.Message) -TaskEnd -Type "Error"
        return
    }
    if ($InstalledSite.Version -eq $Update.FullVersion) {
        Write-ScreenInfo -Message "Update successfully validated"
    }
    else {
        Write-ScreenInfo -Message ("Update validation failed, installed version is '{0}' and the expected version is '{1}'" -f $InstalledSite.Version, $Update.FullVersion) -Type "Error" -TaskEnd
        return
    }
    Write-ScreenInfo -Message "Activity done" -TaskEnd
    #endregion   

}
#endregion

$lab = Import-Lab -Name $data.Name -NoValidation -NoDisplay -PassThru

$InstallCMSiteSplat = @{
    SccmServerName          = $ComputerName
    SccmBinariesDirectory   = $SCCMBinariesDirectory
    SccmPreReqsDirectory    = $SCCMPreReqsDirectory
    SccmSiteCode            = $SccmSiteCode
    SccmSiteName            = $SccmSiteName
    SccmProductId           = $SccmProductId
    SqlServerName           = $SqlServerName
}

Write-ScreenInfo -Message "Starting site install process" -TaskStart
Install-CMSite @InstallCMSiteSplat
Write-ScreenInfo -Message "Finished site install process" -TaskEnd

$UpdateCMSiteSplat = @{
    SccmServerName  = $ComputerName
    SccmSiteCode    = $SccmSiteCode
}

Write-ScreenInfo -Message "Starting site update process" -TaskStart
Update-CMSite @UpdateCMSiteSplat
Write-ScreenInfo -Message "Finished site update process" -TaskEnd