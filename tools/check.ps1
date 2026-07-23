[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$defaultGodot = "D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$godot = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { $defaultGodot }

if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) {
    throw "Godot executable not found: $godot"
}

$env:GODOT_AI_DISABLE_TELEMETRY = "true"
$reportDir = Join-Path $projectRoot "test-reports"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

function Invoke-GodotStep {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $stdoutPath = Join-Path $reportDir "$Name.stdout.log"
    $stderrPath = Join-Path $reportDir "$Name.stderr.log"
    $process = Start-Process -FilePath $godot `
        -ArgumentList $Arguments `
        -Wait `
        -PassThru `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath

    if (Test-Path -LiteralPath $stdoutPath) {
        Get-Content -LiteralPath $stdoutPath
    }
    if (Test-Path -LiteralPath $stderrPath) {
        Get-Content -LiteralPath $stderrPath | Write-Error
    }
    if ($process.ExitCode -ne 0) {
        throw "$Name failed with exit code $($process.ExitCode)"
    }
}

Write-Host "[1/2] Importing resources and parsing project scripts..."
Invoke-GodotStep -Name "import" -Arguments @("--headless", "--path", $projectRoot, "--import")

Write-Host "[2/2] Running GUT tests..."
Invoke-GodotStep -Name "gut" -Arguments @(
    "--headless",
    "--path", $projectRoot,
    "--script", "res://addons/gut/gut_cmdln.gd",
    "-gexit",
    "-gdisable_colors"
)

Write-Host "All project checks passed."
