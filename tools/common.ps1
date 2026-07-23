function Get-GodotCodexConfig {
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )

    $configPath = Join-Path $ProjectRoot "godot-codex.json"
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        throw "Workflow config not found: $configPath"
    }

    return Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
}

function Resolve-GodotExecutable {
    param(
        [Parameter(Mandatory)]
        [object]$Config
    )

    $candidate = if ($env:GODOT_BIN) {
        $env:GODOT_BIN
    } else {
        [string]$Config.godot.binary
    }

    if (-not $candidate) {
        throw "Set GODOT_BIN or godot.binary in godot-codex.json."
    }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "Godot executable not found: $candidate"
    }

    return $candidate
}

function Set-GodotCodexEnvironment {
    param(
        [Parameter(Mandatory)]
        [object]$Config
    )

    if ($Config.mcp.disable_telemetry) {
        $env:GODOT_AI_DISABLE_TELEMETRY = "true"
    }
}
