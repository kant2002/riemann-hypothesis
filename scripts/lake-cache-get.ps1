#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($args.Count -ne 1 -or $args[0] -ne 'get') {
    [Console]::Error.WriteLine('Usage: lake exe cache get')
    exit 2
}

$RhCacheRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $RhCacheRoot

# scripts/ci-cache-get.py needs Python 3.11 for tomllib. Say so before downloading anything.
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    $python = Get-Command python3 -ErrorAction SilentlyContinue
}

$pythonOk = $false
if ($python) {
    & $python.Source -c 'import sys; sys.exit(sys.version_info < (3, 11))'
    $pythonOk = ($LASTEXITCODE -eq 0)
}

if (-not $pythonOk) {
    if ($python) {
        $version = (& $python.Source --version 2>&1) -join ' '
    } else {
        $version = 'none'
    }
    [Console]::Error.WriteLine("lake exe cache get needs Python 3.11 or newer as python3; found: $version")
    exit 1
}

# The per-process open-file limit tuning from the bash script is a Unix (ulimit) concern
# and has no equivalent on Windows PowerShell, so it is intentionally omitted here.

# Qualify Mathlib's executable because this package also supplies a cache target.
Write-Output 'Fetching Mathlib cache...'
if (-not $env:MATHLIB_CACHE_GET_URL) {
    $env:MATHLIB_CACHE_GET_URL = 'https://cache.mathlib.org/mathlib4'
}
lake exe mathlib/cache get
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# Cache URLs live in lakefile.toml; users need no separate configuration file.
# ci-cache-get.py registers the map, downloads and checks the artifacts (500 parallel transfers),
# unpacks them with one leantar process, then checks with `lake build --no-build`.
Write-Output 'Fetching build cache...'
$env:LAKE_CACHE_DIR = Join-Path $RhCacheRoot '.lake/cache'
& $python.Source scripts/ci-cache-get.py
$RhCiCacheStatus = $LASTEXITCODE
if ($RhCiCacheStatus -eq 3) {
    [Console]::Error.WriteLine('No validated cache matches these build inputs; use lake build.')
}
exit $RhCiCacheStatus
