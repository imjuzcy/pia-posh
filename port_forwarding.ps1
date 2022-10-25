
# Check if the mandatory environment variables are set.
if ((-Not $PF_GATEWAY) -or (-Not $PIA_TOKEN) -or (-Not $PF_HOSTNAME)) {
  Write-Host "This script requires 3 env vars:"
  Write-Host "PF_GATEWAY  - the IP of your gateway"
  Write-Host "PF_HOSTNAME - name of the host used for SSL/TLS certificate verification"
  Write-Host "PIA_TOKEN   - the token you use to connect to the vpn services"
  Write-Host
  Write-Host "An easy solution is to just run get_region_and_token.ps1"
  Write-Host "as it will guide you through getting the best server and"
  Write-Host "also a token. Detailed information can be found here:"
  Write-Host "https://github.com/imjuzcy/pia-posh"
  exit 1
}

# The port forwarding system has required two variables:
# PAYLOAD: contains the token, the port and the expiration date
# SIGNATURE: certifies the payload originates from the PIA network.

# Basically PAYLOAD+SIGNATURE=PORT. You can use the same PORT on all servers.
# The system has been designed to be completely decentralized, so that your
# privacy is protected even if you want to host services on your systems.

# You can get your PAYLOAD+SIGNATURE with a simple curl request to any VPN
# gateway, no matter what protocol you are using. Considering WireGuard has
# already been automated in this repo, here is a command to help you get
# your gateway if you have an active OpenVPN connection:
# $ ip route | head -1 | grep tun | awk '{ print $3 }'
# This section will get updated as soon as we created the OpenVPN script.

# Get the payload and the signature from the PF API. This will grant you
# access to a random port, which you can activate on any server you connect to.
# If you already have a signature, and you would like to re-use that port,
# save the payload_and_signature received from your previous request
# in the env var PAYLOAD_AND_SIGNATURE, and that will be used instead.
if ((-Not $PAYLOAD_AND_SIGNATURE)) {
  Write-Host
  Write-Host -NoNewline "Getting new signature... "
  $payload_and_signature = Invoke-Expression -Command 'curl.exe -k -s -G --connect-to "$($PF_HOSTNAME)::$($PF_GATEWAY):" --cacert "ca.rsa.4096.crt" --data-urlencode "token=$($PIA_TOKEN)" "https://$($PF_HOSTNAME):19999/getSignature"'

}
else {
  $payload_and_signature=$PAYLOAD_AND_SIGNATURE
  Write-Host -NoNewline "Checking the payload_and_signature from the env var... "
}

# Powershell extra: convert into JSON object
$payload_and_signature_json = $payload_and_signature | ConvertFrom-Json

# Check if the payload and the signature are OK.
# If they are not OK, just stop the script.
if ($payload_and_signature_json.status -ne "OK") {
  Write-Host -ForegroundColor Red "The payload_and_signature variable does not contain an OK status."
  exit 1
}
Write-Host -ForegroundColor Green "OK!"

# We need to get the signature out of the previous response.
# The signature will allow the us to bind the port on the server.
$signature = $payload_and_signature_json.signature

# The payload has a base64 format. We need to extract it from the
# previous response and also get the following information out:
# - port: This is the port you got access to
# - expires_at: this is the date+time when the port expires
$payload = $payload_and_signature_json.payload
$payload_json = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($payload)) | ConvertFrom-JSON
$port = $payload_json.port

# The port normally expires after 2 months. If you consider
# 2 months is not enough for your setup, please open a ticket.
$expires_at = $payload_json.expires_at

Write-Host -NoNewline "
Signature "; Write-Host -NoNewline -ForegroundColor Green $signature;
Write-Host -NoNewline "Payload"; Write-Host -NoNewline -ForegroundColor Green $payload
Write-Host -NoNewline "--> The port is "; Write-Host -NoNewline -ForegroundColor Green $port; Write-Host -NoNewline "and it will expire on "; Write-Host -NoNewline -ForegroundColor Red $expires_at; Write-Host -NoNewline ". <--
Trying to bind the port... "

# Now we have all required data to create a request to bind the port.
# We will repeat this request every 15 minutes, in order to keep the port
# alive. The servers have no mechanism to track your activity, so they
# will just delete the port forwarding if you don't send keepalives.
while ($true) {
  $bind_port_response = Invoke-Expression -Command 'curl.exe -k -G --connect-to "$($PF_HOSTNAME)::$($PF_GATEWAY):" --cacert "ca.rsa.4096.crt" --data-urlencode "payload=$($payload)" --data-urlencode "signature=$($signature)" "https://$($PF_HOSTNAME):19999/bindPort"'
  Write-Host -ForegroundColor Green "OK!"

  # If port did not bind, just exit the script.
  # This script will exit in 2 months, since the port will expire.
  $bind_port_response_json = $bind_port_response | ConvertFrom-JSON
  if ($bind_port_response_json.status -ne "OK") {
      Write-Host -ForegroundColor Red "The API did not return OK when trying to bind port... Exiting."
      exit 1
  }
  Write-Host -NoNewline "Forwarded port'\t'"; Write-Host -ForegroundColor Green "$port"
  Write-Host -NoNewline "Refreshed on'\t'"; Write-Host -ForegroundColor Green "$(date)"
  Write-Host -NoNewline "Expires on'\t'"; Write-Host -ForegroundColor Red "$(date -Date "$expires_at")"
  Write-Host
  Write-Host -ForegroundColor Green "This script will need to remain active to use port forwarding, and will refresh every 15 minutes."
  Write-Host

  # sleep 15 minutes
  Start-Sleep 900
}