param(
    [ValidateSet("apply", "enable", "disable", "status", "menu")]
    [string]$Action = "apply"
)

$ErrorActionPreference = "Stop"
$ToolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Adb = Join-Path $ToolDir "adb.exe"
$Fastboot = Join-Path $ToolDir "fastboot.exe"
$Twrp = Join-Path $ToolDir "twrp.img"
$JsonFile = Join-Path $ToolDir "install-control.json"
$ShellScript = Join-Path $ToolDir "apply-install-control.sh"
$RemoteJson = "/sdcard/install-control.json"
$RemoteScript = "/sdcard/apply-install-control.sh"

function Invoke-Tool {
    param(
        [Parameter(Mandatory = $true)][string]$Program,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments
    )
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed ($LASTEXITCODE): $Program $($Arguments -join ' ')"
    }
}

function Wait-AdbState {
    param(
        [Parameter(Mandatory = $true)][string]$State,
        [int]$TimeoutSeconds = 120
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        try {
            $lines = & $Adb devices 2>&1 | Out-String
        } catch {
            $lines = ""
        }
        if ($lines.Trim() -match "\s$State") { return }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    throw "Timed out waiting for ADB state: $State"
}

function Wait-Fastboot {
    param([int]$TimeoutSeconds = 60)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        try {
            $devices = & $Fastboot devices 2>&1 | Out-String
        } catch {
            $devices = ""
        }
        if ($devices.Trim() -match "\sfastboot") { return }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    throw "Timed out waiting for Fastboot. Check the USB connection."
}

function Wait-AndroidBoot {
    param([int]$TimeoutSeconds = 300)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        try {
            $state = & $Adb get-state 2>&1 | Out-String
        } catch {
            $state = ""
        }
        if ($state.Trim() -eq "device") {
            try {
                $bootCompleted = (& $Adb shell getprop sys.boot_completed 2>&1 | Out-String).Trim()
            } catch {
                $bootCompleted = ""
            }
            if ($bootCompleted -eq "1") { return }
        }
        Start-Sleep -Seconds 3
    } while ((Get-Date) -lt $deadline)
    throw "Android did not finish booting within $TimeoutSeconds seconds."
}

function Get-JsonConfig {
    if (-not (Test-Path -LiteralPath $JsonFile)) {
        throw "Missing config: $JsonFile"
    }
    $raw = Get-Content -LiteralPath $JsonFile -Raw
    try {
        $config = $raw | ConvertFrom-Json
    } catch {
        throw "Invalid JSON in $JsonFile : $_"
    }
    return $config
}

function Show-JsonConfig {
    param([string]$Label)
    $config = Get-JsonConfig
    $fields = @(
        @("install",       "install",       { param($v) if ($v -eq 0) { "BLOCK install" } else { "ALLOW install" } }),
        @("hideStore",     "hideStore",     { param($v) if ($v -eq 1) { "store hidden" } else { "store shown" } }),
        @("browserOff",    "browserOff",    { param($v) if ($v -eq 1) { "browser off" } else { "browser on" } }),
        @("musicOff",      "musicOff",      { param($v) if ($v -eq 1) { "music off" } else { "music on" } }),
        @("readerOff",     "readerOff",     { param($v) if ($v -eq 1) { "reader off" } else { "reader on" } }),
        @("updaterOff",    "updaterOff",    { param($v) if ($v -eq 1) { "updater off" } else { "updater on" } }),
        @("walletOff",     "walletOff",     { param($v) if ($v -eq 1) { "wallet off" } else { "wallet on" } }),
        @("emailOff",      "emailOff",      { param($v) if ($v -eq 1) { "email off" } else { "email on" } }),
        @("globalSimOff",  "globalSimOff",  { param($v) if ($v -eq 1) { "globalSIM off" } else { "globalSIM on" } }),
        @("vipAccountOff", "vipAccountOff", { param($v) if ($v -eq 1) { "myXiaomi off" } else { "myXiaomi on" } })
    )
    Write-Host ""
    Write-Host $Label -ForegroundColor Cyan
    foreach ($f in $fields) {
        $val = $config.($f[1])
        $desc = & $f[2] $val
        $name = $f[0].PadRight(14)
        Write-Host "  $name = $val  ($desc)"
    }
}

