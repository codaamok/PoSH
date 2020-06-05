Param (
    [Parameter(Mandatory)]
    [String]$CMBinariesDirectory,

    [Parameter(Mandatory)]
    [String]$CMPreReqsDirectory,

    [Parameter(Mandatory)]
    [String]$CMDownloadURL,

    [Parameter(Mandatory)]
    [String]$Branch
)

Write-ScreenInfo -Message "Starting CM binaries and prerequisites download process" -TaskStart

#region CM binaries
Write-ScreenInfo -Message "Downloading CM binaries archive" -TaskStart

$CMZipPath = "{0}\SoftwarePackages\{1}" -f $labSources, ((Split-Path $CMDownloadURL -Leaf) -replace "\.exe$", ".zip")

if (Test-Path -Path $CMZipPath) {
    Write-ScreenInfo -Message ("CM binaries archive already exists, delete '{0}' if you want to download again" -f $CMZipPath)
}

try {
    $CMZipObj = Get-LabInternetFile -Uri $CMDownloadURL -Path (Split-Path -Path $CMZipPath -Parent) -FileName (Split-Path -Path $CMZipPath -Leaf) -PassThru -ErrorAction "Stop" -ErrorVariable "GetLabInternetFileErr"
}
catch {
    $Message = "Failed to download CM binaries archive from '{0}' ({1})" -f $CMDownloadURL, $GetLabInternetFileErr.ErrorRecord.Exception.Message
    Write-ScreenInfo -Message $Message -Type "Error" -TaskEnd
    throw $Message
}

Write-ScreenInfo -Message "Activity done" -TaskEnd
#endregion

#region Extract CM binaries
Write-ScreenInfo -Message "Extracting CM binaries from archive" -TaskStart

if (-not (Test-Path -Path $CMBinariesDirectory))
{
    try {
        Expand-Archive -Path $CMZipObj.FullName -DestinationPath $CMBinariesDirectory -Force -ErrorAction "Stop" -ErrorVariable "ExpandArchiveErr"
    }
    catch {
        $Message = "Failed to initiate extraction to '{0}' ({1})" -f $CMBinariesDirectory, $ExpandArchiveErr.ErrorRecord.Exception.Message
        Write-ScreenInfo -Message $Message -Type "Error" -TaskEnd
        throw $Message
    }
}
else
{
    Write-ScreenInfo -Message ("CM directory already exists, skipping the download. Delete the directory '{0}' if you want to download again." -f $CMBinariesDirectory)
}

Write-ScreenInfo -Message "Activity done" -TaskEnd
#endregion

#region Download CM prerequisites
Write-ScreenInfo -Message "Downloading CM prerequisites" -TaskStart

switch ($Branch) {
    "CB" {
        if (-not (Test-Path -Path $CMPreReqsDirectory))
        {
            try {
                $p = Start-Process -FilePath $CMBinariesDirectory\SMSSETUP\BIN\X64\setupdl.exe -ArgumentList "/NOUI", $CMPreReqsDirectory -PassThru -ErrorAction "Stop" -ErrorVariable "StartProcessErr"
            }
            catch {
                $Message = "Failed to initiate download of CM pre-req files to '{0}' ({1})" -f $CMPreReqsDirectory, $StartProcessErr.ErrorRecord.Exception.Message
                Write-ScreenInfo -Message $Message -Type "Error" -TaskEnd
                throw $Message
            }
            Write-ScreenInfo -Message "Waiting for CM prerequisites to finish downloading"
            while (-not $p.HasExited) {
                Write-ScreenInfo '.' -NoNewLine
                Start-Sleep -Seconds 10
            }
            Write-ScreenInfo -Message '.'
        }
        else
        {
            Write-ScreenInfo -Message ("CM prerequisites directory already exists, skipping the download. Delete the directory '{0}' if you want to download again." -f $CMPreReqsDirectory)
        }        
    }
    "TP" {
        $Messages = @(
            "Directory '{0}' is intentionally empty." -f $CMPreReqsDirectory
            "The prerequisites will be downloaded by the installer within the VM."
            "This is a workaround due to a known issue with TP 2002 baseline: https://twitter.com/codaamok/status/1268588138437509120"
        )

        try {
            $PreReqDirObj = New-Item -Path $CMPreReqsDirectory -ItemType "Directory" -Force -ErrorAction "Stop" -ErrorVariable "CreateCMPreReqDir"
            Set-Content -Path ("{0}\readme.txt" -f $PreReqDirObj.FullName) -Value $Messages -ErrorAction "SilentlyContinue"
        }
        catch {
            $Message = "Failed to create CM prerequisite directory '{0}' ({1})" -f $CMPreReqsDirectory, $CreateCMPreReqDir.ErrorRecord.Exception.Message
            Write-ScreenInfo -Message $Message -Type "Error" -TaskEnd
            throw $Message
        }

        Write-ScreenInfo -Message $Messages
    }
}

Write-ScreenInfo -Message "Activity done" -TaskEnd
#endregion

# Workaround because Write-Progress doesn't yet seem to clear up from Get-LabInternetFile
Write-Progress -Activity * -Completed

Write-ScreenInfo -Message "Finished CM binaries and prerequisites download process" -TaskEnd
