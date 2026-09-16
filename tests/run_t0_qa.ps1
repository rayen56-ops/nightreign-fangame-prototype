$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectRoot

$python = Get-Command python.exe -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py.exe -ErrorAction SilentlyContinue }
if (-not $python) { throw 'Python 3 not found; T0 static gate cannot run.' }
& $python.Source 'tools\validate_t0.py'
if ($LASTEXITCODE -ne 0) { throw 'T0 static QA failed.' }

$enginePath = Join-Path $projectRoot 'runtime\Godot.exe'
if (-not (Test-Path -LiteralPath $enginePath)) {
    $godot = Get-Command godot.exe -ErrorAction SilentlyContinue
    if (-not $godot) { $godot = Get-Command godot4.exe -ErrorAction SilentlyContinue }
    if (-not $godot) { throw 'Godot 4.6 not found. Install Godot or place Godot.exe in runtime\.' }
    $enginePath = $godot.Source
}

$import = Start-Process -FilePath $enginePath -ArgumentList '--headless --editor --import --path . --quit --log-file docs/t0-import.log' -WindowStyle Hidden -Wait -PassThru
if ($import.ExitCode -ne 0) { throw 'T0 asset import failed.' }
if (Test-Path -LiteralPath 'docs\T0_QA.json') { Remove-Item 'docs\T0_QA.json' }
$run = Start-Process -FilePath $enginePath -ArgumentList '--headless --path . res://tests/t0_core.tscn --log-file docs/t0-core.log --quit-after 1800' -WindowStyle Hidden -Wait -PassThru
if ($run.ExitCode -ne 0 -or -not (Test-Path -LiteralPath 'docs\T0_QA.json')) { throw 'T0 Godot QA failed.' }
$report = Get-Content 'docs\T0_QA.json' -Raw | ConvertFrom-Json
if ($report.failures.Count -gt 0) { throw ($report.failures -join '; ') }
$log = Get-Content 'docs\t0-core.log' -Raw
if ($log -match 'SCRIPT ERROR:') { throw 'T0 runtime script error.' }
Write-Host "T0 QA passed: $($report.checks) runtime checks + static gate."
