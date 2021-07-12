# Disable tunnel service in case it's blocking the Internet for new connections
if ((Invoke-Expression -Command "wg.exe show" | Select-Object -First 1) -eq "interface: pia") {
  Invoke-Expression -Command "wireguard.exe /uninstalltunnelservice pia"
  Start-Sleep 1
  Write-Host -ForegroundColor Green "WG connection disabled!"
}

# Wait for Internet connection before running script
do {
  $ping = test-connection -comp privateinternetaccess.com -count 1 -Quiet
} until ($ping)

# Set-Location "C:\Users\chanyun\Downloads\manual-connections-2.0.0\PS_Translate"
$PIA_USER = ""
$PIA_PASS = ""
$PIA_DNS = "true"
$PIA_PF = "false"
$PREFERRED_REGION = "de-frankfurt"
$AUTOCONNECT = "false"
$VPN_PROTOCOL = "wireguard"
$DISABLE_IPV6 = "no"
$MAX_LATENCY = "0.05"
$LOCAL_NETWORK_BYPASS = "true"
$ALLOWED_IPS = ""
./run_setup.ps1