function New-LPRepository {
    <#
    .SYNOPSIS
        Copy out only the Language Packs you want from the Language Pack ISO
    .DESCRIPTION
        Copy out only the Language Packs you want from the Language Pack ISO
    .PARAMETER Langauge
        Language(s) you want to extract, e.g. en-us, fr-fr, de-de etc
    .PARAMETER SourcePath
        Path to where the Language Packs are in the Language Pack ISO
    .PARAMETER TargetPath
        Destination path to copy Language Packs to. A folder per language will be created under this folder.
    .EXAMPLE
        PS C:\> New-LPRepository -Language "fr-FR", "de-DE" -SourcePath "I:\x64\langpacks" -TargetPath "F:\OSD\Source\1909-Languages"

        Copies Language Packs named "fr-FR" and "de-DE" from path "I:\LocalExperiencePack" to "F:\OSD\Source\1909-Languages\LP\fr-FR" and "F:\OSD\Source\1909-Languages\LP\de-DE"
    .NOTES
        Author: Adam Cook (@codaamok)
    #>
    param (
        [Parameter()]
        [ValidateSet("ar-sa", "bg-bg", "cs-cz", "da-dk", "de-de", "el-gr", "en-gb", "en-us", "es-es", "es-mx", "et-ee", "fi-fi", "fr-ca", "fr-fr", "he-il", "hr-hr", "hu-hu", "it-it", "ja-jp", "ko-kr", "lt-lt", "lv-lv", "nb-no", "nl-nl", "pl-pl", "pt-br", "pt-pt", "ro-ro", "ru-ru", "sk-sk", "sl-si", "sr-la", "sv-se", "th-th", "tr-tr", "uk-ua", "zh-cn", "zh-tw")]
        [String[]]$Language,
        [Parameter(Mandatory)]
        [String]$SourcePath,
        [Parameter(Mandatory)]
        [String]$TargetPath
    )

    Get-ChildItem -Path $SourcePath -Filter "*.cab" | ForEach-Object {
        if ($_.Name -match "Microsoft-Windows-Client-Language-Pack_x64_([a-z]{2}-[a-z]{2})\.cab") {
            if ($Language -contains $Matches[1]) {
                $Path = "{0}\LP\{1}" -f $TargetPath, $Matches[1]
                if (-not (Test-Path $Path)) {
                    New-Item -Path $Path -ItemType Directory -Force
                }
    
                Copy-Item -Path $_.FullName -Destination $Path -Force
            }
        }
    }
}

function New-LXPRepository {
    <#
    .SYNOPSIS
        Copy out only the folders of the languages you want from the Language Experience Pack ISO
    .DESCRIPTION
        Copy out only the folders of the languages you want from the Language Experience Pack ISO
    .PARAMETER Langauge
        Language(s) you want to extract, e.g. en-us, fr-fr, de-de etc
    .PARAMETER SourcePath
        Path to where the folders of Language Experience Packs are in the Language Experience Pack ISO
    .PARAMETER TargetPath
        Destination path to copy the folders to
    .EXAMPLE
        PS C:\> New-LXPRepository -Language "fr-FR", "de-DE" -SourcePath "I:\LocalExperiencePack" -TargetPath "F:\OSD\Source\1909-Languages"

        Copies folders named "fr-FR" and "de-DE" in Language Experience Pack ISO path "I:\LocalExperiencePack" to "F:\OSD\Source\1909-Languages\LXP\"
    .NOTES
        Author: Adam Cook (@codaamok)
    #>
    param (
        [Parameter()]
        [ValidateSet("af-za", "am-et", "ar-sa", "as-in", "az-latn-az", "be-by", "bg-bg", "bn-bd", "bn-in", "bs-latn-ba", "ca-es", "ca-es-valencia", "chr-cher-us", "cs-cz", "cy-gb", "da-dk", "de-de", "el-gr", "en-gb", "en-us", "es-es", "es-mx", "et-ee", "eu-es", "fa-ir", "fi-fi", "fil-ph", "fr-ca", "fr-fr", "ga-ie", "gd-gb", "gl-es", "gu-in", "ha-latn-ng", "he-il", "hi-in", "hr-hr", "hu-hu", "hy-am", "id-id", "ig-ng", "is-is", "it-it", "ja-jp", "ka-ge", "kk-kz", "km-kh", "kn-in", "ko-kr", "kok-in", "ku-arab-iq", "ky-kg", "lb-lu", "lo-la", "lt-lt", "lv-lv", "mi-nz", "mk-mk", "ml-in", "mn-mn", "mr-in", "ms-my", "mt-mt", "nb-no", "ne-np", "nl-nl", "nn-no", "nso-za", "or-in", "pa-arab-pk", "pa-in", "pl-pl", "prs-af", "pt-br", "pt-pt", "quc-latn-gt", "quz-pe", "ro-ro", "ru-ru", "rw-rw", "sd-arab-pk", "si-lk", "sk-sk", "sl-si", "sq-al", "sr-cyrl-ba", "sr-cyrl-rs", "sr-latn-rs", "sv-se", "sw-ke", "ta-in", "te-in", "tg-cyrl-tj", "th-th", "ti-et", "tk-tm", "tn-za", "tr-tr", "tt-ru", "ug-cn", "uk-ua", "ur-pk", "uz-latn-uz", "vi-vn", "wo-sn", "xh-za", "yo-ng", "zh-cn", "zh-tw", "zu-za")]
        [String[]]$Language,
        [Parameter(Mandatory)]
        [String]$SourcePath,
        [Parameter(Mandatory)]
        [String]$TargetPath
    )
    
    Get-ChildItem -Path $SourcePath | ForEach-Object { 
        if ($Language -contains $_.Name) {
            $Path = "{0}\LXP\{1}" -f $TargetPath, $_.Name
            if (-not (Test-Path $Path)) {
                New-Item -Path $Path -ItemType Directory -Force
            }

            Copy-Item -Path ("{0}\*" -f $_.FullName) -Destination $Path -Force
        }
    }
}

