param(
  [Parameter(Mandatory=$true)] [string]$File,
  [ValidateSet('dev','prod')] [string]$Env = 'dev',
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$serverRoot = (Get-Item $here).Parent.Parent.Parent.Parent.Parent.FullName

if (-not (Test-Path $File)) {
  $candidate = Join-Path $serverRoot 'backups' $File
  if (Test-Path $candidate) { $File = $candidate } else { throw "backup file not found: $File" }
}

$mysql = Get-ChildItem 'C:\Program Files\MariaDB *','C:\Program Files (x86)\MariaDB *' -Recurse -Filter 'mysql.exe' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (-not $mysql) { throw "mysql.exe not found" }

$db = "simplelife_$Env"

if (-not $Force) {
  Write-Host "WARNING: this will overwrite $db with the content of $File" -ForegroundColor Yellow
  Write-Host "Stop the FiveM server first or players may be kicked." -ForegroundColor Yellow
  $confirm = Read-Host "Type 'yes' to proceed"
  if ($confirm -ne 'yes') { Write-Host "aborted." -ForegroundColor Red; return }
}

Write-Host "Restoring $File -> $db..." -ForegroundColor Cyan
Get-Content $File -Raw | & $mysql --user=simplelife --password=simplelife_local --host=localhost --port=3306 --default-character-set=utf8mb4 $db
Write-Host "Done." -ForegroundColor Green
