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
Serial device for USB flashing (e.g. /dev/ttyUSB0, COM3). Auto-detected
on Linux/macOS if present. Not needed for OTA updates.

.PARAMETER NoTty
Skip the -it flags (use when piping output to a file).

.EXAMPLE
PS> ./scripts/Invoke-EsphomeDocker.ps1
Compile and flash via 'esphome run esp-garage-door.yaml'.

.EXAMPLE
PS> ./scripts/Invoke-EsphomeDocker.ps1 -Command compile
Just validate and compile; no flash.

.EXAMPLE
PS> ./scripts/Invoke-EsphomeDocker.ps1 -Command logs
Stream live logs (uses OTA, no USB device needed).

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

# Build docker args
$dockerArgs = @('run', '--rm')

if ($Device) {
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

Write-Host " docker $($dockerArgs -join ' ')" -ForegroundColor DarkGray
Write-Host ''

& docker @dockerArgs
exit $LASTEXITCODE
