Start-Transcript -Path "C:\transcript.txt" -ErrorAction "Stop"

$AutomatedLabURL = "https://github.com/AutomatedLab/AutomatedLab/releases/latest/download/AutomatedLab.msi"
$ISO = @{
    WindowsServer2019Eval = "https://software-download.microsoft.com/download/pr/17763.737.190906-2324.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us_1.iso"
}

New-Item -Path "C:\Sources" -ItemType "Directory" -Force -ErrorAction "Stop"

Invoke-WebRequest -Uri $AutomatedLabURL -OutFile "C:\Sources\AutomatedLab.msi"

Start-Process -FilePath "C:\Sources\AutomatedLab.msi" -ArgumentList "/qn" -Wait

foreach ($item in $ISO.GetEnumerator()) {
    $File = "C:\LabSources\ISOs\{0}.iso" -f $item.Key
    Invoke-WebRequest -Uri $item.Value -OutFile $File
}

Update-Module "PackageManagement","PowerShellGet" -Force

Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module "codaamok" -Force

Stop-Transcript