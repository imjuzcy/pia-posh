
# pia-posh

 Private Internet Access VPN Manual Connections, but for Windows

---

This is a Powershell translation of [pia-foss/manual-connections](https://www.github.com/pia-foss/manual-connections).

Note:
Currently only supports Wireguard. I might add support for OpenVPN if the demand is there, but since I don't use OpenVPN and Wireguard is superior (in my opinion), I urge you to try Wireguard. If for some reason OpenVPN is the only way for you, open a issue and I will get to it when I have the time to.

I've tested it on Windows 10, which has Powershell 5.1 preinstalled. **If you're not on Windows, do not use this script.** Doesn't need additional modules/programs (other than Wireguard, of course). By default, the Wireguard program folder (C:\Program Files\WireGuard) should be in PATH, so I have used `wireguard.exe` instead of full path. To check, try running `wireguard.exe` and `wg.exe` in Powershell window. The former should open the Wireguard GUI, and the latter will show you the available commands.

When the PIA tunnel is launched with command line (like this script does), the GUI will not show that in the main tab. However, in the "Log" tab in the same GUI, it can be seen that the tunnel is running.

This is my first time writing Powershell scripts, so if your fluent in Powershell, I'd like some feedback on how it can be written better. The scripts are written with compatibility in mind, so if possible, I only use commands for Powershell 5.1 (the one that ships with Windows 10), and programs that comes with Windows 10.

## Extra features

I have implemented some extra features compared to [pia-foss/manual-connections](https://www.github.com/pia-foss/manual-connections). All extra features will be listed here:

- `$ALLOWED_IPS` (string): If this is set, the `AllowedIPs` parameter of the final Wireguard config will use this instead. Eg. `"0.0.0.0/1, 128.0.0.0/1"`. 
  Tip: If you want to exclude certain IP networks, use this `python3` code:
  
  <details>
  <summary>Code</summary>
    <p>

   ```python
   from ipaddress import ip_network
   start = '0.0.0.0/0'
   exclude = ['8.8.8.8', '10.8.0.0/24']

   result = [ip_network(start)]
   for x in exclude:
   n = ip_network(x)
   new = []
   for y in result:
      if y.overlaps(n):
            new.extend(y.address_exclude(n))
      else:
            new.append(y)
   result = new

   print(', '.join(str(x) for x in sorted(result)))
   ```

    </p>
  </details>

- `$LOCAL_NETWORK_BYPASS` (string, `"true"`/`"false"`): If this is set to `"true"`, `$ALLOWED_IPS` will be set to bypass private IPs, eg. `"0.0.0.0/5, 8.0.0.0/7, 11.0.0.0/8, 12.0.0.0/6, 16.0.0.0/4, 32.0.0.0/3, 64.0.0.0/2, 128.0.0.0/3, 160.0.0.0/5, 168.0.0.0/6, 172.0.0.0/12, 172.32.0.0/11, 172.64.0.0/10, 172.128.0.0/9, 173.0.0.0/8, 174.0.0.0/7, 176.0.0.0/4, 192.0.0.0/9, 192.128.0.0/11, 192.160.0.0/13, 192.169.0.0/16, 192.170.0.0/15, 192.172.0.0/14, 192.176.0.0/12, 192.192.0.0/10, 193.0.0.0/8, 194.0.0.0/7, 196.0.0.0/6, 200.0.0.0/5, 208.0.0.0/4, 224.0.0.0/3"`. This only applies if `$ALLOWED_IPS` is not set or is empty string.

---

## Issues

- `curl.exe` takes `.` as decimal point. If system locale uses `,` as decimal point, and `$MAX_LATENCY` is passed to `curl.exe`, it will give out error since the system will pass `,` as decimal point to `curl.exe`. Hence, `$MAX_LATENCY` is hardcoded for now. If you want to change it, edit the `ps1` script directly.
- For some reason, `curl.exe` complains about the cacert being untrusted. `-k` is used to circumvent this. **(HELP NEEDED ON THIS ISSUE)**
- Port forwarding script is yet to be translated.

---

## Usage

1. Make sure `wireguard.exe` and `wg.exe` is able to be run directly from Powershell. If not, install Wireguard or add `C:\Program Files\WireGuard` to environmental path.
2. Allow Powershell to run scripts. Run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned` in a Powershell window with administrator privileges.
3. Run `run_setup.ps1` to start the script. It'll prompt you for information that it needs.
4. Optionally, if you don't want it to prompt for information (non-interactive), use the `startup.ps1` script. Change the variable values inside beforehand. You can also do like

    ```powershell
    $PIA_USER = "p1234567"; $PIA_PASS = "abcd1234"; $PIA_DNS = "true"; $PIA_PF = "false"; $PREFERRED_REGION = "de-frankfurt"; $AUTOCONNECT = "false"; $VPN_PROTOCOL = "wireguard"; $DISABLE_IPV6 = "no"; $MAX_LATENCY = "0.05"; ./run_setup.ps1
    ```

---

### Run on startup

1. Edit `startup.ps1` to include your desired values for variables.
2. Use Task Scheduler to run `startup.ps1` when user logs in:
   1. General: Enable `Run with highest privilege`
   2. Triger: `At logon`
   3. Actions: `Start program`
      1. Program: `powershell.exe`
      2. Arguments: `-File "<path\to\startup.ps1>"`
   4. Conditions: Disable all
3. When saving the task, it'll prompt for your Windows logon password. If you do not have a password for your account, I'm afraid it will not work (afaik).

---

## To-do

- Translate `port_forwarding.sh`
- Translate `connect_to_openvpn_with_token.sh` (low priority unless there is demand)
