Function prompt {
    # .Description
    # This custom version of the PowerShell prompt will present a colorized location value based on the current provider. It will also display the PS prefix in red if the current user is running as administrator.    
    # .Link
    # https://go.microsoft.com/fwlink/?LinkID=225750
    # .ExternalHelp System.Management.Automation.dll-help.xml
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    switch ((New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        $true {
            $adminfg = "red"
        }
        $false {
            $adminfg = "white"
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
    Write-Host "[$env:USERNAME@$env:COMPUTERNAME] " -NoNewline
    Write-Host "[$(Get-Date -Format "HH:mm:ss")]" -NoNewline
    Write-Host " PS " -NoNewline -ForegroundColor $adminfg
    Write-Host "$($ExecutionContext.SessionState.Path.CurrentLocation)" -ForegroundColor $fg -NoNewline
    Write-Output "$('>' * ($nestedPromptLevel + 1)) "
    Write-Host "" 
}