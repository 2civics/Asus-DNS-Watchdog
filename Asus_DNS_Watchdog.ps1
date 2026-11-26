<#PSScriptInfo

.VERSION 1.0.0

.GUID 73174749-59db-488a-b142-0f2df9d5229e

.AUTHOR waresoft

.COMPANYNAME waresoft

.COPYRIGHT (c) 2026 waresoft. All rights reserved.

.TAGS ASUS ASUSWRT Router DNS Watchdog iptables JFFS SSH WPF GUI Networking

.LICENSEURI https://opensource.org/licenses/MIT

.PROJECTURI https://github.com/2civics/Asus-Dns-Watchdog

.RELEASENOTES Initial release (v1.0.0): Dark-mode WPF GUI to audit, deploy, and self-heal an iptables Port 53 DNAT and IPv6 DNS REJECT watchdog script and cron job on ASUS routers over SSH.

#>

<#
.DESCRIPTION
    A dark-mode Windows WPF GUI to audit, deploy, and self-heal an iptables Port 53 DNS redirect watchdog on ASUS routers over SSH—serving as a drop-in replacement for the missing DNS Director feature on models like the ASUS ZenWiFi XT8 v2.
#>

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase;

<# Enable native Windows 10/11 dark title bar and hide console window #>
$Win32Code = @"
using System;
using System.Runtime.InteropServices;
public class DwmTheme {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
}
public class ConsoleWindow {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
Add-Type -TypeDefinition $Win32Code -ErrorAction SilentlyContinue;
$ConsoleHwnd = [ConsoleWindow]::GetConsoleWindow();
if ($ConsoleHwnd -ne [IntPtr]::Zero) {
    [void][ConsoleWindow]::ShowWindow($ConsoleHwnd, 0);
}

<# Connection & Timer Configuration #>
$RouterIP     = "192.168.50.1";
$Username     = "admin";
$KeyPath      = "$env:USERPROFILE\.ssh\id_ed25519";
$DeviceLabel  = "ASUS Router";
$LanInterface = "br0";
$AutoCloseSec = 15; # Set to 0 to keep window pinned open

$router       = "$Username@$RouterIP";

<# Build Dark-Mode WPF Interface #>
[xml]$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="ASUS Router - DNS Watchdog"
        Width="780" SizeToContent="Height"
        MinWidth="720" MaxWidth="960"
        WindowStartupLocation="CenterScreen"
        Background="#121417" Foreground="#E6EDF3"
        FontFamily="Segoe UI" FontSize="12.5">

    <Window.Resources>
        <Style x:Key="ActionBtn" TargetType="Button">
            <Setter Property="Background" Value="#21262D"/>
            <Setter Property="Foreground" Value="#E6EDF3"/>
            <Setter Property="BorderBrush" Value="#30363D"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12,5"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="BtnBorder"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="5"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="BtnBorder" Property="Background" Value="#30363D"/>
                                <Setter TargetName="BtnBorder" Property="BorderBrush" Value="#484F58"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- 1. Hero Status Banner -->
        <Border x:Name="BannerBorder" Grid.Row="0"
                Background="#161B22" BorderBrush="#30363D" BorderThickness="1"
                CornerRadius="8" Padding="14,12" Margin="0,0,0,12">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <Border x:Name="BannerIconBg" Grid.Column="0" Width="38" Height="38"
                        CornerRadius="8" Background="#1F2937" Margin="0,0,12,0"
                        VerticalAlignment="Center">
                    <Path x:Name="BannerIcon" Width="20" Height="20" Stretch="Uniform"
                          Fill="#38BDF8" HorizontalAlignment="Center" VerticalAlignment="Center"
                          Data="M12,1L3,5V11C3,16.55 6.84,21.74 12,23C17.16,21.74 21,16.55 21,11V5L12,1M12,7C13.4,7 14.8,8.1 14.8,9.5V11C15.4,11 16,11.6 16,12.3V15.8C16,16.4 15.4,17 14.7,17H9.2C8.6,17 8,16.4 8,15.7V12.2C8,11.6 8.6,11 9.2,11V9.5C9.2,8.1 10.6,7 12,7M12,8.2C11.2,8.2 10.5,8.7 10.5,9.5V11H13.5V9.5C13.5,8.7 12.8,8.2 12,8.2Z"/>
                </Border>

