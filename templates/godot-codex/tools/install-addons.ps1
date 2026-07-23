[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "common.ps1")
$config = Get-GodotCodexConfig -ProjectRoot $projectRoot
$addonsDir = Join-Path $projectRoot "addons"
$godotAiTarget = Join-Path $addonsDir "godot_ai"
$gutTarget = Join-Path $addonsDir "gut"

if ((Test-Path -LiteralPath $godotAiTarget) -or (Test-Path -LiteralPath $gutTarget)) {
    throw "An addon target already exists. Refusing to merge over an installed version."
}

$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$work = Join-Path $tempRoot ("godot-codex-install-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null

try {
    $godotAiSource = Join-Path $work "godot-ai"
    $gutSource = Join-Path $work "gut"
    git clone --depth 1 --branch $config.addons.godot_ai.ref $config.addons.godot_ai.repository $godotAiSource
    if ($LASTEXITCODE -ne 0) { throw "Failed to clone Godot AI." }
    git clone --depth 1 --branch $config.addons.gut.ref $config.addons.gut.repository $gutSource
    if ($LASTEXITCODE -ne 0) { throw "Failed to clone GUT." }

    $godotAiCommit = git -C $godotAiSource rev-parse HEAD
    $gutCommit = git -C $gutSource rev-parse HEAD
    if ($godotAiCommit.Trim() -ne $config.addons.godot_ai.commit) { throw "Godot AI pin mismatch." }
    if ($gutCommit.Trim() -ne $config.addons.gut.commit) { throw "GUT pin mismatch." }

    New-Item -ItemType Directory -Force -Path $addonsDir | Out-Null
    Copy-Item -LiteralPath (Join-Path $godotAiSource "plugin\addons\godot_ai") -Destination $addonsDir -Recurse
    Copy-Item -LiteralPath (Join-Path $gutSource "addons\gut") -Destination $addonsDir -Recurse
    Write-Host "Installed Godot AI $($config.addons.godot_ai.version) and GUT $($config.addons.gut.version)."
}
finally {
    $resolvedWork = [System.IO.Path]::GetFullPath($work)
    if ($resolvedWork.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and $resolvedWork -ne $tempRoot) {
        Remove-Item -LiteralPath $resolvedWork -Recurse -Force
    }
}
