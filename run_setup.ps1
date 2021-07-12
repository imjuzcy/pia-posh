# Variables to use for validating input
$intCheck = "^[0-9]+$"
$floatCheck = '^[0-9]+([.][0-9]+)?$'

# Only allow script to run as admin
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-Not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Error -ForegroundColor Red "This script needs to be run with administrator privileges."
  exit 1
}

# Erase previous authentication token if present
Remove-Item -Path "$env:USERPROFILE\piavpn-manual\*" -Include token, latencyList -ErrorAction SilentlyContinue

# Retry login if no token is generated
while ($true) {
  while ($true) {
    # Check for in-line definition of $PIA_USER
    if (-Not $PIA_USER) {
      Write-Host
      $PIA_USER = Read-Host -Prompt "PIA username (p#######)"
    }

    # Confirm format of PIA_USER input
    $unPrefix = $PIA_USER.Substring(0,1)
    $unSuffix = $PIA_USER.Substring(1)
    if (-Not $PIA_USER) {
      Write-Host -ForegroundColor Red "You must provide input." 
    }
    elseif ($PIA_USER.Length -ne 8) {
      Write-Host -ForegroundColor Red "A PIA username is always 8 characters long."
    }
    elseif (($unPrefix -ne "P") -and ($unPrefix -ne "p")) {
      Write-Host -ForegroundColor Red "A PIA username must start with ""p""."
    }
    elseif (-Not ($unSuffix -match $intCheck)) {
      Write-Host -ForegroundColor Red "Username formatting is always p#######!"
    }
    else {
      Write-Host
      Write-Host -ForegroundColor Green "PIA_USER=$PIA_USER"
      break
    }
    $PIA_USER = ""
  }

  while ($true) {
    # Check for in-line definition of $PIA_PASS
    if (-Not $PIA_PASS) {
      Write-Host
      $PIA_PASS = Read-Host -Prompt "PIA password" -AsSecureString
      Write-Host
    }

    # Confirm format of PIA_PASS input
    if (-Not $PIA_PASS) {
      Write-Host -ForegroundColor Red "You must provide input."
    }
    elseif ($PIA_PASS.length -lt 8) {
      Write-Host -ForegroundColor Red "A PIA password is always a minimum of 8 characters long."
    }
    else {
      Write-Host -ForegroundColor Green "PIA_PASS input received."
      Write-Host
      break
    }
    $PIA_PASS = ""
  }

  # Confirm credentials and generate token
 .\get_token.ps1

  $tokenLocation = "$env:USERPROFILE\piavpn-manual\token"
  # If the script failed to generate an authentication token, the script will exit early.
  if (-Not (Test-Path $tokenLocation -PathType leaf)) {
    $tryAgain = Read-Host -Prompt "Do you want to try again ([N]o/[y]es)"
    if (-Not ($tryAgain.Substring(0,1) -eq "y")) {
      exit 1
    }
    $PIA_USER = ""
    $PIA_PASS = ""
  }
  else {
    $PIA_TOKEN = Get-Content $tokenLocation -First 1
    Remove-Item $tokenLocation -ErrorAction SilentlyContinue
    break
  }
}

# Check for in-line definition of PIA_PF and prompt for input
if (-Not $PIA_PF) {
  $portForwarding = Read-Host -Prompt "Do you want a forwarding port assigned ([N]o/[y]es)"
  Write-Host
  if ($portForwarding.Substring(0,1) -eq "y") {
    $PIA_PF = $true
  }
}
if ($PIA_PF -ne $true) {
  $PIA_PF = $false
}
Write-Host -ForegroundColor Green "`$PIA_PF = $PIA_PF"
Write-Host

# Check for in-line definition of DISABLE_IPV6 and prompt for input
if (-Not $DISABLE_IPV6) {
  Write-Host "Having active IPv6 connections might compromise security by allowing"
  Write-Host "split tunnel connections that run outside the VPN tunnel."
  $DISABLE_IPV6 = Read-Host -Prompt "Do you want to disable IPv6? (Y/n)"
  Write-Host
}

if ($DISABLE_IPV6.Substring(0,1) -eq "n") {
  Write-Host -ForegroundColor Red "IPv6 settings have not been altered."
}
else {
  Write-Host -ForegroundColor Green "The variable " -NoNewline; Write-Host -ForegroundColor Green "DISABLE_IPV6=$DISABLE_IPV6" -NoNewline; Write-Host ", does not start with 'n' for 'no'."
  Write-Host -ForegroundColor Green "Defaulting to yes."
  Get-NetAdapter | ForEach-Object { Disable-NetAdapterBinding -InterfaceAlias $_.Name -ComponentID ms_tcpip6 }
  
  Write-Host
  Write-Host -ForegroundColor Red "IPv6 has been disabled" -NoNewline; Write-Host ", you can " -NoNewline; Write-Host -ForegroundColor Green "enable it again with: "
  Write-Host -ForegroundColor Green "Get-NetAdapter | foreach { Enable-NetAdapterBinding -InterfaceAlias `$_.Name -ComponentID ms_tcpip6 }"
  Write-Host -ForegroundColor Green "or turn it on in Control Panel."
  Write-Host
}