                <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <TextBlock x:Name="BannerTitle" Text="AUDITING DNS WATCHDOG STATE..."
                               FontSize="14.5" FontWeight="Bold" Foreground="#F0F6FC"/>
                    <TextBlock x:Name="BannerSubtitle" Text="Connecting to router over SSH to inspect NAT redirects, script, and cron..."
                               FontSize="12" Foreground="#8B949E" Margin="0,2,0,0"/>
                </StackPanel>

                <Border Grid.Column="2" Background="#0D1117" BorderBrush="#30363D"
                        BorderThickness="1" CornerRadius="12" Padding="10,4"
                        VerticalAlignment="Center">
                    <StackPanel Orientation="Horizontal">
                        <Ellipse x:Name="ConnDot" Width="8" Height="8" Fill="#38BDF8" Margin="0,0,6,0" VerticalAlignment="Center"/>
                        <TextBlock x:Name="ConnLabel" Text="admin@192.168.50.1" FontFamily="Consolas" FontSize="11.5" Foreground="#C9D1D9"/>
                    </StackPanel>
                </Border>
            </Grid>
        </Border>

        <!-- 2. Three-Card Health Matrix -->
        <Grid Grid.Row="1" Margin="0,0,0,12">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="10"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="10"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- Card 1: NAT PREROUTING Rules -->
            <Border x:Name="CardRulesBorder" Grid.Column="0" Background="#161B22"
                    BorderBrush="#30363D" BorderThickness="1" CornerRadius="8" Padding="12">
                <StackPanel>
                    <DockPanel Margin="0,0,0,8">
                        <TextBlock Text="NAT PREROUTING" FontSize="11" FontWeight="Bold" Foreground="#8B949E" DockPanel.Dock="Left"/>
                        <Border x:Name="CardRulesPill" Background="#21262D" CornerRadius="4" Padding="6,1" DockPanel.Dock="Right" HorizontalAlignment="Right">
                            <TextBlock x:Name="CardRulesBadge" Text="CHECKING" FontSize="10" FontWeight="Bold" Foreground="#8B949E"/>
                        </Border>
                    </DockPanel>
                    <TextBlock x:Name="CardRulesStatus" Text="Inspecting iptables..." FontSize="13.5" FontWeight="SemiBold" Foreground="#E6EDF3"/>
                    <TextBlock x:Name="CardRulesDetail" Text="Target: dport 53 DNAT" FontSize="11" Foreground="#8B949E" Margin="0,4,0,0" TextTrimming="CharacterEllipsis"/>
                </StackPanel>
            </Border>

            <!-- Card 2: Watchdog Script File -->
            <Border x:Name="CardFileBorder" Grid.Column="2" Background="#161B22"
                    BorderBrush="#30363D" BorderThickness="1" CornerRadius="8" Padding="12">
                <StackPanel>
                    <DockPanel Margin="0,0,0,8">
                        <TextBlock Text="WATCHDOG SCRIPT" FontSize="11" FontWeight="Bold" Foreground="#8B949E" DockPanel.Dock="Left"/>
                        <Border x:Name="CardFilePill" Background="#21262D" CornerRadius="4" Padding="6,1" DockPanel.Dock="Right" HorizontalAlignment="Right">
                            <TextBlock x:Name="CardFileBadge" Text="PENDING" FontSize="10" FontWeight="Bold" Foreground="#8B949E"/>
                        </Border>
                    </DockPanel>
                    <TextBlock x:Name="CardFileStatus" Text="Waiting..." FontSize="13.5" FontWeight="SemiBold" Foreground="#E6EDF3"/>
                    <TextBlock x:Name="CardFileDetail" Text="/jffs/dns_watchdog.sh" FontFamily="Consolas" FontSize="11" Foreground="#8B949E" Margin="0,4,0,0" TextTrimming="CharacterEllipsis"/>
                </StackPanel>
            </Border>

