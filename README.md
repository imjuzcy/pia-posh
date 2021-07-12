
# pia-posh

 Private Internet Access VPN Manual Connections, but for Windows

---

This is a Powershell translation of [pia-foss/manual-connections](https://www.github.com/pia-foss/manual-connections).

Note:
Currently only supports Wireguard. I might add support for OpenVPN if the demand is there, but since I don't use OpenVPN and Wireguard is superior (in my opinion), I urge you to try Wireguard. If for some reason OpenVPN is the only way for you, open a issue and I will get to it when I have the time to.

I've tested it on Windows 10, which has Powershell 5.1 preinstalled. **If you're not on Windows, do not use this script.** Doesn't need additional modules/programs (other than Wireguard, of course). By default, the Wireguard program folder (C:\Program Files\WireGuard) should be in PATH, so I have used `wireguard.exe` instead of full path. To check, try running `wireguard.exe` and `wg.exe` in Powershell window. The former should open the Wireguard GUI, and the latter will show you the available commands.

When the PIA tunnel is launched with command line (like this script does), the GUI will not show that in the main tab. However, in the "Log" tab in the same GUI, it can be seen that the tunnel is running.

This is my first time writing Powershell scripts, so if your fluent in Powershell, I'd like some feedback on how it can be written better. The scripts are written with compatibility in mind, so if possible, I only use commands for Powershell 5.1 (the one that ships with Windows 10), and programs that comes with Windows 10.

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
