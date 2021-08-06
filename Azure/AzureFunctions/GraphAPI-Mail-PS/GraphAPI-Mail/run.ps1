
using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

$Data = $Request.RawBody | ConvertFrom-Json

Write-Host "Printing POST'ed data"
foreach ($item in $Data.PSObject.Properties) {
    Write-Host ("- {0}: {1}" -f $item, $Data.$item)
}

Write-Host "Requesting access token"

$ReqTokenBody = @{
    Grant_Type    = "client_credentials"
    Scope         = "https://graph.microsoft.com/.default"
    Client_Id     = $env:AAD_APP_ID
    Client_Secret = $env:AAD_APP_SECRET
}

$InvokeGraphWebRequest = @{
    Uri         = "https://login.microsoftonline.com/$env:AAD_TENANT_NAME/oauth2/v2.0/token"
    Method      = "POST"
    Body        = $ReqTokenBody
}

$TokenResponse = Invoke-GraphWebRequest @InvokeGraphWebRequest | Select-Object -ExpandProperty "Content" | ConvertFrom-Json

Write-Host "Creating message"

$Body = [ordered]@{
    Subject = "Hello world"
    Importance = "Low"
    Body = [PSCustomObject]@{
        ContentType = "HTML"
        Content = "This is a message from GraphAPI-Mail-PS"
    }
    ToRecipients = @(
        [PSCustomObject]@{
            EmailAddress = [PSCustomObject]@{
                Address = $env:AAD_USER
            }
        }
    )
}

$InvokeGraphWebRequest = @{
    Uri         = "https://graph.microsoft.com/v1.0/users/{0}/messages" -f $env:AAD_USER
    Method      = "POST"
    Body        = $Body
    ContentType = "application/json"
    Headers     = @{
        Authorization = "Bearer {0}" -f $TokenResponse.access_token
    }
}

$Response = Invoke-GraphWebRequest @InvokeGraphWebRequest | Select-Object -ExpandProperty Content | ConvertFrom-Json

Write-Host ("Message ID: '{0}'" -f $Response.id)

# The below code just updates properties for the newly created draft
# Leaving it in-place, but commented out, just for completeness as example code

<#
Write-Host "Updating message"

$Body = [ordered]@{
    Importance = "Low"
    replyTo = @(
        [PSCustomObject]@{
            EmailAddress = [PSCustomObject]@{
                Address = "someother@emailaddress.com"
            }
        }
    )
}

$InvokeGraphWebRequest = @{
    Uri         = "https://graph.microsoft.com/v1.0/users/{0}/messages/{1}" -f $env:AAD_USER, $Response.id
    Method      = "PATCH"
    Body        = $Body
    ContentType = "application/json"
    Headers     = @{
        Authorization = "Bearer {0}" -f $TokenResponse.access_token
    }
}

$Response = Invoke-GraphWebRequest @InvokeGraphWebRequest | Select-Object -ExpandProperty Content | ConvertFrom-Json
#>

Write-Host "Sending message"

$InvokeGraphWebRequest = @{
    Uri         = "https://graph.microsoft.com/v1.0/users/{0}/messages/{1}/send" -f $env:AAD_USER, $Response.id
    Method      = "POST"
    Headers     = @{
        Authorization = "Bearer {0}" -f $TokenResponse.access_token
    }
}

$Response = Invoke-GraphWebRequest @InvokeGraphWebRequest | Select-Object -ExpandProperty Content | ConvertFrom-Json

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [System.NET.HttpStatusCode]::OK
})

Write-Host "Finished"
