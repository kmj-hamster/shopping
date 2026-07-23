[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "common.ps1")
$config = Get-GodotCodexConfig -ProjectRoot $projectRoot
$godot = Resolve-GodotExecutable -Config $config
Set-GodotCodexEnvironment -Config $config

$process = Start-Process -FilePath $godot -ArgumentList @("--editor", "--path", $projectRoot) -PassThru
Write-Host "Started Godot editor (PID $($process.Id))."
Write-Host "Godot AI should expose $($config.mcp.endpoint) after the editor finishes loading."