            <!-- Card 3: Cron Job -->
            <Border x:Name="CardCronBorder" Grid.Column="4" Background="#161B22"
                    BorderBrush="#30363D" BorderThickness="1" CornerRadius="8" Padding="12">
                <StackPanel>
                    <DockPanel Margin="0,0,0,8">
                        <TextBlock Text="CRON DAEMON" FontSize="11" FontWeight="Bold" Foreground="#8B949E" DockPanel.Dock="Left"/>
                        <Border x:Name="CardCronPill" Background="#21262D" CornerRadius="4" Padding="6,1" DockPanel.Dock="Right" HorizontalAlignment="Right">
                            <TextBlock x:Name="CardCronBadge" Text="PENDING" FontSize="10" FontWeight="Bold" Foreground="#8B949E"/>
                        </Border>
                    </DockPanel>
                    <TextBlock x:Name="CardCronStatus" Text="Waiting..." FontSize="13.5" FontWeight="SemiBold" Foreground="#E6EDF3"/>
                    <TextBlock x:Name="CardCronDetail" Text="*/5 * * * * (cru l)" FontFamily="Consolas" FontSize="11" Foreground="#8B949E" Margin="0,4,0,0" TextTrimming="CharacterEllipsis"/>
                </StackPanel>
            </Border>
        </Grid>

        <!-- 3. Telemetry & Audit Console -->
        <Border Grid.Row="2" Background="#0D1117" BorderBrush="#30363D" BorderThickness="1"
                CornerRadius="8" Padding="10" Margin="0,0,0,12">
            <StackPanel>
                <DockPanel Margin="2,0,2,6">
                    <TextBlock Text="EXECUTION TELEMETRY" FontSize="10.5" FontWeight="Bold" Foreground="#8B949E" DockPanel.Dock="Left"/>
                    <TextBlock Text="IPv4 DNAT + IPv6 DNS REJECT" FontSize="10.5" Foreground="#6E7681" DockPanel.Dock="Right" HorizontalAlignment="Right"/>
                </DockPanel>
                <RichTextBox x:Name="LogBox" Height="175" IsReadOnly="True"
                             Background="#0D1117" Foreground="#C9D1D9"
                             BorderThickness="0" FontFamily="Consolas" FontSize="12"
                             VerticalScrollBarVisibility="Auto">
                    <FlowDocument PagePadding="2"/>
                </RichTextBox>
            </StackPanel>
        </Border>

        <!-- 4. Countdown Bar & Interactive Controls -->
        <Grid Grid.Row="3">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <ProgressBar x:Name="CountdownBar" Grid.Row="0" Height="3" Minimum="0" Maximum="100" Value="100"
                         Background="#21262D" Foreground="#3FB950" BorderThickness="0" Margin="0,0,0,10"/>

            <DockPanel Grid.Row="1">
                <TextBlock x:Name="CountdownText" DockPanel.Dock="Left" VerticalAlignment="Center"
                           Text="Running diagnostics..." Foreground="#8B949E" FontSize="11.5"/>

