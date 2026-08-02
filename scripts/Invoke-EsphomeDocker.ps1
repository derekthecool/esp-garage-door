#!/usr/bin/env pwsh
<#
.SYNOPSIS
Run esphome via the official esphome/esphome docker image.

.DESCRIPTION
Avoids native esphome / PlatformIO / xtensa-toolchain issues (e.g. the
GCC 14.2.0 internal-compiler-error on the combined arduino+espidf
framework) by running inside the official esphome/esphome container.
Mounts the current directory at /config so the YAML, secrets.yaml, and
.esphome/ build cache are shared with the host.

.PARAMETER Command
esphome subcommand: run, compile, upload, logs, clean, or config.
Defaults to 'run' (compile + flash, prompts for USB or OTA).

.PARAMETER ConfigFile
esphome YAML file (default: esp-garage-door.yaml).

.PARAMETER Device
Upload target. Accepts:
  - Serial port path (e.g. /dev/ttyUSB0, /dev/ttyACM0, COM3)
    -> also passed to docker as --device for container access
  - IP address (e.g. 192.168.1.74) for OTA
    -> no docker device passthrough needed
  - Hostname (e.g. esp-garage-door.local) — requires --network host
    for mDNS to work inside the container, which this script does
    not set; use the IP instead.

If omitted on Linux/macOS, auto-detects /dev/ttyUSB0 and /dev/ttyACM0.

.PARAMETER NoTty
Skip the -it flags (use when piping output to a file).

.EXAMPLE
PS> ./scripts/Invoke-EsphomeDocker.ps1
Compile and flash; esphome prompts for upload method.

.EXAMPLE
PS> ./scripts/Invoke-EsphomeDocker.ps1 -Command compile
Just validate and compile; no flash.

.EXAMPLE
PS> ./scripts/Invoke-EsphomeDocker.ps1 -Device 192.168.1.74
OTA flash straight to the device at the given IP — no USB needed, no
interactive picker. Bypasses mDNS so it works with default docker
bridge networking.

.EXAMPLE
PS> ./scripts/Invoke-EsphomeDocker.ps1 -Command logs -Device 192.168.1.74
Stream live logs over OTA from the specified device.

.EXAMPLE
PS> ./scripts/Invoke-EsphomeDocker.ps1 -Device /dev/ttyACM0
Force a specific USB serial port instead of auto-detection.

.NOTES
Requires docker installed. On Linux the user must be in the docker
group (or run with sudo). On Windows use Docker Desktop.
#>
[CmdletBinding()]
param(
    [ValidateSet('run', 'compile', 'upload', 'logs', 'clean', 'config')]
    [string]$Command = 'run',

    [string]$ConfigFile = 'esp-garage-door.yaml',

    [string]$Device,

    [switch]$NoTty
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error 'docker not found in PATH. Install docker and ensure it is running.'
    exit 1
}

if (-not (Test-Path $ConfigFile)) {
    Write-Error "Config file not found: $ConfigFile (PWD: $PWD)"
    exit 1
}

$projectPath = (Resolve-Path .).Path

# Auto-detect serial device on Linux/macOS if not specified and present
if (-not $Device -and -not $IsWindows) {
    foreach ($candidate in @('/dev/ttyUSB0', '/dev/ttyACM0')) {
        if (Test-Path $candidate) {
            $Device = $candidate
            break
        }
    }
}

# Serial ports need docker --device for container access; IPs/hostnames don't
$isSerial = $Device -and ($Device -match '^/' -or $Device -match '^COM\d+')

# Build docker args
$dockerArgs = @('run', '--rm')

if ($isSerial) {
    $dockerArgs += @('--device', $Device)
}

# Interactive TTY unless output is redirected or explicitly disabled
if (-not $NoTty -and -not [Console]::IsOutputRedirected) {
    $dockerArgs += '-it'
}

$dockerArgs += @(
    '-v', "${projectPath}:/config",
    'esphome/esphome',
    $Command,
    $ConfigFile
)

# Pass --device to esphome for run/upload/logs — works for serial OR IP/hostname
if ($Device -and $Command -in @('run', 'upload', 'logs')) {
    $dockerArgs += @('--device', $Device)
}

Write-Host " docker $($dockerArgs -join ' ')" -ForegroundColor DarkGray
Write-Host ''

& docker @dockerArgs
exit $LASTEXITCODE
