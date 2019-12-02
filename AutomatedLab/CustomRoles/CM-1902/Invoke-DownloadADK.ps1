param(
    [Parameter(Mandatory)]
    [string]$AdkDownloadPath,

    [Parameter(Mandatory)]
    [string]$WinPEDownloadPath
)

$windowsAdkUrl = 'https://go.microsoft.com/fwlink/?linkid=2086042'
$adkSetup = Get-LabInternetFile -Uri $windowsAdkUrl -Path $labSources\SoftwarePackages -FileName "adksetup.exe" -PassThru

if (-not (Test-Path -Path $AdkDownloadPath))
{
    $p = Start-Process -FilePath $adkSetup.FullName -ArgumentList "/quiet /layout $AdkDownloadPath" -PassThru
    Write-ScreenInfo "Waiting for ADK to download files" -NoNewLine
    while (-not $p.HasExited) {
        Write-ScreenInfo '.' -NoNewLine
        Start-Sleep -Seconds 10
    }
    Write-ScreenInfo 'finished'
}
else
{
    Write-ScreenInfo "ADK folder does already exist, skipping the download. Delete the folder '$AdkDownloadPath' if you want to download again."
}

$WinPEUrl = 'https://go.microsoft.com/fwlink/?linkid=2087112'
$WinPESetup = Get-LabInternetFile -Uri $WinPEUrl -Path $labSources\SoftwarePackages -FileName "adkwinpesetup.exe" -PassThru

if (-not (Test-Path -Path $WinPEDownloadPath))
{
    $p = Start-Process -FilePath $WinPESetup.FullName -ArgumentList "/quiet /layout $WinPEDownloadPath" -PassThru
    Write-ScreenInfo "Waiting for WinPE to download files" -NoNewLine
    while (-not $p.HasExited) {
        Write-ScreenInfo '.' -NoNewLine
        Start-Sleep -Seconds 10
    }
    Write-ScreenInfo 'finished'
}
else
{
    Write-ScreenInfo "WinPE folder does already exist, skipping the download. Delete the folder '$WinPEDownloadPath' if you want to download again."
}