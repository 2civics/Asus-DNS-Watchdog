# Asus DNS Watchdog (`Asus_DNS_Watchdog.ps1`)

[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/Asus_DNS_Watchdog?color=38BDF8&label=PowerShell%20Gallery)](https://www.powershellgallery.com/packages/Asus_DNS_Watchdog/1.0.0)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/Asus_DNS_Watchdog?color=3FB950)](https://www.powershellgallery.com/packages/Asus_DNS_Watchdog/1.0.0)
[![GitHub Release](https://img.shields.io/github/v/release/2civics/Asus-DNS-Watchdog?color=A371F7)](https://github.com/2civics/Asus-DNS-Watchdog/releases/tag/v1.0.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A dark-mode Windows WPF GUI that audits, deploys, and self-heals a persistent `iptables` Port 53 DNS redirect watchdog on ASUS routers over SSH—serving as a drop-in replacement for the missing **DNS Director** feature on stock ASUSWRT routers such as the **ASUS ZenWiFi XT8 v2**.

---

## How & Why This Replaces Missing DNS Director

### The Problem on Stock ASUSWRT Routers
Many smart TVs, streaming sticks, IoT appliances, and mobile apps ignore the DNS server handed out by your router's DHCP server and send unencrypted DNS queries straight to hardcoded resolvers (such as `8.8.8.8` or `1.1.1.1`) or leak queries over IPv6. Whenever a device bypasses your router's resolver, upstream DNS filtering—such as **AdGuard Private DNS**, **DNS-over-TLS (DoT)**, **Pi-hole**, or **NextDNS**—is completely bypassed.

On routers running **Asuswrt-Merlin**, this is solved natively with **DNS Director**. However, several popular ASUS routers—including the **ASUS ZenWiFi XT8 v2**—run stock ASUSWRT firmware without Merlin support and do not include DNS Director.

### How `Asus_DNS_Watchdog` Enforces DNS Redirection
`Asus_DNS_Watchdog` replicates DNS Director behavior across three coordinated layers:

1. **IPv4 Port 53 Interception (`iptables` `NAT PREROUTING`):** Injects `DNAT` rules on the LAN bridge (`br0`) for both UDP and TCP port 53, transparently redirecting all outbound client DNS queries to the router's LAN IP (e.g., `192.168.50.1`). The router's local `dnsmasq` service then resolves those requests using your configured WAN DNS / DNS-over-TLS upstream.
2. **IPv6 DNS Leak Prevention (`ip6tables` `FORWARD`):** Injects `REJECT` rules on `br0` for UDP and TCP port 53 over IPv6. Dual-stack clients cannot leak queries around IPv4 interception via IPv6 DNS servers and cleanly fall back to the intercepted IPv4 resolver without breaking IPv6 internet access.
3. **5-Minute On-Router Self-Healing (`cru` + `/jffs/dns_watchdog.sh`):** Deploys an executable BusyBox shell script at `/jffs/dns_watchdog.sh` and schedules it to run every 5 minutes via ASUSWRT's `cru` cron daemon (`*/5 * * * *`). If a WAN reconnect or firewall reload flushes the custom rules, the watchdog automatically re-injects them within 5 minutes and logs the event to the router's syslog under `DNS_WATCHDOG`.

### Surviving Reboots & Firmware Updates
Unlike Asuswrt-Merlin, stock ASUSWRT firmware does not execute custom `firewall-start` or `services-start` scripts on boot, and firmware upgrades frequently wipe `/jffs/dns_watchdog.sh` or clear `cru` cron jobs.

`Asus_DNS_Watchdog.ps1` solves this from your Windows PC:

* **Three-Stage State Audit:** Connects over SSH and checks (1) active `PREROUTING` Port 53 `DNAT` rules, (2) `/jffs/dns_watchdog.sh` existence, and (3) the `cru l` cron schedule.
* **Automatic Recovery:**
  * If `/jffs/dns_watchdog.sh` and the cron job are present but the firewall rules were flushed, it runs `/jffs/dns_watchdog.sh` immediately to restore protection without waiting for the next 5-minute cron cycle.
  * If `/jffs/dns_watchdog.sh` or the cron entry was wiped by a firmware update or reboot, it automatically recreates `/jffs/dns_watchdog.sh`, marks it executable (`chmod +x`), re-registers the `cru` cron job, and injects all IPv4/IPv6 firewall rules.
* **Pure UTF-8 `LF` Payload Streaming:** Standard Windows pipes send `CRLF` (`\r\n`) line endings, which cause BusyBox `sh` on ASUS routers to fail with syntax errors. `Asus_DNS_Watchdog.ps1` writes the payload directly to `ssh.exe` standard input as raw **UTF-8 `LF` (`\n`)** bytes so `/jffs/dns_watchdog.sh` always runs cleanly.

---

## Features

* **Dark-Mode WPF Interface:** Native Windows 10/11 dark title bar (`dwmapi.dll`), color-coded status banner, and a three-card health matrix (`NAT PREROUTING`, `WATCHDOG SCRIPT`, `CRON DAEMON`).
* **Real-Time Telemetry Console:** Timestamped diagnostic output showing each SSH check, matched rule counts, self-healing actions, and full error messages if SSH fails.
* **Smart Auto-Close Timer:** Automatically closes 15 seconds after a clean audit so it can run unattended at Windows startup/logon. Click **Keep Open** or click inside the log window to pause the countdown.
* **Interactive Controls:**
  * **Keep Open:** Pauses the auto-close timer so you can inspect the telemetry log.
  * **Force Rebuild:** Prompts for confirmation, overwrites `/jffs/dns_watchdog.sh`, re-registers the 5-minute `cru` cron job, and re-applies all DNS firewall rules.
  * **Re-Audit (`F5`):** Re-runs the full three-stage SSH audit immediately.
  * **`Esc`:** Closes the window immediately.
* **Zero External PowerShell Modules:** Uses built-in Windows OpenSSH (`ssh.exe`) and native .NET WPF libraries.

---

## Installation

### Option 1: Install from the PowerShell Gallery (Recommended)

Install directly using `Install-Script`:

```powershell
Install-Script -Name Asus_DNS_Watchdog -RequiredVersion 1.0.0
```

View the package listing: [PowerShell Gallery — Asus_DNS_Watchdog 1.0.0](https://www.powershellgallery.com/packages/Asus_DNS_Watchdog/1.0.0)

> **Manage Your Scripts Visually:** You can search, install, update, and manage `Asus_DNS_Watchdog` and your other PowerShell Gallery tools using [**PSGallery-Manager**](https://github.com/2civics/PSGallery-Manager).

To check the exact folder where PowerShell Gallery saved the script:

```powershell
(Get-InstalledScript -Name Asus_DNS_Watchdog).InstalledLocation
```

### Option 2: Download from GitHub Releases

Download `Asus_DNS_Watchdog.ps1` directly from the [**v1.0.0 Release Page**](https://github.com/2civics/Asus-DNS-Watchdog/releases/tag/v1.0.0) and save it to a permanent folder such as `C:\Scripts\Asus_DNS_Watchdog.ps1`.

---

## Step-by-Step SSH & Router Setup

Because `Asus_DNS_Watchdog.ps1` runs non-interactively (`BatchMode=yes`), password authentication is disabled during execution. You must configure key-based SSH authentication between Windows and your ASUS router once.

### Step 1: Verify Windows OpenSSH Client Is Installed

Open PowerShell and verify that `ssh.exe` and `ssh-keygen.exe` are available:

```powershell
Get-Command ssh.exe, ssh-keygen.exe
```

If either command is missing, install the built-in Windows OpenSSH Client from an **Administrator** PowerShell prompt:

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

### Step 2: Generate an `ed25519` SSH Key Pair on Windows

Run the following command in PowerShell to create a dedicated key pair (press **Enter** twice when asked for a passphrase so scheduled tasks and shortcuts run without prompting):

```powershell
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\asus_ed25519" -C "asus-dns-watchdog"
```

Copy the generated public key to your Windows clipboard:

```powershell
Get-Content "$env:USERPROFILE\.ssh\asus_ed25519.pub" | Set-Clipboard
```

*(You can also run `Get-Content "$env:USERPROFILE\.ssh\asus_ed25519.pub"` to view the single `ssh-ed25519 AAAA...` line on screen.)*

### Step 3: Enable SSH (LAN Only) & Add the Public Key on the ASUS Router

1. Open your router's web interface in a browser (typically `http://192.168.50.1` or `http://www.asusrouter.com`).
2. Go to **Administration** → **System** in the left sidebar.
3. Scroll down to the **SSH Daemon** section and configure:
   * **Enable SSH:** Select **LAN only** *(never select LAN & WAN)*.
   * **SSH Port:** `22` (default).
   * **Allow Password Login:** Set to **No** once you verify key login works.
4. Click inside the **Authorized Keys** text box and paste (`Ctrl+V`) the `ssh-ed25519 ...` public key you copied in Step 2.
5. Scroll to the bottom of the page and click **Apply**.

### Step 4: Trust the Router's SSH Host Fingerprint

`BatchMode=yes` will refuse to connect to a host whose fingerprint is not already saved in `$env:USERPROFILE\.ssh\known_hosts`. Run one manual test command in PowerShell (replace `admin` and `192.168.50.1` with your router's admin username and LAN IP):

```powershell
ssh -i "$env:USERPROFILE\.ssh\asus_ed25519" -o StrictHostKeyChecking=accept-new admin@192.168.50.1 "uname -a"
```

* **Verification:** You should see `Warning: Permanently added '192.168.50.1' (ED25519) to the list of known hosts.` followed by the router's Linux kernel string—with **no password prompt**.

---

## Configuration

Before running `Asus_DNS_Watchdog.ps1` for the first time, review the configuration block near the top of the script and verify that the target IP address matches your router's LAN subnet.

### 1. Primary Connection & Timer Settings

Open `Asus_DNS_Watchdog.ps1` in a text editor (such as VS Code or Notepad) and locate the `<# Connection & Timer Configuration #>` block near the top of the file:

```powershell
<# Connection & Timer Configuration #>
$key          = "$env:USERPROFILE\.ssh\asus_ed25519";
$router       = "admin@192.168.50.1";
$AutoCloseSec = 15;
```

| Variable | Example / Default | Required? | Description |
| :--- | :--- | :--- | :--- |
| **`$key`** | `"$env:USERPROFILE\.ssh\asus_ed25519"` | **Yes** | Full path to your OpenSSH **private** key file on Windows. Must match the public key pasted into the router's **Authorized Keys** field. Do not point this to the `.pub` file. |
| **`$router`** | `"admin@192.168.50.1"` | **Yes** | SSH target in `username@router-ip` format. The username must match **Router Login Name** under **Administration** → **System** on your router, and the IP must be your router's LAN gateway IP. |
| **`$AutoCloseSec`** | `15` | Optional | Seconds the dashboard remains visible after a clean audit before closing automatically. Increase for longer review time, or click **Keep Open** in the UI to pause it. |

### 2. Customizing for a Different Router Subnet (`192.168.1.1`, etc.)

Most newer ASUS routers (including the **ZenWiFi XT8 v2**) default to **`192.168.50.1`**, while older models default to **`192.168.1.1`**.

If your router uses a LAN IP other than `192.168.50.1`, update `$router` at the top of the script **and** replace `192.168.50.1` with your router's LAN IP in the following places inside `Asus_DNS_Watchdog.ps1`:

1. **`Deploy-FullWatchdog` (the `iptables` DNAT target and rule check):**
   ```sh
   if ! iptables -t nat -L PREROUTING -n | grep -q "192.168.50.1"; then
       logger -t "DNS_WATCHDOG" "Rules missing. Injecting Port 53 redirects."
       iptables -t nat -D PREROUTING -i br0 -p udp --dport 53 -j DNAT --to 192.168.50.1 2>/dev/null
       iptables -t nat -I PREROUTING -i br0 -p udp --dport 53 -j DNAT --to 192.168.50.1
       iptables -t nat -D PREROUTING -i br0 -p tcp --dport 53 -j DNAT --to 192.168.50.1 2>/dev/null
       iptables -t nat -I PREROUTING -i br0 -p tcp --dport 53 -j DNAT --to 192.168.50.1
   ```
   > **Important:** The `--to <RouterIP>` address in these `DNAT` rules is where intercepted port 53 DNS packets are sent. If this IP does not match your router's actual LAN IP, client DNS queries will fail to resolve.

2. **UI Status Labels & Confirmation Prompt (cosmetic):**
   * XAML `Title="..."` attribute (e.g., `"ASUS ZenWiFi XT8 - DNS Watchdog"` or `"ASUS Router - DNS Watchdog"`).
   * `CardRulesDetail` initial text (`Target: dport 53 DNAT to 192.168.50.1`).
   * `$AuditTimer` Step 1 status detail (`Redirecting :53 to 192.168.50.1`).
   * `$RebuildBtn` confirmation dialog text.

### 3. Advanced Firewall & Cron Parameters

For almost all standard ASUSWRT home networks, the defaults below work out of the box and should not be changed:

| Setting Inside Script | Default Value | Purpose & When to Change |
| :--- | :--- | :--- |
| **LAN Bridge Interface** | `br0` | Primary LAN bridge covering all Ethernet ports and main Wi-Fi radios. Only add rules for `br1` / `br2` if you also want to intercept isolated Guest Network Wi-Fi bridges (check via `brctl show` over SSH). |
| **Watchdog Script Path** | `/jffs/dns_watchdog.sh` | Stored on the router's writable JFFS flash partition so it persists across standard service restarts. |
| **Cron Schedule** | `*/5 * * * *` | Runs `/jffs/dns_watchdog.sh` every 5 minutes via `cru a dns_watchdog`. If you change the interval in `Deploy-FullWatchdog`, update the matching regex check in `$AuditTimer` Step 3 (`\*/5 \* \* \* \* /jffs/dns_watchdog\.sh`) to match. |
| **Syslog Identifier** | `DNS_WATCHDOG` | Tag written to `/tmp/syslog.log` whenever the watchdog checks or re-injects rules (`logger -t "DNS_WATCHDOG"`). |

### 4. Pre-Flight Checklist Before First Run

Verify all four items before launching `Asus_DNS_Watchdog.ps1`:

1. **Router SSH enabled:** **Administration** → **System** → **Enable SSH** is set to **LAN only**.
2. **Public key installed:** The contents of your `.pub` file (`ssh-ed25519 ...`) are saved in **Authorized Keys** on the router.
3. **Host key trusted:** You have run `ssh -i "<path-to-private-key>" <user>@<router-ip> "exit"` once in PowerShell so the router's fingerprint is stored in `$env:USERPROFILE\.ssh\known_hosts`.
4. **Script variables updated:** `$key`, `$router`, and (if not `192.168.50.1`) the `DNAT` target IP inside `Asus_DNS_Watchdog.ps1` match your network.

---

## Creating a Windowless Desktop Shortcut

Running a `.ps1` file directly flashes a console window before WPF hides it. Use either method below to launch `Asus_DNS_Watchdog.ps1` cleanly with zero console flash.

### Option 1: PowerShell Desktop Shortcut Creator (Recommended)

Use [**PowerShell-Desktop-Shortcut-Creator**](https://github.com/2civics/PowerShell-Desktop-Shortcut-Creator) to generate a windowless desktop shortcut automatically with custom icon selection and proper argument escaping.

### Option 2: Manual Desktop Shortcut

1. Right-click an empty area on your Windows Desktop and select **New** → **Shortcut**.
2. In **Type the location of the item**, enter the following command (adjusting the file path to where `Asus_DNS_Watchdog.ps1` is saved):
   ```text
   conhost.exe --headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\Asus_DNS_Watchdog.ps1"
   ```
   *(If you installed via `Install-Script`, the default path is `"$env:USERPROFILE\Documents\PowerShell\Scripts\Asus_DNS_Watchdog.ps1"` or `"$env:USERPROFILE\Documents\WindowsPowerShell\Scripts\Asus_DNS_Watchdog.ps1"`.)*
3. Click **Next**, name the shortcut **ASUS DNS Watchdog**, and click **Finish**.
4. *(Optional)* Right-click the shortcut → **Properties** → **Change Icon...** → browse to `%SystemRoot%\System32\imageres.dll` or `%SystemRoot%\System32\shell32.dll` to assign a network or shield icon.

---

## Automating Recovery on Boot / Logon (Windows Task Scheduler)

Setting up a Windows Scheduled Task ensures `Asus_DNS_Watchdog.ps1` runs automatically after your PC boots or you sign in—immediately restoring `/jffs/dns_watchdog.sh`, the `cru` cron job, and all DNS redirect rules if a router firmware update or power outage cleared them.

### Option 1: Create the Scheduled Task via PowerShell

Run the following in an **Administrator** PowerShell window (update `$ScriptPath` to match your script location):

```powershell
$TaskName   = "ASUS DNS Watchdog"
$ScriptPath = "C:\Scripts\Asus_DNS_Watchdog.ps1"

$Action = New-ScheduledTaskAction `
    -Execute "conhost.exe" `
    -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""

# Run at user logon with a 45-second delay so Wi-Fi/Ethernet and router SSH are online
$Trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$Trigger.Delay = "PT45S"

$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 2)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -Description "Audits and self-heals the ASUS router DNS redirect watchdog over SSH." `
    -Force
```

* **Verification:** Run `Start-ScheduledTask -TaskName "ASUS DNS Watchdog"` in PowerShell to test it immediately. The GUI should appear without a console window, verify or deploy the watchdog, and auto-close after 15 seconds.

### Option 2: Create the Scheduled Task Manually in Task Scheduler

1. Press `Win + R`, type `taskschd.msc`, and press **Enter**.
2. In the right **Actions** pane, click **Create Task...**
3. **General tab:**
   * **Name:** `ASUS DNS Watchdog`
   * Select **Run only when user is logged on** *(required so the WPF GUI can render on your desktop)*.
4. **Triggers tab:**
   * Click **New...** → set **Begin the task** to **At log on**.
   * Check **Delay task for:** and set it to **30 seconds** or **1 minute** so your network adapter has an IP address before SSH runs.
   * Click **OK**.
5. **Actions tab:**
   * Click **New...** → set **Action** to **Start a program**.
   * **Program/script:** `conhost.exe`
   * **Add arguments:** `--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\Asus_DNS_Watchdog.ps1"`
   * Click **OK**.
6. **Conditions tab:**
   * Uncheck **Start the task only if the computer is on AC power** so it also runs on battery.
7. Click **OK** to save the task.

---

## Troubleshooting

### 1. `SSH CONNECTION FAILED` / Connection Timed Out
* Confirm **Enable SSH** is set to **LAN only** (or **LAN & WAN**, though LAN only is strongly recommended) in the router web UI under **Administration** → **System**.
* Verify the router IP in `$router` matches your router's actual LAN IP (`ipconfig` in Windows → look at **Default Gateway**).
* Test reachability directly in PowerShell:
  ```powershell
  Test-NetConnection -ComputerName 192.168.50.1 -Port 22
  ```
  `TcpTestSucceeded` must return `True`.

### 2. `Permission denied (publickey)`
* Check that your router login username in `$router` matches the exact administrator username shown under **Administration** → **System** → **Router Login Name** (not all setups use `admin`).
* Verify you pasted the **public** key (`.pub` file starting with `ssh-ed25519 `) into the router's **Authorized Keys** field—not the private key—and clicked **Apply**.
* Run a verbose SSH test to see the exact rejection reason:
  ```powershell
  ssh -vvv -i "$env:USERPROFILE\.ssh\asus_ed25519" admin@192.168.50.1 "exit"
  ```

### 3. `Host key verification failed` or `REMOTE HOST IDENTIFICATION HAS CHANGED`
* This occurs if you haven't connected interactively once, or if a firmware update/factory reset regenerated the router's SSH host key.
* Remove the stale fingerprint and accept the new one:
  ```powershell
  ssh-keygen -R 192.168.50.1
  ssh -i "$env:USERPROFILE\.ssh\asus_ed25519" -o StrictHostKeyChecking=accept-new admin@192.168.50.1 "exit"
  ```

### 4. `UNPROTECTED PRIVATE KEY FILE!` on Windows
* Windows OpenSSH rejects private keys that are readable by other local user accounts. Reset the NTFS permissions on your private key in PowerShell:
  ```powershell
  icacls "$env:USERPROFILE\.ssh\asus_ed25519" /inheritance:r
  icacls "$env:USERPROFILE\.ssh\asus_ed25519" /grant:r "$($env:USERNAME):(R)"
  ```

### 5. Verifying Rules & Cron Activity Directly on the Router
* To confirm the live firewall rules and cron job directly via SSH:
  ```powershell
  ssh -i "$env:USERPROFILE\.ssh\asus_ed25519" admin@192.168.50.1 "iptables -t nat -L PREROUTING -v -n; echo '---'; ip6tables -L FORWARD -v -n; echo '---'; cru l"
  ```
* To inspect the watchdog's syslog entries on the router:
  ```powershell
  ssh -i "$env:USERPROFILE\.ssh\asus_ed25519" admin@192.168.50.1 "grep DNS_WATCHDOG /tmp/syslog.log"
  ```

### 6. Devices Still Bypassing DNS via Encrypted DNS (DoT / DoH)
* Just like ASUS's built-in DNS Director, `Asus_DNS_Watchdog` intercepts standard unencrypted DNS on **UDP and TCP port 53**.
* **DNS-over-TLS (`TCP 853`):** Block outbound port `853` in your router's **Firewall** → **Network Services Filter** (make sure your router's own WAN DoT traffic is not blocked if you use it on the router).
* **DNS-over-HTTPS (`TCP 443`):** Disable **Secure DNS** / **Private DNS** in client browsers and mobile devices, or block known DoH provider domains on your upstream DNS filter (e.g., AdGuard Private DNS / HaGeZi DoH blocklists).

### 7. Isolated Guest Wi-Fi Clients Bypassing Redirection
* On certain ASUS routers and AiMesh nodes, Guest Network Wi-Fi clients use a separate bridge interface (such as `br1` or `br2`) rather than `br0`.
* List your router's bridge interfaces over SSH:
  ```powershell
  ssh -i "$env:USERPROFILE\.ssh\asus_ed25519" admin@192.168.50.1 "brctl show"
  ```
  If guest interfaces appear on a separate bridge, duplicate the `iptables` and `ip6tables` rules in `Deploy-FullWatchdog` for that bridge interface.

---

## Companion Projects

* [**Asus-Nat-View**](https://github.com/2civics/Asus-Nat-View) — Dark-mode Windows WPF GUI for inspecting live `iptables` NAT chains (`PREROUTING`, `POSTROUTING`, `VSERVER`) on ASUS routers over SSH. Pairs directly with `Asus_DNS_Watchdog` so you can visually inspect the active `DNAT` redirect rules and hit counters.
* [**PowerShell-Desktop-Shortcut-Creator**](https://github.com/2civics/PowerShell-Desktop-Shortcut-Creator) — Easily create clean, windowless desktop shortcuts for PowerShell GUI scripts.
* [**PSGallery-Manager**](https://github.com/2civics/PSGallery-Manager) — Browse, install, update, and manage your PowerShell Gallery scripts from one place.

---

## License

MIT License — Copyright (c) 2026 Danny Wareham (`WareSoft` / `2civics`).