if ([System.Environment]::OSVersion.Platform -ne "Win32NT") {
  Write-Host -ForegroundColor Red "This script can only be run on Windows. For Linux, please use the bash script."
  exit 1
}

# PIA currently does not support IPv6. In order to be sure your VPN
# connection does not leak, it is best to disabled IPv6 altogether.
Write-Host "PIA currently does not support IPv6. In order to be sure your VPN"
Write-Host "connection does not leak, it is best to disabled IPv6 altogether."

# Check if the mandatory environment variables are set.
if ((-Not $WG_SERVER_IP) -or (-Not $WG_HOSTNAME) -or (-Not $PIA_TOKEN)) {
  Write-Host -ForegroundColor Red "This script requires 3 env vars:"
  Write-Host -ForegroundColor Red "WG_SERVER_IP - IP that you want to connect to"
  Write-Host -ForegroundColor Red "WG_HOSTNAME  - name of the server, required for ssl"
  Write-Host -ForegroundColor Red "PIA_TOKEN    - your authentication token"
  Write-Host
  Write-Host -ForegroundColor Red "You can also specify optional env vars:"
  Write-Host -ForegroundColor Red "PIA_PF                - enable port forwarding"
  Write-Host -ForegroundColor Red "PAYLOAD_AND_SIGNATURE - In case you already have a port."
  Write-Host
  Write-Host -ForegroundColor Red "An easy solution is to just run get_region_and_token.ps1"
  Write-Host -ForegroundColor Red "as it will guide you through getting the best server and"
  Write-Host -ForegroundColor Red "also a token. Detailed information can be found here:"
  Write-Host -ForegroundColor Red "https://github.com/pia-foss/manual-connections"
  exit 1
}

# Create ephemeral wireguard keys, that we don't need to save to disk.
$privKey = wg genkey
$pubKey = $privKey | wg pubkey

# Authenticate via the PIA WireGuard RESTful API.
# This will return a JSON with data required for authentication.
# The certificate is required to verify the identity of the VPN server.
# In case you didn't clone the entire repo, get the certificate from:
# https://github.com/pia-foss/manual-connections/blob/master/ca.rsa.4096.crt
# In case you want to troubleshoot the script, replace -s with -v.
Write-Host "Trying to connect to the PIA WireGuard API on $WG_SERVER_IP..."
##### -k has to be used because cacert is untrusted (?) ######
$wireguard_json = Invoke-Expression -Command 'curl.exe -k -s -G --connect-to "$($WG_HOSTNAME)::$($WG_SERVER_IP):" --cacert "ca.rsa.4096.crt" --data-urlencode "pt=$($PIA_TOKEN)" --data-urlencode "pubkey=$($pubKey)" "https://$($WG_HOSTNAME):1337/addKey"' | ConvertFrom-Json

# Check if the API returned OK and stop this script if it didn't.
if ($wireguard_json.status -ne "OK") {
  Write-Error "Server did not return OK. Stopping now."
  exit 1
}

# Multi-hop is out of the scope of this repo, but you should be able to
# get multi-hop running with both WireGuard and OpenVPN by playing with
# these scripts. Feel free to fork the project and test it out.
Write-Host
Write-Host "Trying to disable a PIA WG connection in case it exists..."
if ((Invoke-Expression -Command "wg.exe show" | Select-Object -First 1) -eq "interface: pia") {
  Invoke-Expression -Command "wireguard.exe /uninstalltunnelservice pia"
  Start-Sleep 1
  Write-Host -ForegroundColor Green "PIA WG connection disabled!"
}

# Create the WireGuard config based on the JSON received from the API
# In case you want this section to also add the DNS setting, please
# start the script with PIA_DNS=true.
# This uses a PersistentKeepalive of 25 seconds to keep the NAT active
# on firewalls. You can remove that line if your network does not
# require it.
if ($PIA_DNS) {
  $dnsServer = $wireguard_json.dns_servers[0]
  Write-Host "Trying to set up DNS to $dnsServer."
  Write-Host
  $dnsSettingForVPN = "DNS = $dnsServer"
}

Write-Host "Trying to write $env:USERPROFILE\piavpn-manual\wireguard\pia.conf..."
New-Item -Path "$env:USERPROFILE\piavpn-manual\wireguard" -ItemType "Directory" -ErrorAction SilentlyContinue
"[Interface]
Address = $($wireguard_json.peer_ip)
PrivateKey = $privKey
$dnsSettingForVPN
[Peer]
PersistentKeepalive = 25
PublicKey = $($wireguard_json.server_key)
AllowedIPs = 0.0.0.0/0
Endpoint = ${WG_SERVER_IP}:$($wireguard_json.server_port)" | Out-File "$env:USERPROFILE\piavpn-manual\wireguard\pia.conf"
Write-Host -ForegroundColor Green "OK!"

# Start the WireGuard interface.
# If something failed, stop this script.
Write-Host
Write-Host "Trying to create the wireguard interface..."
Invoke-Expression -Command "wireguard.exe /installtunnelservice $env:USERPROFILE\piavpn-manual\wireguard\pia.conf"
if (-Not $?) {
  exit 1
}
Write-Host
Write-Host -ForegroundColor Green "The WireGuard interface got created."
Write-Host "At this point, internet should work via VPN.
The Wireguard GUI might not be showing accurate information
about the interface, but in the `"Log`" tab it'll show.

To disconnect the VPN, run:

--> " -NoNewline; Write-Host -ForegroundColor Green "wireguard.exe /uninstalltunnelservice pia" -NoNewline; Write-Host " <--"

# This section will stop the script if PIA_PF is not set to "true".
if (-Not $PIA_PF) {
  Write-Host "If you want to also enable port forwarding, you can start the script:"
  Write-Host -ForegroundColor Green "> `$PIA_TOKEN = $PIA_TOKEN; `$PF_GATEWAY = $WG_SERVER_IP; `$PF_HOSTNAME = $WG_HOSTNAME; ./port_forwarding.ps1"
  Write-Host
  Write-Host "The location used must be port forwarding enabled, or this will fail."
  Write-Host "Calling the ./get_region script with `$PIA_PF=true will provide a filtered list."
  exit 1
}

Write-Host "This script got started with " -NoNewline; Write-Host -ForegroundColor Green "`$PIA_PF=true" -NoNewline; Write-Host ".

Starting port forwarding in " -NoNewline

for ($i = 5; $i -gt 0; $i--) {
  Write-Host "$i..." -NoNewline
  Start-Sleep 1
}

Write-Host
Write-Host

Write-Host "Starting procedure to enable port forwarding by running the following command:
> " -NoNewline; Write-Host -ForegroundColor Green "`$PIA_TOKEN = $PIA_TOKEN; `$PF_GATEWAY = $WG_SERVER_IP; `$PF_HOSTNAME = $WG_HOSTNAME; ./port_forwarding.ps1"

$PIA_TOKEN = $PIA_TOKEN
$PF_GATEWAY = $WG_SERVER_IP
$PF_HOSTNAME = $WG_HOSTNAME
Invoke-Expression -Command "./port_forwarding.ps1"