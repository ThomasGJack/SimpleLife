param([switch]$IncludeData, [switch]$Force)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$serverRoot = (Get-Item $here).Parent.Parent.Parent.Parent.Parent.FullName

$mysqldump = Get-ChildItem 'C:\Program Files\MariaDB *','C:\Program Files (x86)\MariaDB *' -Recurse -Filter 'mysqldump.exe' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
$mysql = Get-ChildItem 'C:\Program Files\MariaDB *','C:\Program Files (x86)\MariaDB *' -Recurse -Filter 'mysql.exe' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (-not $mysqldump -or -not $mysql) { throw 'mariadb tools not found' }

if (-not $Force) {
  Write-Host 'WARNING: this will overwrite simplelife_prod with dev structure.' -ForegroundColor Yellow
  if ($IncludeData) { Write-Host 'IncludeData=true -> dev data will REPLACE prod data!' -ForegroundColor Red }
  Write-Host 'Take a backup of prod first if needed.' -ForegroundColor Yellow
  $confirm = Read-Host "Type 'promote' to proceed"
  if ($confirm -ne 'promote') { Write-Host 'aborted.' -ForegroundColor Yellow; return }
}

$tmpFile = "$env:TEMP\sl-promote-dump.sql"
$dumpArgs = @('--user=simplelife','--password=simplelife_local','--host=localhost','--port=3306','--default-character-set=utf8mb4','--routines','--triggers','--events')
if (-not $IncludeData) { $dumpArgs += '--no-data' }
$dumpArgs += 'simplelife_dev'

Write-Host 'Dumping simplelife_dev...' -ForegroundColor Cyan
& $mysqldump @dumpArgs | Out-File -FilePath $tmpFile -Encoding utf8

Write-Host 'Loading into simplelife_prod...' -ForegroundColor Cyan
Get-Content $tmpFile -Raw | & $mysql --user=simplelife --password=simplelife_local --host=localhost --port=3306 --default-character-set=utf8mb4 simplelife_prod

Remove-Item $tmpFile -ErrorAction SilentlyContinue
Write-Host 'Done.' -ForegroundColor Green
