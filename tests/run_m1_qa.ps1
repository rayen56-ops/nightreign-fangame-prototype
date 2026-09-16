$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectRoot
$enginePath = Join-Path $projectRoot 'runtime\Godot.exe'
if (-not (Test-Path -LiteralPath $enginePath)) {
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if (-not $cmd) { $cmd = Get-Command godot4 -ErrorAction SilentlyContinue }
    if (-not $cmd) { throw 'Godot 4.6 was not found. Install Godot 4.6 or place the executable at runtime\Godot.exe.' }
    $enginePath = $cmd.Source
}
$importProcess = Start-Process -FilePath $enginePath -ArgumentList '--headless --editor --import --path . --quit --log-file docs/m1-import.log' -WindowStyle Hidden -Wait -PassThru
if ($importProcess.ExitCode -ne 0) { throw 'Asset import failed.' }
$suites = @(
    @{ Scene='expedition'; Report='docs/M1_QA.json' },
    @{ Scene='phase01'; Report='docs/qa-results.json' },
    @{ Scene='expedition_preview'; Report='docs/M1_UI_QA.json' }
)
foreach ($suite in $suites) {
    if (Test-Path -LiteralPath $suite.Report) { Remove-Item -LiteralPath $suite.Report }
    $sceneName = $suite.Scene
    $run = Start-Process -FilePath $enginePath -ArgumentList "--headless --path . res://tests/$sceneName.tscn --log-file docs/m1-$sceneName.log --quit-after 1800" -WindowStyle Hidden -Wait -PassThru
    if ($run.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $suite.Report)) { throw "QA failed: $sceneName" }
    $report = Get-Content -LiteralPath $suite.Report -Raw | ConvertFrom-Json
    if ($report.failures.Count -gt 0) { throw ($report.failures -join '; ') }
    $log = Get-Content -LiteralPath "docs/m1-$sceneName.log" -Raw
    if ($log -match 'SCRIPT ERROR:') { throw "Runtime script error: $sceneName" }
    Write-Host "$sceneName : $($report.checks) checks passed"
}
Write-Host 'M1 QA passed. Shutdown resource warnings are tracked in docs/M1_REPORT.md.'
