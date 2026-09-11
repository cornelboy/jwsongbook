param(
  [switch]$NoOpen
)

$ErrorActionPreference = 'Stop'
$dashboardDirectory = Split-Path $PSScriptRoot -Parent
$dashboardUrl = 'http://127.0.0.1:4173'
$healthUrl = "$dashboardUrl/api/state"

function Test-Dashboard {
  try {
    $state = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 1
    return $null -ne $state.contentRoot
  } catch {
    return $false
  }
}

try {
  if (-not (Test-Dashboard)) {
    $node = Get-Command node.exe -ErrorAction SilentlyContinue
    if ($null -eq $node) {
      throw 'Node.js 20 or newer is required. Install Node.js, then try again.'
    }

    $lucideBundle = Join-Path $dashboardDirectory 'node_modules\lucide\dist\umd\lucide.min.js'
    if (-not (Test-Path -LiteralPath $lucideBundle)) {
      throw "Dashboard dependencies are missing. Run 'npm install' inside $dashboardDirectory first."
    }

    $logDirectory = Join-Path $env:LOCALAPPDATA 'JW Songs Content Manager'
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
    $stdoutLog = Join-Path $logDirectory 'server.log'
    $stderrLog = Join-Path $logDirectory 'server-error.log'

    Start-Process `
      -FilePath $node.Source `
      -ArgumentList @('src/server.mjs', '--port', '4173') `
      -WorkingDirectory $dashboardDirectory `
      -WindowStyle Hidden `
      -RedirectStandardOutput $stdoutLog `
      -RedirectStandardError $stderrLog | Out-Null

    $started = $false
    for ($attempt = 0; $attempt -lt 24; $attempt += 1) {
      Start-Sleep -Milliseconds 250
      if (Test-Dashboard) {
        $started = $true
        break
      }
    }

    if (-not $started) {
      $details = Get-Content -Raw $stderrLog -ErrorAction SilentlyContinue
      throw "The dashboard server did not start. $details"
    }
  }

  if (-not $NoOpen) {
    Start-Process $dashboardUrl
  }
  Write-Host "JW Songs Content Manager is running at $dashboardUrl"
} catch {
  Write-Error $_.Exception.Message
  exit 1
}
