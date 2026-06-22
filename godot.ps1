$ErrorActionPreference = "Stop"

$godot = Join-Path $PSScriptRoot ".tools\godot\Godot_v4.7-stable_win64_console.exe"

if (-not (Test-Path $godot)) {
    throw "Godot CLI was not found at $godot"
}

& $godot @args
exit $LASTEXITCODE