                <StackPanel Orientation="Horizontal" DockPanel.Dock="Right" HorizontalAlignment="Right">
                    <Button x:Name="PinBtn" Content="Keep Open" Style="{StaticResource ActionBtn}" Margin="0,0,8,0"/>
                    <Button x:Name="RebuildBtn" Content="Force Rebuild" Style="{StaticResource ActionBtn}" Margin="0,0,8,0"/>
                    <Button x:Name="ReauditBtn" Content="Re-Audit (F5)" Style="{StaticResource ActionBtn}"/>
                </StackPanel>
            </DockPanel>
        </Grid>
    </Grid>
</Window>
"@

$Reader          = New-Object System.Xml.XmlNodeReader $Xaml;
$Window          = [Windows.Markup.XamlReader]::Load($Reader);

$BannerBorder    = $Window.FindName("BannerBorder");
$BannerIconBg    = $Window.FindName("BannerIconBg");
$BannerIcon      = $Window.FindName("BannerIcon");
$BannerTitle     = $Window.FindName("BannerTitle");
$BannerSubtitle  = $Window.FindName("BannerSubtitle");
$ConnDot         = $Window.FindName("ConnDot");
$ConnLabel       = $Window.FindName("ConnLabel");

$CardRulesBorder = $Window.FindName("CardRulesBorder");
$CardRulesPill   = $Window.FindName("CardRulesPill");
$CardRulesBadge  = $Window.FindName("CardRulesBadge");
$CardRulesStatus = $Window.FindName("CardRulesStatus");
$CardRulesDetail = $Window.FindName("CardRulesDetail");

$CardFileBorder  = $Window.FindName("CardFileBorder");
$CardFilePill    = $Window.FindName("CardFilePill");
$CardFileBadge   = $Window.FindName("CardFileBadge");
$CardFileStatus  = $Window.FindName("CardFileStatus");
$CardFileDetail  = $Window.FindName("CardFileDetail");

$CardCronBorder  = $Window.FindName("CardCronBorder");
$CardCronPill    = $Window.FindName("CardCronPill");
$CardCronBadge   = $Window.FindName("CardCronBadge");
$CardCronStatus  = $Window.FindName("CardCronStatus");
$CardCronDetail  = $Window.FindName("CardCronDetail");

$LogBox          = $Window.FindName("LogBox");
$CountdownBar    = $Window.FindName("CountdownBar");
$CountdownText   = $Window.FindName("CountdownText");
$PinBtn          = $Window.FindName("PinBtn");
$RebuildBtn      = $Window.FindName("RebuildBtn");
$ReauditBtn      = $Window.FindName("ReauditBtn");

<# Populate Dynamic Labels #>
$Window.Title         = "$DeviceLabel - DNS Watchdog";
$ConnLabel.Text       = $router;
$CardRulesDetail.Text = "Target: dport 53 DNAT to $RouterIP";

<# Apply Windows 10/11 Dark Title Bar #>
$Window.Add_SourceInitialized({
    $Hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($Window)).Handle;
    $UseDark = 1;
    [void][DwmTheme]::DwmSetWindowAttribute($Hwnd, 20, [ref]$UseDark, 4);
    [void][DwmTheme]::DwmSetWindowAttribute($Hwnd, 19, [ref]$UseDark, 4);
});

<# UI Helpers #>
$BrushConverter = New-Object System.Windows.Media.BrushConverter;
function Get-Brush([string]$Hex) {
    return $BrushConverter.ConvertFromString($Hex);
}

function Write-Telemetry([string]$Level = "INFO", [string]$Message) {
    $Colors = @{
        INFO  = "#8B949E";
        CHECK = "#38BDF8";
        OK    = "#3FB950";
        WARN  = "#D29922";
        HEAL  = "#A371F7";
        ERR   = "#F85149";
    };
    $Time = (Get-Date).ToString("HH:mm:ss");
    $Para = New-Object System.Windows.Documents.Paragraph;
    $Para.Margin = New-Object System.Windows.Thickness(0, 1, 0, 2);

    $RunTime = New-Object System.Windows.Documents.Run("[$Time] ");
    $RunTime.Foreground = Get-Brush "#6E7681";

    $Tag = ("[{0}]" -f $Level).PadRight(8);
    $RunTag = New-Object System.Windows.Documents.Run($Tag);
    $RunTag.Foreground = Get-Brush $Colors[$Level];
    $RunTag.FontWeight = [System.Windows.FontWeights]::Bold;

    $RunMsg = New-Object System.Windows.Documents.Run($Message);
    $RunMsg.Foreground = Get-Brush "#E6EDF3";

    $Para.Inlines.Add($RunTime);
    $Para.Inlines.Add($RunTag);
    $Para.Inlines.Add($RunMsg);

    $LogBox.Document.Blocks.Add($Para);
    $LogBox.ScrollToEnd();
}

