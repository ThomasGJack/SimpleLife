param([ValidateSet('dev','prod')] [string]$Env = 'dev')

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$serverRoot = (Get-Item $here).Parent.Parent.Parent.Parent.Parent.FullName
$credFile = Join-Path $serverRoot '.simplelife-credentials.txt'
if (-not (Test-Path $credFile)) { throw "credentials missing: $credFile" }

$mysql = Get-ChildItem 'C:\Program Files\MariaDB *','C:\Program Files (x86)\MariaDB *' -Recurse -Filter 'mysql.exe' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (-not $mysql) { throw "mysql.exe not found" }

$db = "simplelife_$Env"
Write-Host "Opening MariaDB shell on $db..." -ForegroundColor Cyan
& $mysql -u simplelife -psimplelife_local -h localhost -P 3306 $db
