# Configure Claude Desktop for centralized Redis Memory Server (Windows)

Write-Host "🤖 Configuring Claude Desktop for Redis Memory Central" -ForegroundColor Blue
Write-Host "====================================================" -ForegroundColor Blue

$RedisMemoryIP = if ($env:REDIS_MEMORY_IP) { $env:REDIS_MEMORY_IP } else { "10.10.20.85" }
$ConfigDir = "$env:APPDATA\Claude"
$ConfigFile = "$ConfigDir\claude_desktop_config.json"

Write-Host "📁 Config location: $ConfigFile" -ForegroundColor Green
Write-Host "🌐 Redis Memory Server: $RedisMemoryIP" -ForegroundColor Green

# Backup existing config
if (Test-Path $ConfigFile) {
    $BackupFile = "$ConfigFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $ConfigFile $BackupFile
    Write-Host "✅ Backed up existing configuration to $BackupFile" -ForegroundColor Green
}

# Create config directory if it doesn't exist
if (!(Test-Path $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
}

# Read existing config or create new
if (Test-Path $ConfigFile) {
    $Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
} else {
    $Config = @{}
}

# Update config
$Config."redis-memory-server" = @{
    command = "docker"
    args = @(
        "run", "--rm", "-i",
        "--network", "host",
        "-e", "REDIS_URL=redis://$RedisMemoryIP:16379",
        "-e", "API_URL=http://$RedisMemoryIP:8000",
        "-e", "DISABLE_AUTH=true",
        "ghcr.io/redis-developer/agent-memory-mcp:latest"
    )
}

# Write updated config
$Config | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile

Write-Host "✅ Configuration updated successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Added Redis Memory Server MCP configuration:" -ForegroundColor Yellow
$Config."redis-memory-server" | ConvertTo-Json -Depth 10
Write-Host ""
Write-Host "⚠️  Please restart Claude Desktop for changes to take effect" -ForegroundColor Yellow
Write-Host ""
Write-Host "🧪 To test the connection, run:" -ForegroundColor Cyan
Write-Host "   python $PSScriptRoot\test-connection.py" -ForegroundColor Cyan