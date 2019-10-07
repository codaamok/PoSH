Function Get-CloudflareZoneID {
    param (
        # Parameter help description
        [Parameter(Mandatory=$true)]
        [string]
        $Email,
        # Parameter help description
        [Parameter(Mandatory=$true)]
        [string]
        $Key,
        # Parameter help description
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )
    try {
        $URL = ("https://api.cloudflare.com/client/v4/zones?name={0}" -f $Name)
        $invokeRestMethodSplat = @{
            Headers = @{"X-Auth-Email" = $Email; "X-Auth-Key" = $Key; "Content-Type" = "application/json"}
            Method = "GET"
            Uri = $URL
        }
        $id = Invoke-RestMethod @invokeRestMethodSplat | Select-Object -ExpandProperty result | Select-Object -ExpandProperty id
    }
    catch {
        Throw $error[0]
    }
    return $id
}

Function Get-CloudflareDNSARecord {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Mandatory=$true)]
        [string]
        $Email,
        # Parameter help description
        [Parameter(Mandatory=$true)]
        [string]
        $Key,
        # Parameter help description
        [Parameter(Mandatory=$true)]
        [string]
        $ZoneID,
        # Parameter help description
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string[]]
        $Domains
    )
    Process {
        ForEach ($Domain in $Domains) {
            try {
                $URL = ("https://api.cloudflare.com/client/v4/zones/{0}/dns_records?type=A&name={1}" -f $ZoneID, $Domain)
                $invokeRestMethodSplat = @{
                    Headers = @{"X-Auth-Email" = $Email; "X-Auth-Key" = $Key; "Content-Type" = "application/json"}
                    Method = "GET"
                    Uri = $URL
                }
                $r = Invoke-RestMethod @invokeRestMethodSplat | Select-Object -ExpandProperty result
                [PSCustomObject]@{
                    Name    = $r.Name
                    ID      = $r.ID
                }
            }
            catch {
                Write-Warning ("Could not get DNS record for `"{0}`": {1}" -f $Domain, $error[0].Exception.Message)
            }
        }
    }
}

Function Update-CloudflareDNSARecord {
    param (
        # Parameter help description
        [Parameter(Mandatory=$true)]
        [string]
        $Email,
        # Parameter help description
        [Parameter(Mandatory=$true)]
        [string]
        $Key,
        # Parameter help description
        [Parameter(Mandatory=$true)]
        [string]
        $ZoneID,
        # Record ID + name
        [Parameter(Mandatory=$true)]
        [pscustomobject]
        $Domain,
        # Parameter help description
        [Parameter(Mandatory=$true)]
        [string]
        $IP,
        # Parameter help description
        [Parameter(Mandatory=$false)]
        [switch]
        $Proxied
    )
    try {
        $URL = ("https://api.cloudflare.com/client/v4/zones/{0}/dns_records/{1}" -f $ZoneID, $Domain.ID)
        $invokeRestMethodSplat = @{
            Headers = @{"X-Auth-Email" = $Email; "X-Auth-Key" = $Key; "Content-Type" = "application/json"}
            Method = "PUT"
            Body = (@{"type" = "A"; "name" = $Domain.Name; "content" = $IP; "proxied" = $Proxied.IsPresent} | ConvertTo-Json -Compress)
            Uri = $URL
        }
        Invoke-RestMethod @invokeRestMethodSplat
    }
    catch {
        Write-Warning ("Could not update DNS record for `"{0}`": {1}" -f $Domain, $error[0].Exception.Message)
    }
}

# https://api.cloudflare.com/

$APIKEY = "x"
$email = "example@domain.com"
$IPAddress = Invoke-WebRequest -uri "https://ident.me" | Select-Object -ExpandProperty Content
$CloudflareZoneName = "domain.com"
$Domains = @(
    "www.domain.com",
    "domain.com"
)

$CloudflareZoneID = Get-CloudflareZoneID -Email $email -Key $APIKEY -Name $CloudflareZoneName

$CloudflareDomainRecs = Get-CloudflareDNSARecord -Email $email -Key $APIKEY -ZoneID $CloudflareZoneID -Domains $Domains

$CloudflareDomainRecs | ForEach-Object {
    Update-CloudflareDNSARecord -Email $email -Key $APIKEY -ZoneID $CloudflareZoneID -Domain $_ -IP $IPAddress -Proxied:$true
}