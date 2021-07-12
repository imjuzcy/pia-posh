# If the server list has less than 1000 characters, it means curl failed.
function check_all_region_data {
  Write-Host
  Write-Host "Getting the server list..." -NoNewline
  
  if ($all_region_data.length -lt 1000) {
    Write-Host -ForegroundColor Red "Could not get correct region data. To debug this, run:"
    Write-Host -ForegroundColor Red "$ curl -v $serverlist_url"
    Write-Host -ForegroundColor Red "If it works, you will get a huge JSON as a response."
    exit 1
  }

  # Notify the user that we got the server list.
  Write-Host -ForegroundColor Green "OK!
  "
}

# Get all data for the selected region
# Exit with code 1 if the REGION_ID provided is invalid
function get_selected_region_data {
  $script:regionData = foreach ($region in ($all_region_data | ConvertFrom-Json).regions) {if ($region.id -eq $selectedRegion) {$region}}
  if (-Not $regionData) {
    Write-Host -ForegroundColor Red "The REGION_ID $selectedRegion is not valid.
    "
    exit 1
  }  
}

New-Item -Path "$env:USERPROFILE\piavpn-manual" -ItemType "Directory" -Force | Out-Null
# Erase old latencyList file
Remove-Item -Path "$env:USERPROFILE\piavpn-manual\latencyList" -ErrorAction SilentlyContinue
New-Item -Path "$env:USERPROFILE\piavpn-manual\latencyList" -ItemType "File" | Out-Null

# This allows you to set the maximum allowed latency in seconds.
# All servers that respond slower than this will be ignored.
# You can inject this with the environment variable MAX_LATENCY.
# The default value is 50 milliseconds.
if (-Not $MAX_LATENCY) {
  $MAX_LATENCY = 0.05
}

$serverlist_url = 'https://serverlist.piaservers.net/vpninfo/servers/v4'

# This function checks the latency you have to a specific region.
# It will print a human-readable message to stderr,
# and it will print the variables to stdout
function printServerLatency {
  param (
    [Parameter(Position=0)]
    [string]
    $serverIP,

    [Parameter(Position=1)]
    [string]
    $regionID,

    [Parameter(Position=2)]
    [string]
    $regionName
  )
  
  $regionName = $regionName -replace " False","" -replace "True","(geo)"
  ###### CURL.EXE USES LOCALE'S DECIMAL BUT $MAX_LATENCY PASS DOT AS DECIMAL #####
  $time = Invoke-Expression -Command 'curl.exe -o NUL -s --connect-timeout 0,05 --write-out "%{time_connect}" http://$($serverIP):443'

  if ($?) {
    Write-Host "Got latency ${time}s for region: $regionName"
    $time, $regionID, $serverIP -join " "
    # Write a list of servers with acceptable latancy
    # to $env:USERPROFILE\piavpn-manual\latencyList
    "$time $regionID`t$serverIP`t$regionName" | Add-Content -Path "$env:USERPROFILE\piavpn-manual\latencyList"
  }
  # Sort the latencyList, ordered by latency
  Get-Content "$env:USERPROFILE\piavpn-manual\latencyList" | Sort-Object {[int]$_} | Get-Unique | Out-File "$env:USERPROFILE\piavpn-manual\latencyList"
}

# If a server location or autoconnect isn't specified, set the variable to false/no.

if (-Not $PREFERRED_REGION) {
  $PREFERRED_REGION = "none"
}
if (-Not $VPN_PROTOCOL) {
  $VPN_PROTOCOL = "no"
}

# Get all region data
$all_region_data = Invoke-Expression -Command "curl.exe -s $serverlist_url" | Select-Object -First 1

# Set the region the user has specified
$selectedRegion = $PREFERRED_REGION

