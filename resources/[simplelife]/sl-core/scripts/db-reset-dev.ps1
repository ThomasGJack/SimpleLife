param([switch]$Force)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$serverRoot = (Get-Item $here).Parent.Parent.Parent.Parent.Parent.FullName
$credFile = Join-Path $serverRoot '.simplelife-credentials.txt'
if (-not (Test-Path $credFile)) { throw "credentials missing: $credFile" }

$rootPwd = (Select-String -Path $credFile -Pattern '^password = (.+)' | Select-Object -First 1).Matches.Groups[1].Value
$mysql = Get-ChildItem 'C:\Program Files\MariaDB *','C:\Program Files (x86)\MariaDB *' -Recurse -Filter 'mysql.exe' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (-not $mysql) { throw "mysql.exe not found" }

if (-not $Force) {
  Write-Host "WARNING: this will DROP simplelife_dev and re-create it empty." -ForegroundColor Red
  Write-Host "All dev data will be lost. simplelife_prod is untouched." -ForegroundColor Red
  $confirm = Read-Host "Type 'reset dev' to proceed"
  if ($confirm -ne 'reset dev') { Write-Host "aborted." -ForegroundColor Yellow; return }
}

$tmpCnf = "$env:TEMP\sl-reset.cnf"
Set-Content -Path $tmpCnf -Value "[client]`nuser=root`npassword=$rootPwd`nhost=localhost`nport=3306" -Encoding ASCII
try {
  Write-Host "Dropping simplelife_dev..." -ForegroundColor Cyan
  "DROP DATABASE IF EXISTS simplelife_dev; CREATE DATABASE simplelife_dev CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; GRANT ALL PRIVILEGES ON simplelife_dev.* TO 'simplelife'@'localhost'; FLUSH PRIVILEGES;" | & $mysql --defaults-extra-file=$tmpCnf
  Write-Host "Done. Restart the FiveM server to replay migrations." -ForegroundColor Green
} finally {
  Remove-Item $tmpCnf -ErrorAction SilentlyContinue
}
