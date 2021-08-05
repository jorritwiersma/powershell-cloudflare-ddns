#########################################
#                                       #
# Cloudflare DDNS powershell script     #
#                                       #
# Author : Jorrit Wiersma               #
#                                       #
#########################################

# Cloudflare token

$CFtoken = "API-TOKEN-HERE"

# Permissions:
#   Zone | Zone | Read
#   Zone | DNS  | Edit

#########################################
$CFbaseuri = "https://api.cloudflare.com/client/v4/zones/"
$CFheaders = @{
    'Authorization' = "Bearer $CFtoken" 
    "Content-Type" = "application/json"
}
try {$PublicIP = (Invoke-WebRequest -uri 'https://api.ipify.org/' -UseBasicParsing).Content}catch{Write-Error "Cannot collect public ip information" ; Exit}
Write-Host "INFO: Current public IP: $PublicIP" -ForegroundColor Green
try {$CFZones = (Invoke-RestMethod -uri $CFbaseuri -Method GET -Headers $CFheaders).Result}catch{Write-Error "Cannot collect Cloudflare information" ; Exit}
Foreach ($CFzone in $CFZones){ 
    try {$CFmainDomainRecord = (Invoke-RestMethod -uri ($CFbaseuri + $CFzone.id + "/dns_records") -Method GET -Headers $CFheaders).result | where-object {$_.name -eq $CFzone.name}}catch{Write-Error "Cannot collect (Cloudflare) DNS information" ; Exit}
    if ($null -ne $CFmainDomainRecord){
        Write-Host "INFO: Record $($CFZone.name) found" -ForegroundColor Green
        if ($CFmainDomainRecord.content -ne $PublicIP){
            Write-Host "INFO: - IP has changed!" -ForegroundColor Yellow
            $CFBody = @{
                "type" = "A"
                "name" = $CFmainDomainRecord.name
                "content" = $PublicIP
                "ttl" = "1"
                "proxied" = $CFmainDomainRecord.proxied
            }
            $CFBodyJSON = $CFBody | ConvertTo-Json
            Write-Host "EXEC: - Updating record" -ForegroundColor Yellow
            try {$CFDNSrecordChange = (Invoke-RestMethod -uri ($CFbaseuri + $CFzone.id + "/dns_records/" + $CFmainDomainRecord.id) -Method Patch -Headers $CFheaders -body $CFBodyJSON).result}catch {Write-Error "Cannot update (Cloudflare) DNS record information" ; Exit}
            Write-Host "EXEC: - Successfully updated!" -ForegroundColor Yellow
        }
        else{
            Write-Host "INFO: - IP is up-to-date" -ForegroundColor Green
        }
    }
    else{
        Write-Host "INFO: Record $($CFZone.name) not found!" -ForegroundColor Green
        $CFBody = @{
            "type" = "A"
            "name" = $CFZone.name
            "content" = $PublicIP
            "ttl" = "1"
            "proxied" = $true
        }
        $CFBodyJSON = $CFBody | ConvertTo-Json
        Write-Host "EXEC: - Creating record" -ForegroundColor Yellow
        try {$CFDNSrecordCreate = (Invoke-RestMethod -uri ($CFbaseuri + $CFzone.id + "/dns_records") -Method POST -Headers $CFheaders -Body $CFBodyJSON)}catch {Write-Error "Cannot create (Cloudflare) DNS record information" ; Exit}
        Write-Host "EXEC: - Successfully created" -ForegroundColor Yellow
    }
}