function Set-CardState([string]$Card, [string]$State, [string]$Badge, [string]$Status, [string]$Detail = "") {
    $Styles = @{
        CHECKING = @{ Border = "#38BDF8"; PillBg = "#13233A"; Text = "#38BDF8" };
        OK       = @{ Border = "#238636"; PillBg = "#12261E"; Text = "#3FB950" };
        WARN     = @{ Border = "#9E6A03"; PillBg = "#2B2111"; Text = "#D29922" };
        ERR      = @{ Border = "#DA3633"; PillBg = "#2A1517"; Text = "#F85149" };
    };
    $S = $Styles[$State];

    switch ($Card) {
        "Rules" {
            $CardRulesBorder.BorderBrush = Get-Brush $S.Border;
            $CardRulesPill.Background    = Get-Brush $S.PillBg;
            $CardRulesBadge.Foreground   = Get-Brush $S.Text;
            $CardRulesBadge.Text         = $Badge;
            $CardRulesStatus.Text        = $Status;
            if ($Detail) { $CardRulesDetail.Text = $Detail; };
        }
        "File" {
            $CardFileBorder.BorderBrush = Get-Brush $S.Border;
            $CardFilePill.Background    = Get-Brush $S.PillBg;
            $CardFileBadge.Foreground   = Get-Brush $S.Text;
            $CardFileBadge.Text         = $Badge;
            $CardFileStatus.Text        = $Status;
            if ($Detail) { $CardFileDetail.Text = $Detail; };
        }
        "Cron" {
            $CardCronBorder.BorderBrush = Get-Brush $S.Border;
            $CardCronPill.Background    = Get-Brush $S.PillBg;
            $CardCronBadge.Foreground   = Get-Brush $S.Text;
            $CardCronBadge.Text         = $Badge;
            $CardCronStatus.Text        = $Status;
            if ($Detail) { $CardCronDetail.Text = $Detail; };
        }
    };
}

function Set-BannerState([string]$State, [string]$Title, [string]$Subtitle) {
    $Styles = @{
        WORKING = @{ Bg = "#161B22"; Border = "#30363D"; IconBg = "#13233A"; Accent = "#38BDF8" };
        OK      = @{ Bg = "#111D18"; Border = "#238636"; IconBg = "#163024"; Accent = "#3FB950" };
        HEAL    = @{ Bg = "#1E1912"; Border = "#9E6A03"; IconBg = "#2E2312"; Accent = "#D29922" };
        ERR     = @{ Bg = "#201315"; Border = "#DA3633"; IconBg = "#33181B"; Accent = "#F85149" };
    };
    $S = $Styles[$State];
    $BannerBorder.Background   = Get-Brush $S.Bg;
    $BannerBorder.BorderBrush  = Get-Brush $S.Border;
    $BannerIconBg.Background   = Get-Brush $S.IconBg;
    $BannerIcon.Fill           = Get-Brush $S.Accent;
    $ConnDot.Fill              = Get-Brush $S.Accent;
    $BannerTitle.Text          = $Title;
    $BannerSubtitle.Text       = $Subtitle;
    $CountdownBar.Foreground   = Get-Brush $S.Accent;
}

<# Watchdog Payload streamed as pure UTF-8 LF bytes (no PowerShell CRLF pipe) #>
function Deploy-FullWatchdog {
    $payload = @"
cat << 'EOF' > /jffs/dns_watchdog.sh
#!/bin/sh
PATH=/bin:/sbin:/usr/bin:/usr/sbin
if ! iptables -t nat -L PREROUTING -n | grep -q "$RouterIP"; then
    logger -t "DNS_WATCHDOG" "Rules missing. Injecting Port 53 redirects."
    iptables -t nat -D PREROUTING -i $LanInterface -p udp --dport 53 -j DNAT --to $RouterIP 2>/dev/null
    iptables -t nat -I PREROUTING -i $LanInterface -p udp --dport 53 -j DNAT --to $RouterIP
    iptables -t nat -D PREROUTING -i $LanInterface -p tcp --dport 53 -j DNAT --to $RouterIP 2>/dev/null
    iptables -t nat -I PREROUTING -i $LanInterface -p tcp --dport 53 -j DNAT --to $RouterIP
    ip6tables -D FORWARD -i $LanInterface -p udp --dport 53 -j REJECT 2>/dev/null
    ip6tables -I FORWARD -i $LanInterface -p udp --dport 53 -j REJECT
    ip6tables -D FORWARD -i $LanInterface -p tcp --dport 53 -j REJECT 2>/dev/null
    ip6tables -I FORWARD -i $LanInterface -p tcp --dport 53 -j REJECT
else
    logger -t "DNS_WATCHDOG" "Rules present. No action taken."
fi
EOF
chmod +x /jffs/dns_watchdog.sh
cru a dns_watchdog "*/5 * * * * /jffs/dns_watchdog.sh"
sh /jffs/dns_watchdog.sh
exit 0
"@

    $payload = ($payload -replace "`r`n", "`n") + "`n";

    $psi = New-Object System.Diagnostics.ProcessStartInfo;
    $psi.FileName = "ssh.exe";
    $psi.Arguments = "-T -o BatchMode=yes -o ConnectTimeout=5 -i `"$KeyPath`" $router";
    $psi.UseShellExecute = $false;
    $psi.RedirectStandardInput = $true;
    $psi.RedirectStandardOutput = $true;
    $psi.RedirectStandardError = $true;
    $psi.CreateNoWindow = $true;

    $proc = [System.Diagnostics.Process]::Start($psi);
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false);
    $bytes = $utf8NoBom.GetBytes($payload);
    $proc.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length);
    $proc.StandardInput.BaseStream.Flush();
    $proc.StandardInput.Close();

    $stdOut = $proc.StandardOutput.ReadToEnd();
    $stdErr = $proc.StandardError.ReadToEnd();
    $proc.WaitForExit();

    $global:LASTEXITCODE = $proc.ExitCode;
    return ("$stdOut`n$stdErr").Trim();
}