function Set-JsonField {
    param([string]$Field, [int]$Value)
    $config = Get-JsonConfig
    $config.$Field = $Value
    $config | ConvertTo-Json -Compress | Set-Content -LiteralPath $JsonFile -NoNewline
}

function Get-RestrictionStatus {
    $userInfo = & $Adb shell dumpsys user 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to read Android user restrictions. Is the phone connected?"
    }
    $installBlocked = [bool]($userInfo -match "^\s+no_install_apps\s*$")
    $unknownBlocked = [bool]($userInfo -match "^\s+no_install_unknown_sources\s*$")
    Write-Host ""
    Write-Host "Phone restriction status"
    Write-Host "  App installation blocked : $installBlocked"
    Write-Host "  Unknown sources blocked  : $unknownBlocked"
    if ($installBlocked) {
        Write-Host "  Result                   : DISABLED (installation blocked)" -ForegroundColor Yellow
    } else {
        Write-Host "  Result                   : ENABLED (installation allowed)" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "Launcher visibility:"
    $apps = @(
        @("com.xiaomi.market", "Market"),
        @("com.android.browser", "Browser"),
        @("com.miui.player", "Music"),
        @("com.duokan.reader", "Reader"),
        @("com.android.updater", "Updater"),
        @("com.mipay.wallet", "Wallet"),
        @("com.android.email", "Email"),
        @("com.miui.virtualsim", "GlobalSIM"),
        @("com.xiaomi.vipaccount", "MyXiaomi")
    )
    foreach ($app in $apps) {
        $result = & $Adb shell "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER $($app[0])" 2>$null
        if ($result -match "No activity found") {
            Write-Host "  $($app[1].PadRight(12)) hidden" -ForegroundColor Yellow
        } else {
            Write-Host "  $($app[1].PadRight(12)) visible" -ForegroundColor Green
        }
    }
}

function Apply-Config {
    if (-not (Test-Path -LiteralPath $Twrp)) { throw "Missing TWRP image: $Twrp" }
    if (-not (Test-Path -LiteralPath $JsonFile)) { throw "Missing $JsonFile" }
    if (-not (Test-Path -LiteralPath $ShellScript)) { throw "Missing $ShellScript" }

    Show-JsonConfig "Applying config from install-control.json"

    Write-Host ""
    $fbDevices = & $Fastboot devices 2>$null
    if ($fbDevices -match "\sfastboot$") {
        Write-Host "Phone already in Fastboot, booting TWRP directly..."
    } else {
        Write-Host "Rebooting to Fastboot..."
        & $Adb reboot bootloader 2>&1 | Out-Null
        Start-Sleep -Seconds 8
        Wait-Fastboot
    }

    Write-Host "Temporarily booting TWRP..."
    Invoke-Tool $Fastboot boot $Twrp
    Wait-AdbState -State "recovery" -TimeoutSeconds 120
    Start-Sleep -Seconds 3

    Write-Host "Pushing config and script to phone..."
    Invoke-Tool $Adb push $JsonFile $RemoteJson
    Invoke-Tool $Adb push $ShellScript $RemoteScript
    Invoke-Tool $Adb shell "chmod 755 $RemoteScript"

    Write-Host "Running apply-install-control.sh in TWRP..."
    $output = (& $Adb shell "/sbin/sh $RemoteScript" 2>&1) -join "`n"
    Write-Host $output
    if ($output -notmatch "OK:") {
        throw "Script failed. Check output above."
    }

    Write-Host "Rebooting Android..."
    & $Adb reboot system 2>&1 | Out-Null
    Start-Sleep -Seconds 5
    Wait-AndroidBoot

    Write-Host ""
    Get-RestrictionStatus
}

if (-not (Test-Path -LiteralPath $Adb) -or -not (Test-Path -LiteralPath $Fastboot)) {
    throw "adb.exe and fastboot.exe must be in the same directory as this script."
}

switch ($Action) {
    "apply"  { Apply-Config }
    "enable" { Set-JsonField "install" 1; Apply-Config }
    "disable" { Set-JsonField "install" 0; Apply-Config }
    "status"  { Wait-AdbState -State "device" -TimeoutSeconds 10; Get-RestrictionStatus }
    "menu"   { Apply-Config }
}
