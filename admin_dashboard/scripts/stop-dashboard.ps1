$ErrorActionPreference = 'Stop'

try {
  $listener = Get-NetTCPConnection `
    -LocalAddress '127.0.0.1' `
    -LocalPort 4173 `
    -State Listen `
    -ErrorAction SilentlyContinue |
    Select-Object -First 1

  if ($null -eq $listener) {
    Write-Host 'The dashboard server is not running.'
    exit 0
  }

  $process = Get-CimInstance Win32_Process `
    -Filter "ProcessId=$($listener.OwningProcess)"
  if ($process.CommandLine -notmatch 'src[\\/]server\.mjs') {
    throw "Port 4173 belongs to another program (PID $($listener.OwningProcess))."
  }

  Stop-Process -Id $listener.OwningProcess
  Write-Host 'JW Songs Content Manager stopped.'
} catch {
  Write-Error $_.Exception.Message
  exit 1
}
