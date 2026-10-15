param(
  [ValidateSet('dev','prod')] [string]$Env = 'dev',
  [string]$Name = $null
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$serverRoot = (Get-Item $here).Parent.Parent.Parent.Parent.Parent.FullName
$backupDir = Join-Path $serverRoot 'backups'
[void][System.IO.Directory]::CreateDirectory($backupDir)

$mysqldump = Get-ChildItem 'C:\Program Files\MariaDB *','C:\Program Files (x86)\MariaDB *' -Recurse -Filter 'mysqldump.exe' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (-not $mysqldump) { throw "mysqldump.exe not found" }

$db = "simplelife_$Env"
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$tag = if ($Name) { "_$Name" } else { '' }
$outFile = Join-Path $backupDir "${db}_${ts}${tag}.sql"

Write-Host "Backing up $db -> $outFile" -ForegroundColor Cyan
& $mysqldump --user=simplelife --password=simplelife_local --host=localhost --port=3306 --single-transaction --routines --triggers --events --default-character-set=utf8mb4 $db | Out-File -FilePath $outFile -Encoding utf8

$size = (Get-Item $outFile).Length
Write-Host ("Done. Size: {0:N0} bytes" -f $size) -ForegroundColor Green

$cutoff = (Get-Date).AddDays(-7)
Get-ChildItem $backupDir -Filter "${db}_*.sql" | Where-Object { $_.LastWriteTime -lt $cutoff } | ForEach-Object {
  Write-Host "Pruning old backup: $($_.Name)" -ForegroundColor DarkGray
  Remove-Item $_.FullName -Force
}
