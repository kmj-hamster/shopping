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
$process = Start-Process -FilePath $godot -ArgumentList @("--editor", "--path", $projectRoot) -PassThru
Write-Host "Started Godot editor (PID $($process.Id))."
Write-Host "Godot AI should expose http://127.0.0.1:8000/mcp after the editor finishes loading."