# If a server isn't being specified, auto-select the server with the lowest latency
if ($selectedRegion -eq "none") {
  $selectedOrLowestLatency = "lowest latency"
  check_all_region_data

  # Making sure this variable doesn't contain some strange string
  if ($PIA_PF -ne $true) {
    $PIA_PF = $false
  }

  # Test one server from each region to get the closest region.
  # If port forwarding is enabled, filter out regions that don't support it.
  if ($PIA_PF) {
    Write-Host "Port Forwarding is enabled, non-PF servers excluded."
    Write-Host
    $summarized_region_data = @(foreach ($region in ($all_region_data | ConvertFrom-Json).regions) {if ($region.port_forward) {$region.servers.meta[0].ip + " " + $region.id + " " + $region.name + " " + $region.geo}})
  }
  else {
    $summarized_region_data = @(foreach ($region in ($all_region_data | ConvertFrom-Json).regions) {$region.servers.meta[0].ip + " " + $region.id + " " + $region.name + " " + $region.geo})
  }
  Write-Host "Testing regions that respond
  faster than " -NoNewline; Write-Host -ForegroundColor Green "$MAX_LATENCY" -NoNewline; Write-Host " seconds:"
  $results = foreach ($region in $summarized_region_data) {$regionArr = $region -split " " ;printServerLatency $regionArr[0] $regionArr[1] ($regionArr[2..($regionArr.length - 1)] -join " ")} 
  $selectedRegion = (($results | Sort-Object | Select-Object -First 1) -split " " )[1]
  Write-Host

  if (-Not $selectedRegion) {
    Write-Host -ForegroundColor Red "No region responded within ${MAX_LATENCY}s, consider using a higher timeout."
    Write-Host -ForegroundColor Red "For example, to wait 1 second for each region, inject MAX_LATENCY=1 like this:"
    Write-Host -ForegroundColor Red "$ MAX_LATENCY=1 ./get_region.sh"
    exit 1
  }
  else {
    Write-Host "A list of servers and connection details, ordered by latency can be 
found in at : " -NoNewline; Write-Host -ForegroundColor Green "/opt/piavpn-manual/latencyList
"
  }
}
else {
  $selectedOrLowestLatency = "selected"
  check_all_region_data
}

get_selected_region_data

$bestServer_meta_IP = $regionData.servers.meta[0].ip
$bestServer_meta_hostname = $regionData.servers.meta[0].cn
$bestServer_WG_IP = $regionData.servers.wg[0].ip
$bestServer_WG_hostname = $regionData.servers.wg[0].cn
$bestServer_OT_IP = $regionData.servers.ovpntcp[0].ip
$bestServer_OT_hostname = $regionData.servers.ovpntcp[0].cn
$bestServer_OU_IP = $regionData.servers.ovpnudp[0].ip
$bestServer_OU_hostname = $regionData.servers.ovpnudp[0].cn

