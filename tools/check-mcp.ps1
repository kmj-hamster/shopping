[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$endpoint = "http://127.0.0.1:8000/mcp"

function Send-McpMessage {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Message,

        [string]$Session = ""
    )

    $headers = @{ Accept = "application/json, text/event-stream" }
    if ($Session) {
        $headers["Mcp-Session-Id"] = $Session
    }

    $response = Invoke-WebRequest `
        -Uri $endpoint `
        -Method Post `
        -Headers $headers `
        -ContentType "application/json" `
        -Body ($Message | ConvertTo-Json -Depth 20 -Compress) `
        -TimeoutSec 20 `
        -UseBasicParsing

    $dataLines = @($response.Content -split "`n" | Where-Object { $_ -like "data:*" })
    $json = if ($dataLines.Count) {
        $dataLines[-1].Substring(5).Trim() | ConvertFrom-Json -Depth 30
    }

    return [pscustomobject]@{
        Session = [string]($response.Headers["Mcp-Session-Id"] | Select-Object -First 1)
        Json = $json
    }
}

function Invoke-McpTool {
    param(
        [int]$RequestId,
        [string]$Name,
        [hashtable]$Arguments,
        [string]$Session
    )

    $reply = Send-McpMessage -Session $Session -Message @{
        jsonrpc = "2.0"
        id = $RequestId
        method = "tools/call"
        params = @{
            name = $Name
            arguments = $Arguments
        }
    }
    if ($reply.Json.result.isError) {
        throw "$Name returned an MCP error: $($reply.Json.result.content[0].text)"
    }
    return $reply.Json.result.structuredContent
}

$initialize = Send-McpMessage -Message @{
    jsonrpc = "2.0"
    id = 1
    method = "initialize"
    params = @{
        protocolVersion = "2025-06-18"
        capabilities = @{}
        clientInfo = @{ name = "shopping-mcp-check"; version = "1.0" }
    }
}
$session = $initialize.Session
if (-not $session) {
    throw "Godot AI did not return an MCP session id."
}

$null = Send-McpMessage -Session $session -Message @{
    jsonrpc = "2.0"
    method = "notifications/initialized"
}

$sessions = Invoke-McpTool -RequestId 2 -Name "session_manage" -Arguments @{
    op = "list"
    params = @{}
} -Session $session
if ($sessions.count -lt 1) {
    throw "Godot AI is running, but no Godot editor session is connected."
}

$state = Invoke-McpTool -RequestId 3 -Name "editor_state" -Arguments @{} -Session $session
Write-Host "MCP bridge connected: $($sessions.sessions[0].session_id)"
Write-Host "Godot: $($state.godot_version)"
Write-Host "Scene: $($state.current_scene)"
Write-Host "Readiness: $($state.readiness)"