<# Timers & State Machine #>
$Script:AuditStep       = 0;
$Script:ForceRebuild    = $false;
$Script:rulesPresent    = $false;
$Script:filePresent     = $false;
$Script:cronPresent     = $false;
$Script:AutoClosePaused = ($AutoCloseSec -le 0);
$Script:CountdownStart  = [DateTime]::MinValue;

$CountdownTimer = New-Object System.Windows.Threading.DispatcherTimer;
$CountdownTimer.Interval = [TimeSpan]::FromMilliseconds(200);
$CountdownTimer.Add_Tick({
    if ($Script:AutoClosePaused) {
        $CountdownTimer.Stop();
        return;
    };
    $Elapsed   = ([DateTime]::Now - $Script:CountdownStart).TotalSeconds;
    $Remaining = [Math]::Max(0, $AutoCloseSec - $Elapsed);
    $Pct       = ($Remaining / $AutoCloseSec) * 100;
    $CountdownBar.Value = $Pct;

    $TimeLeft = [TimeSpan]::FromSeconds([Math]::Ceiling($Remaining)).ToString("mm\:ss");
    $CountdownText.Text = "Audit complete. Auto-closing in $TimeLeft... (Esc to close)";

    if ($Remaining -le 0) {
        $CountdownTimer.Stop();
        $Window.Close();
    };
});

function Stop-AutoClose {
    if (-not $Script:AutoClosePaused) {
        $Script:AutoClosePaused = $true;
        $CountdownTimer.Stop();
        $CountdownBar.Value = 100;
        $CountdownText.Text = "Auto-close paused. Press Esc to close or F5 to re-audit.";
        $PinBtn.Content = "Pinned";
        $PinBtn.IsEnabled = $false;
    };
}

if ($Script:AutoClosePaused) {
    $CountdownBar.Value = 100;
    $CountdownText.Text = "Auto-close disabled. Press Esc to close or F5 to re-audit.";
    $PinBtn.Content = "Pinned";
    $PinBtn.IsEnabled = $false;
}

