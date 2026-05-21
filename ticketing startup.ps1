#Requires -Version 5.1
<#
.SYNOPSIS
  TacticalTickets: verify prerequisites, install missing dependencies, migrate, build the SPA, then start a production-oriented stack on Windows.

.DESCRIPTION
  - Checks Python (3.12+), Node.js (per Frontend/package.json engines), and npm; prints download links when something is missing.
  - Ensures Backend venv exists; installs pinned Django stack + Waitress if imports fail.
  - Ensures Frontend node_modules; runs npm ci when package-lock.json exists, otherwise npm install.
  - Runs migrate + Django system checks; builds Frontend (unless -SkipFrontendBuild).
  - Launches Waitress (WSGI) for the API and `vite preview` for the built SPA in separate console windows.

.NOTES
  Default URLs: API http://0.0.0.0:8000/  SPA http://0.0.0.0:5174/
  Real internet-facing production still requires hardening Django settings (SECRET_KEY, DEBUG, ALLOWED_HOSTS, CORS, HTTPS). This script automates a production *build* and a suitable Windows process layout.

.EXAMPLE
  .\ticketing startup.ps1

.EXAMPLE
  .\ticketing startup.ps1 -SkipFrontendBuild -ApiPort 8080 -WebPort 3000
#>
[CmdletBinding()]
param(
    [int]$ApiPort = 8000,
    [int]$WebPort = 5174,
    [switch]$SkipFrontendBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) {
    Write-Host "[ticketing] $Message" -ForegroundColor Cyan
}

function Write-Fail([string]$Message) {
    Write-Host "[ticketing] $Message" -ForegroundColor Red
}

function Get-PythonInvocation {
    # Prefer py launcher with 3.12+, then python / python3 on PATH.
    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($py) {
        $v = & py -3.12 --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $v -match 'Python (\d+)\.(\d+)') {
            $ver = [version]"$($Matches[1]).$($Matches[2]).0"
            if ($ver -ge [version]'3.12.0') {
                return @{ Exe = 'py'; Args = @('-3.12') }
            }
        }
        $v2 = & py -3 --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $v2 -match 'Python (\d+)\.(\d+)') {
            $ver2 = [version]"$($Matches[1]).$($Matches[2]).0"
            if ($ver2 -ge [version]'3.12.0') {
                return @{ Exe = 'py'; Args = @('-3') }
            }
        }
    }
    foreach ($name in @('python', 'python3')) {
        $c = Get-Command $name -ErrorAction SilentlyContinue
        if (-not $c) { continue }
        $out = & $name --version 2>&1
        if ($out -match 'Python (\d+)\.(\d+)\.(\d+)') {
            $ver3 = [version]"$($Matches[1]).$($Matches[2]).$($Matches[3])"
            if ($ver3 -ge [version]'3.12.0') {
                return @{ Exe = $name; Args = @() }
            }
        }
    }
    return $null
}

function Test-NodeEngineOk([version]$v) {
    if ($v.Major -eq 20) { return $v -ge [version]'20.19.0' }
    if ($v.Major -eq 21) { return $false }
    return $v -ge [version]'22.12.0'
}

# Script lives in TacticalTickets; Backend and Frontend are under the same folder.
$TicketsRoot = $PSScriptRoot
$BackendRoot = Join-Path $TicketsRoot 'Backend'
$FrontendRoot = Join-Path $TicketsRoot 'Frontend'
$VenvPython = Join-Path $BackendRoot 'venv\Scripts\python.exe'
$WaitressServe = Join-Path $BackendRoot 'venv\Scripts\waitress-serve.exe'

if (-not (Test-Path -LiteralPath $BackendRoot)) {
    Write-Fail "Backend folder not found: $BackendRoot"
    exit 1
}
if (-not (Test-Path -LiteralPath $FrontendRoot)) {
    Write-Fail "Frontend folder not found: $FrontendRoot"
    exit 1
}

Write-Info 'Checking Python 3.12+ ...'
$pyInv = Get-PythonInvocation
if (-not $pyInv) {
    Write-Fail @'
Python 3.12 or newer is required but was not found on PATH (or py launcher could not run 3.12+).

Install options:
  - https://www.python.org/downloads/
  - winget install Python.Python.3.12

On Windows, enable "Add python.exe to PATH" during setup, or use the "py" launcher after install.
'@
    exit 1
}

Write-Info "Using Python: $($pyInv.Exe) $($pyInv.Args -join ' ')"

Write-Info 'Checking Node.js and npm ...'
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
$npmCmd = Get-Command npm -ErrorAction SilentlyContinue
if (-not $nodeCmd -or -not $npmCmd) {
    Write-Fail @'
Node.js 20.19+ (or 22.12+) and npm are required.

Install: https://nodejs.org/  (LTS 20.x or 22.x recommended)
winget: winget OpenJS.NodeJS.LTS
'@
    exit 1
}

