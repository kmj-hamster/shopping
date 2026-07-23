[CmdletBinding()]
param(
    [switch]$ImportOnly,
    [switch]$SkipImport,
    [string[]]$TestPath
)

$ErrorActionPreference = "Stop"
if ($ImportOnly -and $SkipImport) {
    throw "ImportOnly and SkipImport cannot be used together."
}
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "common.ps1")
$config = Get-GodotCodexConfig -ProjectRoot $projectRoot
$godot = Resolve-GodotExecutable -Config $config
Set-GodotCodexEnvironment -Config $config
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

$versionOut = Join-Path $reportDir "version.stdout.log"
$versionErr = Join-Path $reportDir "version.stderr.log"
$versionProcess = Start-Process -FilePath $godot `
    -ArgumentList @("--version") `
    -Wait `
    -PassThru `
    -RedirectStandardOutput $versionOut `
    -RedirectStandardError $versionErr
if ($versionProcess.ExitCode -ne 0) {
    throw "Unable to read Godot version (exit $($versionProcess.ExitCode))."
}
$actualVersion = (Get-Content -Raw -LiteralPath $versionOut).Trim()
$expectedVersion = [string]$config.godot.expected_version
if ($expectedVersion -and -not $actualVersion.StartsWith($expectedVersion)) {
    throw "Expected Godot $expectedVersion but found $actualVersion."
}
Write-Host "Godot $actualVersion"

$testsEnabled = [bool]$config.tests.enabled
$shouldImport = -not $SkipImport
$shouldRunTests = $testsEnabled -and -not $ImportOnly
if (-not $shouldImport -and -not $shouldRunTests) {
    throw "No checks selected. Remove SkipImport or enable tests."
}

$stepCount = [int]$shouldImport + [int]$shouldRunTests
$stepNumber = 1
if ($shouldImport) {
    Write-Host "[$stepNumber/$stepCount] Importing resources and parsing project scripts..."
    Invoke-GodotStep -Name "import" -Arguments @("--headless", "--path", $projectRoot, "--import")
    $stepNumber += 1
}

if ($shouldRunTests) {
    if ($config.tests.runner -ne "gut") {
        throw "Unsupported test runner: $($config.tests.runner)"
    }
    $gutArguments = @(
        "--headless",
        "--path", $projectRoot,
        "--script", [string]$config.tests.script,
        "-gexit",
        "-gdisable_colors"
    )

    $stepName = "gut"
    if ($TestPath.Count -gt 0) {
        $projectPrefix = [IO.Path]::GetFullPath($projectRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
        $testUris = foreach ($path in $TestPath) {
            if ($path.StartsWith("res://")) {
                $path
                continue
            }
            $resolved = (Resolve-Path -LiteralPath (Join-Path $projectRoot $path)).Path
            if (-not $resolved.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                throw "TestPath must be inside the project: $path"
            }
            "res://" + $resolved.Substring($projectPrefix.Length).Replace('\', '/')
        }
        $gutArguments += "-gdir="
        $gutArguments += "-gtest=$($testUris -join ',')"
        $stepName = "gut-targeted"
        Write-Host "[$stepNumber/$stepCount] Running targeted GUT tests: $($testUris -join ', ')"
    } else {
        Write-Host "[$stepNumber/$stepCount] Running all GUT tests..."
    }
    Invoke-GodotStep -Name $stepName -Arguments $gutArguments
}

Write-Host "All requested project checks passed."
