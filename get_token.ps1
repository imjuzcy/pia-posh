# Only allow script to run as admin
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-Not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Error -ForegroundColor Red "This script needs to be run with administrator privileges."
  exit 1
}

New-Item -Path "$env:USERPROFILE\piavpn-manual" -ItemType "Directory" -ErrorAction SilentlyContinue

if ((-Not $PIA_USER) -or (-Not $PIA_PASS)) {
  Write-Host "If you want this script to automatically get a token from the Meta"
  Write-Host "service, please add the variables PIA_USER and PIA_PASS. Example:"
  Write-Host "$ PIA_USER=p0123456 PIA_PASS=xxx ./get_token.sh"
  exit 1
}

$tokenLocation = "$env:USERPROFILE/piavpn-manual/token"

Write-Host "Checking login credentials..."

if ($PIA_PASS.GetType().name -eq "SecureString") {
  $PIA_PASS = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PIA_PASS))
}
$generateTokenResponse = Invoke-Expression -Command 'curl.exe -s -u "$($PIA_USER):$($PIA_PASS)" "https://privateinternetaccess.com/gtoken/generateToken"' | ConvertFrom-Json

if (($generateTokenResponse).status -ne "OK") {
  Write-Host
  Write-Host
  Write-Host
  Write-Host -ForegroundColor Red "Could not authenticate with the login credentials provided!"
  exit
}

Write-Host -ForegroundColor Green "OK!"
Write-Host
$token = $generateTokenResponse.token
$tokenExpiration = (Get-Date).AddDays(1)
Write-Host -ForegroundColor Green "`$PIA_TOKEN = $token"
$token | Out-File -FilePath $tokenLocation
$tokenExpiration | Add-Content $tokenLocation
Write-Host
Write-Host "This token will expire in 24 hours, on $tokenExpiration."
Write-Host