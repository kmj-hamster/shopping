[CmdletBinding()]
param(
    [string]$ScreenshotPath = "test-reports/runtime-mcp.png"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "common.ps1")
$config = Get-GodotCodexConfig -ProjectRoot $projectRoot
$endpoint = [string]$config.mcp.endpoint

function Send-McpMessage {
    param(
        [Parameter(Mandatory)] [hashtable]$Message,
        [string]$Session = ""
    )
    $headers = @{ Accept = "application/json, text/event-stream" }
    if ($Session) { $headers["Mcp-Session-Id"] = $Session }
    $response = Invoke-WebRequest `
        -Uri $endpoint `
        -Method Post `
        -Headers $headers `
        -ContentType "application/json" `
        -Body ($Message | ConvertTo-Json -Depth 20 -Compress) `
        -TimeoutSec 40 `
        -UseBasicParsing
    $dataLines = @($response.Content -split "`n" | Where-Object { $_ -like "data:*" })
    $json = if ($dataLines.Count) {
        $dataLines[-1].Substring(5).Trim() | ConvertFrom-Json -Depth 40
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
        params = @{ name = $Name; arguments = $Arguments }
    }
    if ($reply.Json.result.isError) {
        throw "$Name returned an MCP error: $($reply.Json.result.content[0].text)"
    }
    return $reply.Json.result
}

$initialize = Send-McpMessage -Message @{
    jsonrpc = "2.0"
    id = 1
    method = "initialize"
    params = @{
        protocolVersion = "2025-06-18"
        capabilities = @{}
        clientInfo = @{ name = "$($config.project_name)-runtime-check"; version = "1.0" }
    }
}
$session = $initialize.Session
if (-not $session) { throw "Godot AI did not return an MCP session id." }
$null = Send-McpMessage -Session $session -Message @{
    jsonrpc = "2.0"
    method = "notifications/initialized"
}

$screenshotAbsolute = if ([IO.Path]::IsPathRooted($ScreenshotPath)) {
    $ScreenshotPath
} else {
    Join-Path $projectRoot $ScreenshotPath
}
$screenshotDirectory = Split-Path -Parent $screenshotAbsolute
if (-not (Test-Path $screenshotDirectory)) {
    New-Item -ItemType Directory -Path $screenshotDirectory | Out-Null
}

try {
    $baseline = Invoke-McpTool -RequestId 2 -Name "logs_read" -Arguments @{
        source = "editor"
        count = 1
        include_details = $false
    } -Session $session
    $editorCursor = [int]$baseline.structuredContent.next_cursor
    $run = Invoke-McpTool -RequestId 3 -Name "project_run" -Arguments @{
        mode = "main"
        autosave = $true
    } -Session $session
    Write-Host "Runtime launch: $($run.structuredContent.message)"

    $shot = Invoke-McpTool -RequestId 4 -Name "editor_screenshot" -Arguments @{
        source = "game"
        max_resolution = 1280
    } -Session $session
    $imageBase64 = $null
    if ($shot.structuredContent.data.image_base64) {
        $imageBase64 = [string]$shot.structuredContent.data.image_base64
    } elseif ($shot.structuredContent.image_base64) {
        $imageBase64 = [string]$shot.structuredContent.image_base64
    } else {
        $imageBlock = @($shot.content | Where-Object { $_.type -eq "image" }) | Select-Object -First 1
        if ($imageBlock) { $imageBase64 = [string]$imageBlock.data }
    }
    if (-not $imageBase64) { throw "editor_screenshot returned no image payload." }
    [IO.File]::WriteAllBytes($screenshotAbsolute, [Convert]::FromBase64String($imageBase64))
    Write-Host "Runtime screenshot: $screenshotAbsolute"

    foreach ($source in @("editor", "game")) {
        $arguments = @{
            source = $source
            count = 80
            include_details = $true
        }
        if ($source -eq "editor") { $arguments.since_cursor = $editorCursor }
        $logs = Invoke-McpTool -RequestId (5 + [array]::IndexOf(@("editor", "game"), $source)) `
            -Name "logs_read" -Arguments @{
                source = $arguments.source
                count = $arguments.count
                include_details = $arguments.include_details
                since_cursor = $arguments.since_cursor
            } -Session $session
        $payload = $logs.structuredContent | ConvertTo-Json -Depth 12 -Compress
        Write-Host "$source logs: $payload"
    }
} finally {
    $null = Invoke-McpTool -RequestId 7 -Name "project_manage" -Arguments @{
        op = "stop"
        params = @{}
    } -Session $session
}
