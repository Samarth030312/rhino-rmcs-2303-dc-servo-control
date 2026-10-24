# Rhino DC Servo Lab: one-step set-up for Windows 10 / 11 (Windows PowerShell 5.1 or PowerShell 7).
#
#   From PowerShell:
#     [Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/Samarth030312/rhino-rmcs-2303-dc-servo-control/main/install/windows/install.ps1 | iex
#   From Command Prompt (cmd):
#     powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/Samarth030312/rhino-rmcs-2303-dc-servo-control/main/install/windows/install.ps1 | iex"
#
# What it does (no admin rights needed, except winget may ask once to install Git):
#   1. installs Git if missing (winget), else falls back to a ZIP download
#   2. clones the repository to %USERPROFILE%\rhino-rmcs-2303-dc-servo-control, or updates it (git pull)
#   3. looks for a CH340 / Arduino board without a working USB driver and says what to do
#   4. finds MATLAB and starts it with setup open, which installs the Arduino toolchain
#      (into %LOCALAPPDATA%\arduino-lab-tools) on first use and opens the app
#
# Options (environment variables, set before running):
#   SERVOLAB_DIR       where to put the repository   (default %USERPROFILE%\rhino-rmcs-2303-dc-servo-control)
#   SERVOLAB_NO_LAUNCH =1: do not start MATLAB         (used by CI)

$ErrorActionPreference = 'Stop'
$RepoUrl = 'https://github.com/Samarth030312/rhino-rmcs-2303-dc-servo-control.git'
$ZipUrl  = 'https://github.com/Samarth030312/rhino-rmcs-2303-dc-servo-control/archive/refs/heads/main.zip'
$Dir = $env:SERVOLAB_DIR
if (-not $Dir) { $Dir = Join-Path $env:USERPROFILE 'rhino-rmcs-2303-dc-servo-control' }

function Say($m)  { Write-Host "==> $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "!!  $m" -ForegroundColor Yellow }
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

Write-Host ''
Write-Host 'Rhino DC Servo Lab set-up (Windows)' -ForegroundColor White
Write-Host "Repository folder: $Dir"
Write-Host ''

# ---------------------------------------------------------------- 1. Git
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Say 'Installing Git with winget (accept the prompt if Windows asks) ...'
        winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements --silent | Out-Host
        Refresh-Path
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            foreach ($p in @("$env:ProgramFiles\Git\cmd", "$env:LOCALAPPDATA\Programs\Git\cmd")) {
                if (Test-Path (Join-Path $p 'git.exe')) { $env:Path += ";$p" }
            }
        }
        $git = Get-Command git -ErrorAction SilentlyContinue
    }
    if (-not $git) { Warn 'Git could not be installed: using a ZIP download instead (install Git later to pull updates and push data).' }
}

# ---------------------------------------------------------------- 2. the repository
if ($git) {
    if (Test-Path (Join-Path $Dir '.git')) {
        Say "Updating $Dir (git pull) ..."
        git -C $Dir pull --ff-only
        if ($LASTEXITCODE -ne 0) { Warn 'git pull did not fast-forward (local changes?). Continuing with the copy you have.' }
    } elseif (Test-Path $Dir) {
        throw "$Dir exists but is not a git checkout. Rename it, or set SERVOLAB_DIR to another folder, and run this again."
    } else {
        Say "Cloning into $Dir ..."
        git clone $RepoUrl $Dir
        if ($LASTEXITCODE -ne 0) { throw 'git clone failed: check the internet connection or proxy.' }
    }
} else {
    if (Test-Path $Dir) {
        Warn "$Dir already exists: left as it is (delete or rename it to download a fresh copy)."
    } else {
        $zip = Join-Path $env:TEMP 'rhino-rmcs-2303-dc-servo-control-main.zip'
        $tmp = Join-Path $env:TEMP 'rhino-rmcs-2303-dc-servo-control-unzip'
        Say 'Downloading the repository (ZIP) ...'
        Invoke-WebRequest -UseBasicParsing -Uri $ZipUrl -OutFile $zip
        if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
        Expand-Archive -Path $zip -DestinationPath $tmp -Force
        Move-Item (Join-Path $tmp 'rhino-rmcs-2303-dc-servo-control-main') $Dir
        Remove-Item -Force $zip; Remove-Item -Recurse -Force $tmp
    }
}
if (-not (Test-Path (Join-Path $Dir 'setup.m'))) { throw "The repository in $Dir is incomplete (setup.m missing)." }

# ---------------------------------------------------------------- 3. USB driver
try {
    $boards = Get-PnpDevice -PresentOnly -ErrorAction Stop | Where-Object { $_.InstanceId -match 'VID_(1A86|2341|2A03|0403|10C4)' }
} catch { $boards = @() }
foreach ($b in $boards) {
    if ($b.Status -eq 'OK' -and $b.Class -eq 'Ports') {
        Say "Board found: $($b.FriendlyName)"
    } elseif ($b.InstanceId -match 'VID_1A86') {
        Warn "`"$($b.FriendlyName)`" (CH340 chip, clone Uno) has no working driver."
        Warn 'Device Manager opens: right-click the device under "Other devices" > Update driver > Search automatically.'
        Warn 'If Windows finds nothing, install CH341SER.EXE from the page that opens (the chip maker, WCH), then replug the board.'
        Start-Process devmgmt.msc
        Start-Process 'https://www.wch-ic.com/downloads/CH341SER_EXE.html'
    } else {
        Warn "`"$($b.FriendlyName)`" has no working driver: install the Arduino IDE once (winget install --id ArduinoSA.IDE.stable -e)."
    }
}
if (-not $boards) { Say 'No Arduino plugged in yet (fine: plug it in later; the app notices it).' }

# ---------------------------------------------------------------- 4. MATLAB
$matlab = $null
$cmd = Get-Command matlab -ErrorAction SilentlyContinue
if ($cmd) { $matlab = $cmd.Source }
if (-not $matlab) {
    $c = Get-ChildItem -Path "$env:ProgramFiles\MATLAB\R20*\bin\matlab.exe" -ErrorAction SilentlyContinue |
         Sort-Object FullName -Descending | Select-Object -First 1
    if ($c) { $matlab = $c.FullName }
}
$mdir = $Dir
Write-Host ''
if ($env:SERVOLAB_NO_LAUNCH -eq '1') {
    Say 'Done (MATLAB not started: SERVOLAB_NO_LAUNCH=1).'
} elseif ($matlab) {
    Say "Starting MATLAB ($matlab). It installs the Arduino toolchain the first time (about 60 MB), then opens the lab."
    $arg = "-r `"cd('" + $mdir.Replace("'", "''") + "'); setup open`""
    Start-Process -FilePath $matlab -ArgumentList $arg
} else {
    Warn 'MATLAB was not found. Install MATLAB R2023b or newer, then in MATLAB run:'
    Write-Host "      cd('$mdir'); setup open"
}
Write-Host ''
Write-Host 'Next time: open MATLAB and run   cd(''' + $mdir + '''); setup open'
Write-Host 'Problems:  in MATLAB run         setup fix'
Write-Host 'Push recorded data: ask the owner to add your GitHub account as a collaborator, then'
Write-Host "      git -C `"$Dir`" add data results && git -C `"$Dir`" commit -m `"data: <what you ran>`" && git -C `"$Dir`" push"
Write-Host ''