# Input validation and check for conflicting declartions of AUTOCONNECT and PREFERRED_REGION
# If both variables are set, AUTOCONNECT has superiority and PREFERRED_REGION is ignored
if (-Not $AUTOCONNECT) {
  Write-Host "AUTOCONNECT was not declared."
  Write-Host
  $selectServer = "ask"
}
elseif ($AUTOCONNECT.Substring(0,1) -eq "f") {
  if ($AUTOCONNECT -ne "false") {
    Write-Host "The variable " -NoNewline; Write-Host -ForegroundColor Green "AUTOCONNECT=$AUTOCONNECT" -NoNewline; Write-Host ", starts with 'f' for 'false'."
    $AUTOCONNECT = "false"
    Write-Host "Updated " -NoNewline; Write-Host -ForegroundColor Green "AUTOCONNECT=$AUTOCONNECT"
    Write-Host
  }
  $selectServer="yes"
}
else {
  if ($AUTOCONNECT -ne "true") {
    Write-Host "The variable " -NoNewline; Write-Host -ForegroundColor Green "AUTOCONNECT=$AUTOCONNECT" -NoNewline; Write-Host ", does not start with 'f' for 'false'."
    $AUTOCONNECT = "true"
    Write-Host "Updated " -NoNewline; Write-Host -ForegroundColor Green "AUTOCONNECT=$AUTOCONNECT"
    Write-Host
  }
  if (-Not $PREFERRED_REGION) {
    Write-Host -ForegroundColor Green "AUTOCONNECT=true"
    Write-Host
  }
  else {
    Write-Host
    Write-Host "AUTOCONNECT supercedes in-line definitions of PREFERRED_REGION."
    Write-Host -ForegroundColor Red "PREFERRED_REGION=$PREFERRED_REGION will be ignored."
    Write-Host
    $PREFERRED_REGION = ""
  }
  $selectServer = "no"
}

# Prompt the user to specify a server or auto-connect to the lowest latency
while ($true) {
  if (-Not $PREFERRED_REGION) {
    # If autoconnect is not set, prompt the user to specify a server or auto-connect to the lowest latency
    if ($selectServer -eq "ask") {
      $selectServer =  Read-Host -Prompt "Do you want to manually select a server, instead of auto-connecting to the
      server with the lowest latency ([N]o/[y]es)" 
      Write-Host
    }

    # Call the region script with input to create an ordered list based upon latency
    # When $PREFERRED_REGION is set to none, get_region.sh will generate a list of servers
    # that meet the latency requirements speciied by $MAX_LATENCY.
    # When $VPN_PROTOCOL is set to no, get_region.sh will sort that list of servers
    # to allow for numeric selection, or an easy manual review of options.
    if ($selectServer.Substring(0,1) -eq "y") {
    
      # This sets the maximum allowed latency in seconds.
      # All servers that respond slower than this will be ignored.
      if (-Not $MAX_LATENCY) {
        Write-Host "With no input, the maximum allowed latency will be set to 0.05s (50ms).
        If your connection has high latency, you may need to increase this value.
        For example, you can try 0.2 for 200ms allowed latency.
        "
      }
      else {
        $latencyInput = $MAX_LATENCY
      }

      # Assure that input is numeric and properly formatted.
      $MAX_LATENCY = 0.05 # default
      while ($true) {
        if (-Not $latencyInput) {
          $latencyInput = Read-Host -Prompt "Custom latency (no input required for 50ms)"
          Write-Host
        }
        $customLatency = 0
        $customLatency += $latencyInput

        if (-Not $latencyInput) {
          break
        }
        elseif ($latencyInput -eq 0) {
          Write-Host -ForegroundColor Red "Latency input must not be zero."
        }
        elseif (-Not ($customLatency -match $floatCheck)) {
          Write-Host -ForegroundColor Red "Latency input must be numeric."
        }
        elseif ($latencyInput -match $intCheck) {
          $MAX_LATENCY = $latencyInput
          break
        }
        else {
          $MAX_LATENCY = $customLatency
          break
        }
        $latencyInput = ""
      }
      Write-Host -ForegroundColor Green "MAX_LATENCY=$MAX_LATENCY"

      $PREFERRED_REGION = "none"
      $VPN_PROTOCOL = "no"
      Write-Host "2"
      ./get_region.ps1

      if ((Test-Path "/opt/piavpn-manual/latencyList" -PathType leaf) -and ((Get-Item "/opt/piavpn-manual/latencyList").length) -gt 0) {
        # Output the ordered list of servers that meet the latency specification $MAX_LATENCY
        Write-Host "Orderd list of servers with latency less than " -NoNewline; Write-Host -ForegroundColor Green "$MAX_LATENCY" -NoNewline; Write-Host "seconds:"
        $i = 0
        foreach ($line in Get-Content "/opt/piavpn-manual/latencyList") {
          $i += 1
          $time = ($line -split '\s+')[0]
          $id = ($line -split '\s+')[1]
          $ip = ($line -split '\s+')[2]
          $location1 = ($line -split '\s+')[3]
          $location2 = ($line -split '\s+')[4]
          $location3 = ($line -split '\s+')[5]
          $location4 = ($line -split '\s+')[6]
          $location = -join($location1, " ", $location2, " ", $location3, " ", $location4)
          "{0,3} : {1,-8} {2,15} {3,17} - {4}" -f "$i", "$time", "$ip", "$id", "$location"
        }
        Write-Host

        # Receive input to specify the server to connect to manually
        while ($true) {
          $serverSelection = Read-Host -Prompt "Input the number of the server you want to connect to ([1]-[$i])"
          if (-Not $serverSelection) {
            Write-Host -ForegroundColor Red "You must provide input."
          }
          elseif (-Not ($serverSelection -match $intCheck)) {
            Write-Host -ForegroundColor Red "You must enter a number."
          }
          elseif ($serverSelection -lt 1) {
            Write-Host -ForegroundColor Red "You must enter a number greater than 1."
          }
          elseif ($serverSelection -gt $i) {
            Write-Host -ForegroundColor Red "You must enter a number between 1 and $i."
          }
          else {
            $PREFERRED_REGION = ((Get-Content -Path "/opt/piavpn-manual/latencyList" -TotalCount $serverSelection)[-1] -split '\s+')[1]
            Write-Host
            Write-Host -ForegroundColor Green "PREFERRED_REGION=$PREFERRED_REGION"
            break
          }
        }

        # Write the serverID for use when connecting, and display the serverName for user confirmation
        Write-Host
        break
      }
      else {
        exit 1
      }
    }
    else {
      Write-Host -ForegroundColor Green "You will auto-connect to the server with the lowest latency."
      Write-Host
      break
    }
  }
  else {
    # Validate in-line declaration of PREFERRED_REGION; if invalid remove input to initiate prompts
    Write-Host "Region input is : $PREFERRED_REGION"
    $VPN_PROTOCOL = "no"
    Write-Host "1"
    ./get_region.ps1
    
    ##### $LASTEXITCODE NEEDS CHECKING #####
    if ($LastExitCode -ne 1) {
      break
    }
    $PREFERRED_REGION = ""
  }
}

