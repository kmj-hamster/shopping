[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "common.ps1")
$config = Get-GodotCodexConfig -ProjectRoot $projectRoot
$godot = Resolve-GodotExecutable -Config $config
Set-GodotCodexEnvironment -Config $config
$reportDir = Join-Path $projectRoot "test-reports"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

function Invoke-GodotStep {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string[]]$Arguments)

    $stdoutPath = Join-Path $reportDir "$Name.stdout.log"
    $stderrPath = Join-Path $reportDir "$Name.stderr.log"
    $process = Start-Process -FilePath $godot -ArgumentList $Arguments -Wait -PassThru `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath }
    if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath | Write-Error }
    if ($process.ExitCode -ne 0) { throw "$Name failed with exit code $($process.ExitCode)" }
}

$versionOut = Join-Path $reportDir "version.stdout.log"
$versionErr = Join-Path $reportDir "version.stderr.log"
$versionProcess = Start-Process -FilePath $godot -ArgumentList @("--version") -Wait -PassThru `
    -RedirectStandardOutput $versionOut -RedirectStandardError $versionErr
if ($versionProcess.ExitCode -ne 0) { throw "Unable to read Godot version." }
$actualVersion = (Get-Content -Raw -LiteralPath $versionOut).Trim()
$expectedVersion = [string]$config.godot.expected_version
if ($expectedVersion -and -not $actualVersion.StartsWith($expectedVersion)) {
    throw "Expected Godot $expectedVersion but found $actualVersion."
}
Write-Host "Godot $actualVersion"

$testsEnabled = [bool]$config.tests.enabled
$stepCount = if ($testsEnabled) { 2 } else { 1 }
Write-Host "[1/$stepCount] Importing resources and parsing project scripts..."
Invoke-GodotStep -Name "import" -Arguments @("--headless", "--path", $projectRoot, "--import")

if ($testsEnabled) {
    if ($config.tests.runner -ne "gut") { throw "Unsupported test runner: $($config.tests.runner)" }
    Write-Host "[2/$stepCount] Running GUT tests..."
    Invoke-GodotStep -Name "gut" -Arguments @(
        "--headless", "--path", $projectRoot,
        "--script", [string]$config.tests.script,
        "-gexit", "-gdisable_colors"
    )
}
Write-Host "All project checks passed."
