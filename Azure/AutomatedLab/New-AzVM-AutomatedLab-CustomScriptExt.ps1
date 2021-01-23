Start-Transcript -Path "C:\transcript.txt" -ErrorAction "Stop"

$ProgressPreference = "SilentlyContinue"
$AutomatedLabURL = "https://github.com/AutomatedLab/AutomatedLab/releases/latest/download/AutomatedLab.msi"
$ISO = @{
    WindowsServer2019Eval = "https://software-download.microsoft.com/download/pr/17763.737.190906-2324.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us_1.iso"
}

Write-Host "Creating directory"
New-Item -Path "C:\Sources" -ItemType "Directory" -Force -ErrorAction "Stop"

Write-Host "Downloading AutomatedLab"
Invoke-WebRequest -Uri $AutomatedLabURL -OutFile "C:\Sources\AutomatedLab.msi"

Write-Host "Installing AutomatedLab"
Start-Process -FilePath "C:\Sources\AutomatedLab.msi" -ArgumentList "/qn" -Wait

foreach ($item in $ISO.GetEnumerator()) {
    $File = "C:\LabSources\ISOs\{0}.iso" -f $item.Key
    Write-Host ("Downloading '{0}'" -f $item.Value)
    Invoke-WebRequest -Uri $item.Value -OutFile $File
}

Write-Host "Updating NuGet.exe"
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

Write-Host "Installing codaamok module"
Install-Module "codaamok" -Force

Stop-Transcript