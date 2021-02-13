<#
.SYNOPSIS
    Create a WinPE boot image.
.DESCRIPTION
    Create a WinPE boot image. Optionally apply any updates, drivers or optional components to the image.
.EXAMPLE
    PS C:\> .\New-WinPEWIM.ps1 -Platforms "amd64" -OptionalComponents "WinPE-WDS-Tools", "WinPE-Scripting", "WinPE-WMI", "WinPE-SecureStartup", "WinPE-NetFx", "WinPE-PowerShell", "WinPE-StorageWMI", "WinPE-DismCmdlets" -OutputDirectory "G:\OSD\BootImages" -DriversDirectory "G:\Drivers\WINPE10.0-DRIVERS-A22-3GVJN\x64" -UpdatesDirectory "G:\SoftwareUpdates\Patches\20200213"
    
    Copy winpe.wim from the amd64 folder in your ADKInstallDirectory to G:\OSD\BootImages named "WinPE-amd64-yyyy-MM-dd.wim". 
    
    Mount the windows image to your %TEMP% directory and install the listed optional components. 
    
    Then install all drivers in "G:\Drivers\WINPE10.0-DRIVERS-A22-3GVJN\x64" (recursively), and also install the Windows updates in "G:\SoftwareUpdates\Patches\20200213".
.NOTES
    Author: Adam Cook (@codaamok)
    Adapation of PEPrep.ps1 from Michael Niehaus https://oofhours.com/2021/01/17/build-your-own-windows-pe-image/
#>
param (
    [Parameter()]
    [ValidateSet("amd64", "x86", "arm64")]
    [String[]]$Platforms = "amd64",

    [Parameter()]
    [ValidateSet(
        "WinPE-DismCmdlets", 
        "WinPE-Dot3Svc",
        "WinPE-EnhancedStorage",
        "WinPE-FMAPI",
        "WinPE-Fonts-Legacy",
        "WinPE-FontSupport-JA-JP",
        "WinPE-FontSupport-KO-KR",
        "WinPE-FontSupport-WinRE",
        "WinPE-FontSupport-ZH-CN",
        "WinPE-FontSupport-ZH-HK",
        "WinPE-FontSupport-ZH-TW",
        "WinPE-GamingPeripherals",
        "WinPE-HTA",
        "WinPE-LegacySetup",
        "WinPE-MDAC",
        "WinPE-NetFx",
        "WinPE-PlatformId",
        "WinPE-PowerShell",
        "WinPE-PPPoE",
        "WinPE-RNDIS",
        "WinPE-Scripting",
        "WinPE-SecureBootCmdlets",
        "WinPE-SecureStartup",
        "WinPE-Setup-Client",
        "WinPE-Setup-Server",
        "WinPE-Setup",
        "WinPE-StorageWMI",
        "WinPE-WDS-Tools",
        "WinPE-WinReCfg",
        "WinPE-WMI"
    )]
    [String[]]$OptionalComponents,

    [Parameter()]
    [ValidateScript({
        if (-not (Test-Path $_)) {
            throw "OutputDirectory does not exist"
        }
        $true
    })]
    [String]$OutputDirectory = [Environment]::GetFolderPath("MyDocuments"),

    [Parameter()]
    [ValidateScript({
        if (-not (Test-Path $_)) {
            throw "DriversDirectory does not exist"
        }
        $true
    })]
    [String]$DriversDirectory,

    [Parameter()]
    [ValidateScript({
        if (-not (Test-Path $_)) {
            throw "DriversDirectory does not exist"
        }
        $true
    })]
    [String]$UpdatesDirectory,

    [Parameter()]
    [ValidateScript({
        if (-not (Test-Path $_)) {
            throw "ADKInstallDirectory does not exist"
        }
        $true
    })]
    [String]$ADKInstallDirectory # e.g. C:\Program Files (x86)\Windows Kits\10\
)

$JobId = Get-Date -Format 'yyyy-MM-dd'

if (-not $PSBoundParameters.ContainsKey("ADKInstallDirectory")) {
    # Find the ADK
    $Paths = @(
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots"
        "HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots"
    )

    $kitsRoot = Get-ItemPropertyValue -Path $Paths -Name KitsRoot10 -ErrorAction "SilentlyContinue"
}
else {
    $kitsRoot = $ADKInstallDirectory
}

if (-not $kitsRoot) {
    Write-Error -Message "ADK is not installed." -ErrorAction "Stop"
}
elseif ($kitsRoot.Count -gt 1) {
    Write-Verbose ("Found more than one ADK install directory, using '{0}'" -f $kitsRoot[0]) -Verbose
    Write-Verbose "Consider using the -ADKInstallDirectory parameter if you want to use a directory" -Verbose
    $kitsRoot = $kitsRoot[0]
}

# Find Windows PE
$peRoot = "{0}\Assessment and Deployment Kit\Windows Preinstallation Environment\" -f $kitsRoot
if (-not (Test-Path $peRoot)) {
    Write-Error "Windows PE is not installed." -ErrorAction "Stop"
}

foreach ($Platform in $Platforms) {

    # Copy the winpe.wim
    $peFile = "$peRoot\$Platform\en-us\winpe.wim"
    if (-not (Test-Path $peFile)) {
        Write-Error "Windows PE file " + $peFile + " does not exist." -ErrorAction "Stop"
    }
    $peNew = "{0}\WinPE-{1}-{2}.wim" -f $OutputDirectory, $Platform, $JobId
    Copy-Item -Path $peFile -Destination $peNew -Force -Verbose

    # Mount the winpe.wim
    $peMount = "$($env:TEMP)\mount_$Platform"
    if (-not (Test-Path $peMount)) {
        MkDir $peMount
    }
    Mount-WindowsImage -Path $peMount -ImagePath $peNew -Index 1 -Verbose

    # Add the needed components to it
    $PackagePath = "$peRoot\$Platform\WinPE_OCs"
    foreach ($Component in $OptionalComponents) {
        $Path = "{0}.cab" -f (Join-Path -Path $PackagePath -ChildPath $Component)
        Add-WindowsPackage -Path $peMount -PackagePath $Path -Verbose
    }

    # Inject any needed drivers
    if ($PSBoundParameters.ContainsKey("DriversDirectory")) {
        Add-WindowsDriver -Path $peMount -Driver $DriversDirectory -Recurse -Verbose
    }

    # Inject any needed update
    if ($PSBoundParameters.ContainsKey("UpdatesDirectory")) {
        Get-ChildItem ".\$Platform\Updates" | ForEach-Object { 
            Add-WindowsPackage -Path $peMount -PackagePath $_.FullName -Verbose
        }
    }

    # Unmount and commit
    Dismount-WindowsImage -Path $peMount -Save -Verbose

    # Report completion
    Write-Host "Windows PE generated: $peNew" -ForegroundColor Green
}
