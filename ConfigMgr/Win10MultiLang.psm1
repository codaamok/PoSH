function New-LXPRepository {
    param (
        [Parameter()]
        [String[]]$Language = @("en-us", "cs-CZ", "de-DE", "es-ES", "fr-FR", "ja-JP", "ko-KR", "sk-SK", "zh-CN", "zh-TW"),
        [Parameter(Mandatory)]
        [String]$SourcePath,
        [Parameter(Mandatory)]
        [String]$TargetPath
    )
    
    Get-ChildItem -Path $SourcePath | ForEach-Object { 
        if ($SupportedLanguages -contains $_.Name) {
            if (-not (Test-Path $TargetPath\$_.Name)) {
                New-Item -Path $TargetPath -Name $_.Name -ItemType Directory -Force
            }

            Copy-Item -Path ("{0}\*" -f $_.FullName) -Destination ("{0}\{1}" -f $TargetPath, $_.Name) -Force
        }
    }
}

function New-FODRepository {
    param (
        [Parameter()]
        [String[]]$Language = @("en-us", "cs-CZ", "de-DE", "es-ES", "fr-FR", "ja-JP", "ko-KR", "sk-SK", "zh-CN", "zh-TW"),
        [Parameter(Mandatory)]
        [String]$SourcePath,
        [Parameter(Mandatory)]
        [String]$TargetPath
    )

    Get-ChildItem -Path $SourcePath | ForEach-Object {
        if ($_.Name -match "LanguageFeatures-\w+-([a-z]{2}-[a-z]{2})") {
            if ($Language -contains $Matches[1]) {
                if (-not (Test-Path $TargetPath\$Matches[1])) {
                    New-Item -Path $TargetPath -Name $Matches[1] -ItemType Directory -Force
                }
    
                Copy-Item -Path $_.FullName -Destination ("{0}\{1}" -f $TargetPath, $Matches[1]) -Force
            }
        }
    }
}