function New-FoDLanguageFeaturesRepository {
    <#
    .SYNOPSIS
        Copy out only the languages you want of the Features on Demand LanguageFeatures Basic, Handwriting, OCR, Speech and TextToSpeech from Features on Demand ISO
    .DESCRIPTION
        Copy out only the languages you want of the Features on Demand LanguageFeatures Basic, Handwriting, OCR, Speech and TextToSpeech from Features on Demand ISO
    .PARAMETER Langauge
        Language(s) you want to extract, e.g. en-us, fr-fr, de-de etc
    .PARAMETER SourcePath
        Path to where the Features on Demand are in the Features on Demand ISO
    .PARAMETER TargetPath
        Destination path to copy Features on Demand to. A folder per language will be created under this folder.
    .EXAMPLE
        PS C:\> New-FoDLanguageFeaturesRepository -Language "fr-FR", "de-DE" -SourcePath "I:\" -TargetPath "F:\OSD\Source\1909-Languages"

        Copies Features on Demand of LanguageFeatures Basic, Handwriting, OCR, Speech and TextToSpeech with language elements "fr-FR", "de-DE" in path "I:\" to "F:\OSD\Source\1909-Languages\FoD\fr-FR" and "F:\OSD\Source\1909-Languages\FoD\de-DE"
    .NOTES
        Author: Adam Cook (@codaamok)
    #>
    param (
        [Parameter()]
        [ValidateSet("ar-SA", "bg-BG", "cs-CZ", "da-DK", "de-DE", "el-GR", "en-GB", "en-US", "es-ES", "es-MX", "et-EE", "fi-FI", "fr-CA", "fr-FR", "he-IL", "hr-HR", "hu-HU", "it-IT", "ja-JP", "ko-KR", "lt-LT", "lv-LV", "nb-NO", "nl-NL", "pl-PL", "pt-BR", "pt-PT", "ro-RO", "ru-RU", "sk-SK", "sl-SI", "sr-Latn-RS", "sv-SE", "th-TH", "tr-TR", "uk-UA", "zh-CN", "zh-TW")]
        [String[]]$Language,
        [Parameter(Mandatory)]
        [String]$SourcePath,
        [Parameter(Mandatory)]
        [String]$TargetPath
    )

    Get-ChildItem -Path $SourcePath | ForEach-Object {
        if ($_.Name -match "LanguageFeatures-\w+-([\w]{2}-[\w]{4}-[\w]{2}|[\w]{2}-[\w]{2})") {
            if ($Language -contains $Matches[1]) {
                $Path = "{0}\FoD\{1}" -f $TargetPath, $Matches[1]
                if (-not (Test-Path $Path)) {
                    New-Item -Path $Path -ItemType Directory -Force
                }
    
                Copy-Item -Path $_.FullName -Destination $Path -Force
            }
        }
    }
}