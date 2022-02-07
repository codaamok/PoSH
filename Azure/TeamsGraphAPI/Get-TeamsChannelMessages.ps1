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

$secret = Get-Secure "TeamsGIFLeaderboard"
$AAD_APP_ID = $secret.UserName
$AAD_APP_SECRET = $secret.GetNetworkCredential().Password

$ReqTokenBody = @{
    Grant_Type    = "client_credentials"
    Scope         = "https://graph.microsoft.com/.default"
    Client_Id     = $AAD_APP_ID
    Client_Secret = $AAD_APP_SECRET
}

$InvokeGraphWebRequest = @{
    Uri         = "https://login.microsoftonline.com/cookadam.co.uk/oauth2/v2.0/token"
    Method      = "POST"
    Body        = $ReqTokenBody
    ContentType = "application/x-www-form-urlencoded"
}

$TokenResponse = Invoke-GraphWebRequest @InvokeGraphWebRequest | Select-Object -ExpandProperty "Content" | ConvertFrom-Json

$InvokeGraphWebRequest = @{
    Uri         = 'https://graph.microsoft.com/v1.0/groups?$select=id,resourceProvisioningOptions'
    Method      = "GET"
    ContentType = "application/json"
    Headers     = @{
        Authorization = "Bearer {0}" -f $TokenResponse.access_token
    }
}
$Response = Invoke-GraphWebRequest @InvokeGraphWebRequest

$Groups = ($Response.Content | ConvertFrom-Json).value
$Teams = $Groups.Where{$_.resourceProvisioningOptions -contains "Team"}

$Channels = foreach ($Team in $Teams) {
    $InvokeGraphWebRequest = @{
        Uri         = 'https://graph.microsoft.com/v1.0//teams/{0}/channels' -f $Team.id
        Method      = "GET"
        ContentType = "application/json"
        Headers     = @{
            Authorization = "Bearer {0}" -f $TokenResponse.access_token
        }
    }
    $Response = Invoke-GraphWebRequest @InvokeGraphWebRequest
    ($Response.Content | ConvertFrom-Json).value
}

$Messages = foreach ($Channel in $Channels) {
    $InvokeGraphWebRequest = @{
        Uri         = 'https://graph.microsoft.com/v1.0//teams/{0}/channels/{1}/messages' -f $Team.id, $Channel.id
        Method      = "GET"
        ContentType = "application/json"
        Headers     = @{
            Authorization = "Bearer {0}" -f $TokenResponse.access_token
        }
    }
    $Response = Invoke-GraphWebRequest @InvokeGraphWebRequest
    ($Response.Content | ConvertFrom-Json).value
}