if (-Not $VPN_PROTOCOL) {
  $VPN_PROTOCOL = "none"
}
# This section asks for user connection preferences
switch ($VPN_PROTOCOL) {
  "openvpn" { $VPN_PROTOCOL = "openvpn_udp_standard" }
  {($_ -eq "wireguard") -or ($_ -eq "openvpn_udp_standard") -or ($_ -eq "openvpn_udp_strong") -or ($_ -eq "openvpn_tcp_standard") -or ($_ -eq "openvpn_tcp_strong")} { break }
  Default {
    $connection_method = Read-Host -Prompt "Connection method ([W]ireguard/[o]penvpn)"
    Write-Host

    $VPN_PROTOCOL = "wireguard"
    if ($connection_method.Substring(0,1) -eq "o") {
      $protocolInput = Read-Host -Prompt "Connection method ([U]dp/[t]cp)"
      Write-Host

      $protocol = "udp"
      if ($protocolInput.Substring(0,1) -eq "t") {
        $protocol = "tcp"
      }

      Write-Host "Higher levels of encryption trade performance for security. "
      $strongEncryption = Read-Host -Prompt "Do you want to use strong encryption ([N]o/[y]es)"
      Write-Host

      $encryption = "standard"
      if ($strongEncryption.Substring(0,1) -eq "y") {
        $encryption = "strong"
      }

      $VPN_PROTOCOL = -join("openvpn_", "$protocol", "_", "$encryption")
    }
    break
  }
}
Write-Host -ForegroundColor Green "VPN_PROTOCOL=$VPN_PROTOCOL"

# Check for the required presence of resolvconf for setting DNS on wireguard connections
$setDNS = "yes"
##### ONLY RUN ON LINUX #####
# try {
#   Invoke-Expression "resolvconf" | Out-Null
#   $resolvconfExist = "true"
# } catch {
#   $resolvconfExist = "false"
# }
# if ((-Not $resolvconfExist) -and ($VPN_PROTOCOL -eq "wireguard")) {
#   Write-Host -ForegroundColor Red "The resolvconf package could not be found."
#   Write-Host -ForegroundColor Red "This script can not set DNS for you and you will"
#   Write-Host -ForegroundColor Red "need to invoke DNS protection some other way."
#   Write-Host
#   $setDNS = "no"
# }
#############################

# Check for in-line definition of PIA_DNS and prompt for input
if ($setDNS -eq "yes") {
  if (-Not $PIA_DNS) {
    Write-Host "Using third party DNS could allow DNS monitoring."
    $setDNS = Read-Host -Prompt "Do you want to force PIA DNS ([Y]es/[n]o)"
    Write-Host
    $PIA_DNS = "true"
    if ($setDNS.Substring(0,1) -eq "n") {
      $PIA_DNS = "false"
    }
  }
}
elseif (($PIA_DNS -ne "true") -or ($setDNS -eq "no")) {
  $PIA_DNS = "false"
}
Write-Host -ForegroundColor Green "PIA_DNS=$PIA_DNS"

$CONNECTION_READY = "true"

./get_region.ps1
