Start-Transcript -Path "C:\transcript.txt" -ErrorAction "Stop"

$ProgressPreference = "SilentlyContinue"
$AutomatedLabURL = "https://github.com/AutomatedLab/AutomatedLab/releases/latest/download/AutomatedLab.msi"
$ISO = @{
    WindowsServer2019Eval = "https://software-download.microsoft.com/download/pr/17763.737.190906-2324.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us_1.iso"
}

Write-Host "Creating directories"
New-Item -Path "C:\Sources" -ItemType "Directory" -Force -ErrorAction "Stop"
New-Item -Path "C:\git" -ItemType "Directory" -Force -ErrorAction "Stop"

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

Write-Host "Importing codaamok module"
Import-Module "codaamok" -ErrorAction "Stop"

Write-Host "Installing Chocolatey"
Install-Choco

Write-Host "Installing git"
Start-Process -FilePath "C:\ProgramData\chocolatey\choco.exe" -ArgumentList "install","git","-y" -Wait

Write-Host "Cloning PoSH.git"
Push-Location "C:\git"
Start-Process -FilePath "C:\Program Files\Git\bin\git.exe" -ArgumentList "clone","https://github.com/codaamok/PoSH.git" -Wait
Pop-Location

Write-Host "Installing Hyper-V"
Install-WindowsFeature -Name "Hyper-V*" -IncludeManagementTools

Write-Host "Scheduling reboot"
Start-Process -FilePath "C:\system32\shutdown.exe" -ArgumentList "-r","-f","-t","15" -Wait

Stop-Transcript