if ($VPN_PROTOCOL -eq "no") {
  Write-Host "The $selectedOrLowestLatency region is " -NoNewline; Write-Host -ForegroundColor Green "$($regionData.name)" -NoNewline
  if ($regionData.geo) {
    Write-Host " (geolocated region)."
  }
  else {
    Write-Host "."
  }
  Write-Host "
  The script found the best servers from the region you selected.
  When connecting to an IP (no matter which protocol), please verify
  the SSL/TLS certificate actually contains the hostname so that you
  are sure you are connecting to a secure server, validated by the
  PIA authority. Please find below the list of best IPs and matching
  hostnames for each protocol:"
  Write-Host -ForegroundColor Green "  Meta Services $bestServer_meta_IP`t-     $bestServer_meta_hostname
  WireGuard     $bestServer_WG_IP`t-     $bestServer_WG_hostname
  OpenVPN TCP   $bestServer_OT_IP`t-     $bestServer_OT_hostname
  OpenVPN UDP   $bestServer_OU_IP`t-     $bestServer_OU_hostname
  "
}

# The script will check for an authentication token, and use it if present
# If no token exists, the script will check for login credentials to generate one
if (-Not $PIA_TOKEN) {
  if ((-Not $PIA_USER) -or (-Not $PIA_PASS)) {
    Write-Host -ForegroundColor Red "If you want this script to automatically get an authentication"
    Write-Host -ForegroundColor Red "token, please add the variables PIA_USER and PIA_PASS. Example:"
    Write-Host -ForegroundColor Red "$ PIA_USER=p0123456 PIA_PASS=xxx ./get_region.sh"
    exit 0
  }
  ./get_token.ps1
  $PIA_TOKEN = Get-Content -Path "$env:USERPROFILE\piavpn-manual\token" | Select-Object -First 1
  Remove-Item -Path "$env:USERPROFILE\piavpn-manual\token" -ErrorAction SilentlyContinue
}
else {
  Write-Host "Using existing token " -NoNewline; Write-Host -ForegroundColor Green "$PIA_TOKEN" -NoNewline; Write-Host "."
  Write-Host
}

# Connect with WireGuard and clear authentication token file and latencyList
if ($VPN_PROTOCOL -match "wireguard") {
  Write-Host "The ./get_region.ps1 script got started with"
  Write-Host -ForegroundColor Green "VPN_PROTOCOL=wireguard" -NoNewline
  Write-Host ", so we will automatically connect to WireGuard,"
  Write-Host "by running this command:"
  Write-Host "$ " -NoNewline; Write-Host -ForegroundColor Green "PIA_TOKEN=$PIA_TOKEN \"
  Write-Host -ForegroundColor Green "WG_SERVER_IP=$bestServer_WG_IP WG_HOSTNAME=$bestServer_WG_hostname \"
  Write-Host -ForegroundColor Green "PIA_PF=$PIA_PF ./connect_to_wireguard_with_token.sh"
  Write-Host
  $PIA_PF = $PIA_PF; $PIA_TOKEN = $PIA_TOKEN; $WG_SERVER_IP = $bestServer_WG_IP; $WG_HOSTNAME = $bestServer_WG_hostname; ./connect_to_wireguard_with_token.ps1
  Remove-Item -Path "$env:USERPROFILE/piavpn-manual/latencyList" -ErrorAction SilentlyContinue
  exit 0
}

# Connect with OpenVPN and clear authentication token file and latencyList
if ($VPN_PROTOCOL -match "openvpn") {
  $serverIP = $bestServer_OU_IP
  $serverHostname = $bestServer_OU_hostname
  if ($VPN_PROTOCOL -match "tcp") {
    $serverIP = $bestServer_OT_IP
    $serverHostname = $bestServer_OT_hostname
  }
  Write-Host "The ./get_region.sh script got started with"
  Write-Host -ForegroundColor Green "VPN_PROTOCOL=$VPN_PROTOCOL$" -NoNewline; Write-Host ", so we will automatically"
  Write-Host "connect to OpenVPN, by running this command:"
  Write-Host "> " -NoNewline; Write-Host -ForegroundColor Green "PIA_PF=$PIA_PF PIA_TOKEN=$PIA_TOKEN;"
  Write-Host -ForegroundColor Green "$OVPN_SERVER_IP = $serverIP;"
  Write-Host -ForegroundColor Green "$OVPN_HOSTNAME = $serverHostname;"
  Write-Host -ForegroundColor Green "$CONNECTION_SETTINGS = $VPN_PROTOCOL;"
  Write-Host -ForegroundColor Green "./connect_to_openvpn_with_token.ps1"
  Write-Host
  $PIA_PF = $PIA_PF; $PIA_TOKEN = $PIA_TOKEN; $OVPN_SERVER_IP = $serverIP; $OVPN_HOSTNAME = $serverHostname; $CONNECTION_SETTINGS = $VPN_PROTOCOL; ./connect_to_openvpn_with_token.ps1
  Remove-Item -Path "$env:USERPROFILE/piavpn-manual/latencyList" -ErrorAction SilentlyContinue
  exit 0
}