$nodeVerRaw = (& node --version).Trim()
if ($nodeVerRaw -notmatch '^v(\d+)\.(\d+)\.(\d+)') {
    Write-Fail "Could not parse node version: $nodeVerRaw"
    exit 1
}
$nodeVer = [version]"$($Matches[1]).$($Matches[2]).$($Matches[3])"
if (-not (Test-NodeEngineOk $nodeVer)) {
    Write-Fail "Node $nodeVer does not satisfy Frontend/package.json engines (^20.19.0 || >=22.12.0). Upgrade Node.js from https://nodejs.org/"
    exit 1
}
Write-Info "Using Node $nodeVerRaw, npm $($npmCmd.Source)"

if (-not (Test-Path -LiteralPath $VenvPython)) {
    Write-Info 'Creating Python virtual environment (Backend\venv) ...'
    Push-Location -LiteralPath $BackendRoot
    try {
        if ($pyInv.Args.Count -gt 0) {
            & $pyInv.Exe @($pyInv.Args) '-m' 'venv' 'venv'
        }
        else {
            & $pyInv.Exe '-m' 'venv' 'venv'
        }
        if ($LASTEXITCODE -ne 0) { throw "venv creation failed with exit code $LASTEXITCODE" }
    }
    finally {
        Pop-Location
    }
}

$pipRequirements = @(
    'Django==6.0.4',
    'djangorestframework==3.17.1',
    'django-cors-headers==4.9.0',
    'waitress==3.0.2'
)

Write-Info 'Ensuring Python packages (Django, DRF, CORS, Waitress) ...'
$needsPipInstall = (-not (Test-Path -LiteralPath $WaitressServe))
if (-not $needsPipInstall) {
    & $VenvPython -c "import django, corsheaders, rest_framework, waitress" 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { $needsPipInstall = $true }
}

if ($needsPipInstall) {
    Write-Info 'Installing / upgrading pinned backend packages ...'
    & $VenvPython -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) { throw 'pip upgrade failed' }
    & $VenvPython -m pip install $pipRequirements
    if ($LASTEXITCODE -ne 0) { throw 'pip install failed' }
}

Write-Info 'Running Django migrations and checks ...'
Push-Location -LiteralPath $BackendRoot
try {
    & $VenvPython manage.py migrate --noinput
    if ($LASTEXITCODE -ne 0) { throw 'migrate failed' }
    & $VenvPython manage.py check
    if ($LASTEXITCODE -ne 0) { throw 'manage.py check failed' }
}
finally {
    Pop-Location
}

$lockPath = Join-Path $FrontendRoot 'package-lock.json'
$modulesPath = Join-Path $FrontendRoot 'node_modules'
if (-not (Test-Path -LiteralPath $modulesPath)) {
    Write-Info 'Installing frontend dependencies ...'
    Push-Location -LiteralPath $FrontendRoot
    try {
        if (Test-Path -LiteralPath $lockPath) {
            npm ci
        }
        else {
            Write-Info 'No package-lock.json; using npm install'
            npm install
        }
        if ($LASTEXITCODE -ne 0) { throw 'npm install failed' }
    }
    finally {
        Pop-Location
    }
}

if (-not $SkipFrontendBuild) {
    Write-Info 'Building frontend for production (npm run build) ...'
    Push-Location -LiteralPath $FrontendRoot
    try {
        npm run build
        if ($LASTEXITCODE -ne 0) { throw 'npm run build failed' }
    }
    finally {
        Pop-Location
    }
}
else {
    $distPath = Join-Path $FrontendRoot 'dist'
    if (-not (Test-Path -LiteralPath $distPath)) {
        Write-Fail 'dist/ is missing. Run without -SkipFrontendBuild or execute npm run build first.'
        exit 1
    }
    Write-Info 'Skipping frontend build (-SkipFrontendBuild); using existing dist/'
}

$listenApi = "0.0.0.0:$ApiPort"
$backendCmd = @"
Set-Location -LiteralPath '$BackendRoot'
`$env:PYTHONUNBUFFERED = '1'
Write-Host 'TacticalTickets API (Waitress) on http://$listenApi/' -ForegroundColor Green
& '$($WaitressServe.Replace("'", "''"))' --listen=$listenApi config.wsgi:application
"@

$frontendCmd = @"
Set-Location -LiteralPath '$FrontendRoot'
Write-Host 'TacticalTickets SPA (vite preview) on http://0.0.0.0:$WebPort/' -ForegroundColor Green
npm run preview -- --host 0.0.0.0 --port $WebPort
"@

Write-Info "Starting API (Waitress) in a new window: http://127.0.0.1:$ApiPort/"
Write-Info "Starting SPA (vite preview) in a new window: http://127.0.0.1:$WebPort/"
Write-Info 'Close those windows to stop each server.'

$shellExe = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) {
    (Get-Command pwsh.exe).Source
}
elseif (Get-Command powershell.exe -ErrorAction SilentlyContinue) {
    (Get-Command powershell.exe).Source
}
else {
    Write-Fail 'Could not find pwsh.exe or powershell.exe to launch server windows.'
    exit 1
}

Start-Process -FilePath $shellExe -WorkingDirectory $BackendRoot -ArgumentList @('-NoExit', '-NoProfile', '-Command', $backendCmd)
Start-Process -FilePath $shellExe -WorkingDirectory $FrontendRoot -ArgumentList @('-NoExit', '-NoProfile', '-Command', $frontendCmd)

Write-Info 'Done.'
