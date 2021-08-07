# Azure Functions profile.ps1
#
# This profile.ps1 will get executed every "cold start" of your Function App.
# "cold start" occurs when:
#
# * A Function App starts up for the very first time
# * A Function App starts up after being de-allocated due to inactivity
#
# You can define helper functions, run commands, or specify environment variables
# NOTE: any variables defined that are not environment variables will get reset after the first execution

# Authenticate with Azure PowerShell using MSI.
# Remove this if you are not planning on using MSI or Azure PowerShell.
if ($env:MSI_SECRET) {
    Disable-AzContextAutosave -Scope Process | Out-Null
    Connect-AzAccount -Identity
}

# Uncomment the next line to enable legacy AzureRm alias in Azure PowerShell.
# Enable-AzureRmAlias

# You can also define functions or aliases that can be referenced in any of your PowerShell functions.

function Invoke-GraphWebRequest {
    param (
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.WebRequestMethod]$Method,

        [Parameter(Mandatory)]
        [String]$Uri,

        [Parameter()]
        [hashtable]$Body,

        [Parameter()]
        [hashtable]$Headers,

        [Parameter(Mandatory)]
        [String]$ContentType
    )

    Write-Host ("Sending '{0}' request to Graph '{1}'" -f $Method, $Uri)

    $InvokeRestMethodSplat = @{
        Uri = $Uri
        Method = $Method
        ErrorAction = "Stop"
    }

    if ($PSBoundParameters.ContainsKey("Body")) {
        switch ($ContentType) {
            "application/x-www-form-urlencoded" {
                $QueryString = [System.Web.HttpUtility]::ParseQueryString('')

                # Sanitise client secret from the output stream
                $DisplayBody = $Body.Clone()
                if ($DisplayBody.ContainsKey("Client_Secret")) {
                    $DisplayBody["Client_Secret"] = "*"
                } 
                $DisplayBody = $DisplayBody | ConvertTo-Json

                Write-Host ("Body: {0}" -f $DisplayBody)

                foreach ($item in $Body.GetEnumerator()) {
                    $QueryString.Add($item.Key, $item.Value)
                }
                
                $InvokeRestMethodSplat["Body"] = $QueryString.ToString()
            }
            "application/json" {
                $InvokeRestMethodSplat["Body"] = $Body | ConvertTo-Json -Depth 5
                Write-Host ("Body: {0}" -f $Body)
            }
        }
    }

    if ($PSBoundParameters.ContainsKey("Headers")) {
        $InvokeRestMethodSplat["Headers"] = $Headers
    }

    if ($PSBoundParameters.ContainsKey("ContentType")) {
        $InvokeRestMethodSplat["ContentType"] = $ContentType
    }

    try {
        Invoke-WebRequest @InvokeRestMethodSplat
        Write-Host "Success"
    }
    catch {
        throw
    }
}