$AuditTimer = New-Object System.Windows.Threading.DispatcherTimer;
$AuditTimer.Interval = [TimeSpan]::FromMilliseconds(90);
$AuditTimer.Add_Tick({
    switch ($Script:AuditStep) {
        0 {
            $ReauditBtn.IsEnabled = $false;
            $RebuildBtn.IsEnabled = $false;
            Set-BannerState "WORKING" "AUDITING DNS WATCHDOG STATE..." "Running SSH diagnostics against $router";
            Set-CardState "Rules" "CHECKING" "CHECKING" "Querying NAT...";
            Set-CardState "File"  "CHECKING" "QUEUED"   "Waiting...";
            Set-CardState "Cron"  "CHECKING" "QUEUED"   "Waiting...";
            Write-Telemetry "CHECK" "Auditing DNS Watchdog State...";
            $Script:AuditStep = 1;
        }

        1 {
            $currentRules = ssh -n -o BatchMode=yes -o ConnectTimeout=5 -i "$KeyPath" $router "iptables -t nat -S PREROUTING" 2>&1;
            if ($LASTEXITCODE -ne 0) {
                $AuditTimer.Stop();
                $ErrMsg = ($currentRules | Out-String).Trim();
                if (-not $ErrMsg) { $ErrMsg = "SSH connection failed."; };
                Set-BannerState "ERR" "SSH CONNECTION FAILED" "Unable to reach $router";
                Set-CardState "Rules" "ERR" "ERROR" "Unreachable";
                Set-CardState "File"  "ERR" "ERROR" "Unreachable";
                Set-CardState "Cron"  "ERR" "ERROR" "Unreachable";
                Write-Telemetry "ERR" "SSH failure: $ErrMsg";
                Stop-AutoClose;
                $ReauditBtn.IsEnabled = $true;
                $RebuildBtn.IsEnabled = $true;
                return;
            };

            $Script:rulesPresent = (($currentRules -join "") -match "dport 53 -j DNAT");
            if ($Script:rulesPresent) {
                $DnatCount = @($currentRules | Where-Object { $_ -match "dport 53 -j DNAT" }).Count;
                Set-CardState "Rules" "OK" "ACTIVE" "$DnatCount DNAT rule(s) active" "Redirecting :53 to $RouterIP";
                Write-Telemetry "OK" "Rules Present: True ($DnatCount PREROUTING DNAT rules matched)";
            } else {
                Set-CardState "Rules" "WARN" "MISSING" "No Port 53 DNAT" "Redirects not found in PREROUTING";
                Write-Telemetry "WARN" "Rules Present: False (dport 53 DNAT missing)";
            };
            $Script:AuditStep = 2;
        }

        2 {
            Set-CardState "File" "CHECKING" "CHECKING" "Checking /jffs...";
            $fileExists = ssh -n -o BatchMode=yes -o ConnectTimeout=5 -i "$KeyPath" $router "[ -f /jffs/dns_watchdog.sh ] && echo 'YES' || echo 'NO'" 2>&1;
            $Script:filePresent = (($fileExists -join "") -match "YES");

            if ($Script:filePresent) {
                Set-CardState "File" "OK" "PRESENT" "Script verified" "/jffs/dns_watchdog.sh";
                Write-Telemetry "OK" "File Present:  True (/jffs/dns_watchdog.sh exists)";
            } else {
                Set-CardState "File" "ERR" "MISSING" "Script missing" "/jffs/dns_watchdog.sh not found";
                Write-Telemetry "WARN" "File Present:  False (/jffs/dns_watchdog.sh missing)";
            };
            $Script:AuditStep = 3;
        }

        3 {
            Set-CardState "Cron" "CHECKING" "CHECKING" "Querying cru l...";
            $cronCheck = ssh -n -o BatchMode=yes -o ConnectTimeout=5 -i "$KeyPath" $router "cru l" 2>&1;
            $Script:cronPresent = (($cronCheck -join "") -match "\*/5 \* \* \* \* /jffs/dns_watchdog\.sh");

            if ($Script:cronPresent) {
                Set-CardState "Cron" "OK" "SCHEDULED" "Every 5 minutes" "*/5 * * * * /jffs/dns_watchdog.sh";
                Write-Telemetry "OK" "Cron Present:  True (dns_watchdog scheduled every 5m)";
            } else {
                Set-CardState "Cron" "ERR" "MISSING" "Job not scheduled" "Missing from cru l output";
                Write-Telemetry "WARN" "Cron Present:  False (cron entry missing)";
            };
            $Script:AuditStep = 4;
        }

        4 {
            if (-not $Script:ForceRebuild -and $Script:filePresent -and $Script:cronPresent) {
                if (-not $Script:rulesPresent) {
                    Set-BannerState "HEAL" "SELF-HEALING: INJECTING DNS RULES" "File and cron are present, but rules are missing. Triggering script...";
                    Write-Telemetry "HEAL" "File and cron are present, but rules are missing. Triggering script to inject rules...";
                    $null = ssh -n -o BatchMode=yes -o ConnectTimeout=5 -i "$KeyPath" $router "sh /jffs/dns_watchdog.sh" 2>&1;

                    $VerifyRules = ssh -n -o BatchMode=yes -o ConnectTimeout=5 -i "$KeyPath" $router "iptables -t nat -S PREROUTING" 2>&1;
                    if (($VerifyRules -join "") -match "dport 53 -j DNAT") {
                        $DnatCount = @($VerifyRules | Where-Object { $_ -match "dport 53 -j DNAT" }).Count;
                        Set-CardState "Rules" "OK" "INJECTED" "$DnatCount DNAT rule(s) active" "Injected via dns_watchdog.sh";
                        Set-BannerState "OK" "RULES INJECTED SUCCESSFULLY" "Port 53 IPv4 DNAT and IPv6 REJECT rules are now active.";
                        Write-Telemetry "OK" "Rules injected successfully.";
                    } else {
                        Set-BannerState "ERR" "RULE INJECTION FAILED" "Script executed but DNAT rules were not detected.";
                        Write-Telemetry "ERR" "Verification failed after running /jffs/dns_watchdog.sh.";
                        Stop-AutoClose;
                    };
                } else {
                    Set-BannerState "OK" "ALL SYSTEMS NOMINAL" "File, cron job, and rules are all present.";
                    Write-Telemetry "OK" "File, cron job, and rules are all present.";
                };
            } else {
                $Reason = if ($Script:ForceRebuild) { "Manual rebuild triggered" } else { "File or cron job is missing" };
                Set-BannerState "HEAL" "REBUILDING WATCHDOG & INJECTING RULES" "$Reason. Rebuilding file, cron, and injecting rules...";
                Write-Telemetry "HEAL" "$Reason. Rebuilding file, cron, and injecting rules...";

                $DeployOut = Deploy-FullWatchdog;
                if ($LASTEXITCODE -eq 0) {
                    Set-CardState "File"  "OK" "DEPLOYED"   "Script created"    "chmod +x /jffs/dns_watchdog.sh";
                    Set-CardState "Cron"  "OK" "REGISTERED" "Every 5 minutes"   "cru a dns_watchdog active";
                    Set-CardState "Rules" "OK" "INJECTED"   "DNAT rules active" "IPv4 :53 DNAT + IPv6 REJECT";
                    Set-BannerState "OK" "RECOVERY COMPLETE" "File, cron, and rules have been deployed.";
                    Write-Telemetry "OK" "Recovery complete. File, cron, and rules have been deployed.";
                } else {
                    $ErrText = ($DeployOut | Out-String).Trim();
                    Set-BannerState "ERR" "RECOVERY FAILED" "Error deploying watchdog payload over SSH.";
                    Write-Telemetry "ERR" "Deployment error: $ErrText";
                    Stop-AutoClose;
                };
            };

            $Script:ForceRebuild  = $false;
            $ReauditBtn.IsEnabled = $true;
            $RebuildBtn.IsEnabled = $true;
            $AuditTimer.Stop();

            if (-not $Script:AutoClosePaused) {
                $Script:CountdownStart = [DateTime]::Now;
                $CountdownTimer.Start();
            };
        }
    };
});

