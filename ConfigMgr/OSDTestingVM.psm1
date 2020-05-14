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
        [String]$Server,
        [Parameter(Mandatory=$false, Position = 1)]
        [String]$SiteCode,
        [Parameter(Mandatory=$false, Position = 2)]
        [String]$Path = (Get-Location | Select-Object -ExpandProperty Path)
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

function New-TestVM {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$VMHost,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$VMName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$CollectionName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$SiteServer,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$SiteCode,

        [Parameter()]
        [Switch]$TPM,

        [Parameter()]
        [ValidateSet("On", "Off")]
        [String]$SecureBoot
    )

    $Path = (Get-VMHost -ComputerName $VMHost).VirtualMachinePath

    New-VM -ComputerName $VMHost -Name $VMName -Generation 2 -Path $Path -NewVHDPath "$Path\$VMName\System.vhdx" -NewVHDSizeBytes ([int64]1gb*60) -SwitchName "Cluster-Switch" -Confirm:$false -Version "9.0"
    Set-VM -ComputerName $VMHost -Name $VMName -AutomaticStartAction "Nothing" -AutomaticStopAction "ShutDown"
    $Adapter = Get-VMNetworkAdapter -ComputerName $VMHost -VMName $VMName
    Set-VMFirmware -ComputerName $VMHost -VMName $VMName -EnableSecureBoot $SecureBoot -FirstBootDevice $Adapter
    Set-VMMemory -ComputerName $VMHost -VMName $VMName -DynamicMemoryEnabled $true -StartupBytes ([int64]1GB) -MaximumBytes ([int64]1GB*4) -MinimumBytes ([int64]1GB)
    Set-VMProcessor -ComputerName $VMHost -VMName $VMName -Count 2
    Set-VMNetworkAdapterVlan -ComputerName $VMHost -VMName $VMName -VlanId 100 -Access
    Set-VMKeyProtector -ComputerName $VMHost -VMName $VMName -NewLocalKeyProtector
    if ($TPM) {
        Enable-VMTPM -ComputerName $VMHost -VMName $VMName -Confirm:$false
    }
    Start-VM -ComputerName $VMHost -Name $VMName
    Start-Sleep -Seconds 5
    Stop-VM -ComputerName $VMHost -Name $VMName -Force

    $MACAddress = (Get-VMNetworkAdapter -ComputerName $VMHost -VMName $VMName).MacAddress

    $OriginalLocation = Get-Location
    
    $ConnectCMDriveSplat = @{}

    if ($PSBoundParameters.ContainsKey("SiteServer")) {
        $ConnectCMDriveSplat["Server"] = $SiteServer
    }

    if ($PSBoundParameters.ContainsKey("SiteCode")) {
        $ConnectCMDriveSplat["SiteCode"] = $SiteCode
    }

    if ($ConnectCMDriveSplat.Count -gt 0) {
        Connect-CMDrive
    }
    else {
        Connect-CMDrive @ConnectCMDriveSplat
    }
    
    Import-CMComputerInformation -ComputerName $VMName -MacAddress $MACAddress -CollectionName $CollectionName
    
    Set-Location $OriginalLocation
}

function Remove-TestVM {
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$VMHost,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$VMName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$SiteServer,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$SiteCode,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [PSCredential]$Credential
    )

    $Path = (Get-VM -ComputerName $VMHost -Name $VMName).Path

    try {
        Invoke-Command -ComputerName $VMHost -ScriptBlock {
            param (
                $Path
            )
            try {
                if (-not (Test-Path $Path -ErrorAction "Stop")) {
                    throw "Not exist"
                }
            }
            catch {
                throw
            }
        } -ArgumentList $Path -ErrorAction "Stop"
    }
    catch {
        throw
    }

    Stop-VM -ComputerName $VMhost -Name $VMName -Force -TurnOff -Confirm:$false -ErrorAction "Stop"
    Remove-VM -ComputerName $VMHost -Name $VMName -Force -Confirm:$false -ErrorAction "Stop"

    Invoke-Command -ComputerName $VMHost -ScriptBlock {
        param (
            $Path
        )
        Remove-Item -Path $Path -Force -ErrorAction "Stop"
    } -ArgumentList $Path -ErrorAction "Stop"

    $RemoveADObjectSplat = @{
        Confirm = $false
        Recursive = $true
    }
    if ($PSBoundParameters.ContainsKey("Credential")) {
        $RemoveADObjectSplat = @{
            Credential = $Credential
        }
    }
    Get-ADComputer -Identity $VMName | Remove-ADObject @RemoveADObjectSplat

    $OriginalLocation = Get-Location

    $ConnectCMDriveSplat = @{}

    if ($PSBoundParameters.ContainsKey("SiteServer")) {
        $ConnectCMDriveSplat["Server"] = $SiteServer
    }

    if ($PSBoundParameters.ContainsKey("SiteCode")) {
        $ConnectCMDriveSplat["SiteCode"] = $SiteCode
    }

    if ($ConnectCMDriveSplat.Count -gt 0) {
        Connect-CMDrive
    }
    else {
        Connect-CMDrive @ConnectCMDriveSplat
    }

    Remove-CMDevice -Name $VMName -Force

    Set-Location $OriginalLocation
}
