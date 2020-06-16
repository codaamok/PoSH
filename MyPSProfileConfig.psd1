@{
  ProjectPaths = @()
  PluginPaths = @('C:\Users\acc\OneDrive - Adam Cook\Documents\WindowsPowerShell\Modules\PSProfile\0.6.2\Plugins')
  GitPathMap = @{
    
  }
  Settings = @{
    ConfigurationPath = 'C:\Users\acc\AppData\Roaming\powershell\SCRT HQ\PSProfile\Configuration.psd1'
    DefaultPrompt = 'myprompt'
    PSReadline = @{
      KeyHandlers = @{
        
      }
      Options = @{
        
      }
    }
    FontType = 'Default'
    PSVersionStringLength = 3
    PromptCharacters = @{
      AWS = @{
        NerdFonts = ''
        Default = 'AWS: '
        PowerLine = ''
      }
      GitRepo = @{
        NerdFonts = ''
        Default = '@'
        PowerLine = ''
      }
    }
  }
  LastSave = (DateTime '2020-06-14T21:44:28.2823350+01:00')
  Variables = @{
    Environment = @{
      UserName = 'acc'
      ComputerName = 'CODAAMOKL'
      Home = 'C:\Users\acc'
    }
    Global = @{
      AltPathAliasDirectorySeparator = ''
      PathAliasDirectorySeparator = '\'
    }
  }
  PathAliases = @{
    '~' = 'C:\Users\acc'
  }
  SymbolicLinks = @{
    
  }
  ModulesToInstall = @()
  Plugins = @()
  ModulesToImport = @()
  RefreshFrequency = '01:00:00'
  ScriptPaths = @()
  CommandAliases = @{
    
  }
  InitScripts = @{
    
  }
  Prompts = @{
    SCRTHQ = '$lastStatus = $?
                                        $lastColor = if ($lastStatus -eq $true) {
                                        "Green"
                                        }
                                        else {
                                        "Red"
                                        }
                                        $isAdmin = $false
                                        $isDesktop = ($PSVersionTable.PSVersion.Major -eq 5)
                                        if ($isDesktop -or $IsWindows) {
                                        $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
                                        $windowsPrincipal = New-Object "System.Security.Principal.WindowsPrincipal" $windowsIdentity
                                        $isAdmin = $windowsPrincipal.IsInRole("Administrators") -eq 1
                                        } else {
                                        $isAdmin = ((& id -u) -eq 0)
                                        }
                                        if ($isAdmin) {
                                        $idColor = "Magenta"
                                        }
                                        else {
                                        $idColor = "Cyan"
                                        }
                                        Write-Host "[" -NoNewline
                                        Write-Host -ForegroundColor $idColor "#$($MyInvocation.HistoryId)" -NoNewline
                                        Write-Host "] [" -NoNewline
                                        $verColor = @{
                                        ForegroundColor = if ($PSVersionTable.PSVersion.Major -eq 7) {
                                        "Yellow"
                                        }
                                        elseif ($PSVersionTable.PSVersion.Major -eq 6) {
                                        "Magenta"
                                        }
                                        else {
                                        "Cyan"
                                        }
                                        }
                                        Write-Host @verColor ("PS {0}" -f (Get-PSVersion)) -NoNewline
                                        Write-Host "] [" -NoNewline
                                        Write-Host -ForegroundColor $lastColor ("{0}" -f (Get-LastCommandDuration)) -NoNewline
                                        Write-Host "] [" -NoNewline
                                        Write-Host ("{0}" -f $(Get-PathAlias)) -NoNewline -ForegroundColor DarkYellow
                                        if ((Get-Location -Stack).Count -gt 0) {
                                        Write-Host (("+" * ((Get-Location -Stack).Count))) -NoNewLine -ForegroundColor Cyan
                                        }
                                        Write-Host "]" -NoNewline
                                        if ($PWD.Path -notlike "\\*" -and $env:DisablePoshGit -ne $true) {
                                        Write-VcsStatus
                                        $GitPromptSettings.EnableWindowTitle = "PS {0} @" -f (Get-PSVersion)
                                        }
                                        else {
                                        $Host.UI.RawUI.WindowTitle = "PS {0}" -f (Get-PSVersion)
                                        }
                                        if ($env:AWS_PROFILE) {
                                        Write-Host "`n[" -NoNewline
                                        $awsIcon = if ($global:PSProfile.Settings.ContainsKey("FontType")) {
                                        $global:PSProfile.Settings.PromptCharacters.AWS[$global:PSProfile.Settings.FontType]
                                        }
                                        else {
                                        "AWS:"
                                        }
                                        if ([String]::IsNullOrEmpty($awsIcon)) {
                                        $awsIcon = "AWS:"
                                        }
                                        Write-Host -ForegroundColor Yellow "$($awsIcon) $($env:AWS_PROFILE)$(if($env:AWS_DEFAULT_REGION){" @ $env:AWS_DEFAULT_REGION"})" -NoNewline
                                        Write-Host "]" -NoNewline
                                        }
                                        "`n>> "'
    myprompt = '$adminfg = switch ($script:MyOS) {
                "Windows" {
                    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
                    switch ((New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
                        $true {
                            "Red"
                        }
                        $false {
                            "White"
                        }
                    }
                }
                default {
                    "White"
                }
            }
            switch ((Get-Location).Provider.Name) {
                "FileSystem"    { $fg = "green"}
                "Registry"      { $fg = "magenta"}
                "wsman"         { $fg = "cyan"}
                "Environment"   { $fg = "yellow"}
                "Certificate"   { $fg = "darkcyan"}
                "Function"      { $fg = "gray"}
                "alias"         { $fg = "darkgray"}
                "variable"      { $fg = "darkgreen"}
                default         { $fg = $host.ui.rawui.ForegroundColor}
            }
            Write-Host ("[{0}@{1}] " -f $global:MyUsername, [System.Net.Dns]::GetHostName()) -NoNewline
            Write-Host ("[{0}]" -f (Get-Date -Format "HH:mm:ss")) -NoNewline
            Write-Host " PS " -NoNewline -ForegroundColor $adminfg
            Write-Host $ExecutionContext.SessionState.Path.CurrentLocation -ForegroundColor $fg
            Write-Output ("{0} " -f (">" * ($nestedPromptLevel + 1)))'
  }
  LastRefresh = (DateTime '2020-06-14T21:24:36.7249808+01:00')
  PSBuildPathMap = @{
    
  }
}