function Start-Audit([bool]$Rebuild = $false) {
    $CountdownTimer.Stop();
    $LogBox.Document.Blocks.Clear();
    $Script:ForceRebuild = $Rebuild;
    $Script:AuditStep = 0;
    $AuditTimer.Start();
}

<# Interactive Controls #>
$PinBtn.Add_Click({ Stop-AutoClose; });
$LogBox.Add_PreviewMouseDown({ Stop-AutoClose; });

$ReauditBtn.Add_Click({
    Stop-AutoClose;
    Start-Audit $false;
});

$RebuildBtn.Add_Click({
    Stop-AutoClose;
    $Confirm = [System.Windows.MessageBox]::Show(
        "Overwrite /jffs/dns_watchdog.sh, re-register the 5-minute cron job, and re-apply DNS firewall rules on " + $RouterIP + "?",
        "Confirm Watchdog Rebuild",
        "YesNo",
        "Question"
    );
    if ($Confirm -eq "Yes") {
        Start-Audit $true;
    };
});

$Window.Add_KeyDown({
    param($Sender, $EventArgs);
    if ($EventArgs.Key -eq 'Escape') { $Window.Close(); }
    elseif ($EventArgs.Key -eq 'F5') {
        Stop-AutoClose;
        Start-Audit $false;
    };
});

$Window.Add_ContentRendered({
    Start-Audit $false;
});

[void]$Window.ShowDialog();

