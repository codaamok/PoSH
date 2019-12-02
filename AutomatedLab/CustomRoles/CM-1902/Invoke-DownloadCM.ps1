param(
    [Parameter(Mandatory)]
    [string]$SccmBinariesDirectory,

    [Parameter(Mandatory)]
    [string]$SccmPreReqsDirectory
)

$sccmUrl = 'http://download.microsoft.com/download/1/B/C/1BCADBD7-47F6-40BB-8B1F-0B2D9B51B289/SC_Configmgr_SCEP_1902.exe'
$sccmSetup = Get-LabInternetFile -Uri $sccmUrl -Path $labSources\SoftwarePackages -PassThru

if (-not (Test-Path -Path $SccmBinariesDirectory))
{
    $pArgs = '/AUTO "{0}"' -f $SccmBinariesDirectory
    $p = Start-Process -FilePath $sccmSetup.FullName -ArgumentList $pArgs -PassThru
    Write-ScreenInfo "Waiting for extracting the SCCM files to '$SccmBinariesDirectory'" -NoNewLine
    while (-not $p.HasExited) {
        Write-ScreenInfo '.' -NoNewLine
        Start-Sleep -Seconds 10
    }
    Write-ScreenInfo 'finished'
}
else
{
    Write-ScreenInfo "SCCM folder does already exist, skipping the download. Delete the folder '$SccmBinariesDirectory' if you want to download again."
}

if (-not (Test-Path -Path $SccmPreReqsDirectory))
{
    $p = Start-Process -FilePath $SccmBinariesDirectory\SMSSETUP\BIN\X64\setupdl.exe -ArgumentList $SccmPreReqsDirectory -PassThru
    Write-ScreenInfo "Waiting for downloading the SCCM Prerequisites to '$SccmPreReqsDirectory'" -NoNewLine
    while (-not $p.HasExited) {
        Write-ScreenInfo '.' -NoNewLine
        Start-Sleep -Seconds 10
    }
    Write-ScreenInfo 'finished'
    
}
else
{
    Write-ScreenInfo "SCCM Prerequisites folder does already exist, skipping the download. Delete the folder '$SccmPreReqsDirectory' if you want to download again."
}