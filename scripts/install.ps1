# Instala el schema sdd-incremental, la config de ejemplo y los skills sdd-* en un proyecto
# que ya usa OpenSpec, y desactiva la telemetría de OpenSpec en la configuración global del
# usuario. Idempotente: no toca los skills openspec-* ni una config.yaml existente.
# Equivalente a install.sh para Windows PowerShell 5.1+ y PowerShell 7+.
#
# Uso: scripts\install.ps1 <ruta-proyecto> [-Tools claude,codex,github-copilot,opencode]
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Target,

    [string[]]$Tools = @('claude', 'codex', 'github-copilot')
)

$ErrorActionPreference = 'Stop'

$RepoDir = Split-Path -Parent $PSScriptRoot
$Schema = 'sdd-incremental'
$ToolDirs = @{
    'claude'         = '.claude/skills'
    'codex'          = '.agents/skills'
    'github-copilot' = '.github/skills'
    'opencode'       = '.opencode/skills'
}

$Target = (Resolve-Path -LiteralPath $Target).Path
# Admite tanto -Tools claude,codex como -Tools "claude,codex"
$Tools = @($Tools | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$OpenSpecDir = Join-Path $Target 'openspec'
if (-not (Test-Path -LiteralPath $OpenSpecDir -PathType Container)) {
    [Console]::Error.WriteLine("No existe $OpenSpecDir. Inicializa OpenSpec primero:")
    [Console]::Error.WriteLine("  cd $Target; npx @fission-ai/openspec@latest init --tools $($Tools -join ',')")
    exit 1
}

function Copy-Fresh([string]$Source, [string]$Destination) {
    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse
}

# 1. Schema
$SchemasDir = Join-Path $OpenSpecDir 'schemas'
New-Item -ItemType Directory -Force -Path $SchemasDir | Out-Null
Copy-Fresh (Join-Path $RepoDir "openspec/schemas/$Schema") (Join-Path $SchemasDir $Schema)
Write-Host "OK  Schema  openspec\schemas\$Schema"

# 2. Config: solo se crea si no existe o si es la generada por 'openspec init' sin personalizar
$Config = Join-Path $OpenSpecDir 'config.yaml'
$ExampleConfig = Join-Path $RepoDir 'openspec/config.example.yaml'
$Customized = $false
if (Test-Path -LiteralPath $Config) {
    $Customized = [bool](Get-Content -LiteralPath $Config | Where-Object {
            $_ -notmatch '^\s*(#|$)' -and $_ -notmatch '^schema: spec-driven\s*$'
        })
}
if ($Customized) {
    Write-Host "!   openspec\config.yaml ya está personalizada; no se modifica."
    Write-Host "    Pon 'schema: $Schema' y copia lo que necesites de:"
    Write-Host "    $ExampleConfig"
}
else {
    Copy-Item -LiteralPath $ExampleConfig -Destination $Config -Force
    Write-Host "OK  Config  openspec\config.yaml"
}

# 3. Skills
foreach ($Tool in $Tools) {
    if (-not $ToolDirs.ContainsKey($Tool)) {
        Write-Warning "Herramienta desconocida: $Tool (usa claude, codex, github-copilot u opencode)"
        continue
    }
    $SkillsDir = Join-Path $Target $ToolDirs[$Tool]
    New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null
    foreach ($Skill in Get-ChildItem -LiteralPath (Join-Path $RepoDir 'skills') -Directory) {
        Copy-Fresh $Skill.FullName (Join-Path $SkillsDir $Skill.Name)
    }
    Write-Host "OK  Skills  $($ToolDirs[$Tool])/sdd-*"
}

# 4. Telemetría de OpenSpec desactivada en la configuración global del usuario.
#    OPENSPEC_TELEMETRY=0 evita que este mismo comando envíe telemetría.
$PreviousTelemetry = $env:OPENSPEC_TELEMETRY
$env:OPENSPEC_TELEMETRY = '0'
try {
    if (Get-Command openspec -ErrorAction SilentlyContinue) {
        & openspec config set telemetry.enabled false | Out-Null
    }
    else {
        & npx -y @fission-ai/openspec@latest config set telemetry.enabled false | Out-Null
    }
    $TelemetryOk = ($LASTEXITCODE -eq 0)
}
catch {
    $TelemetryOk = $false
}
finally {
    $env:OPENSPEC_TELEMETRY = $PreviousTelemetry
}
if ($TelemetryOk) {
    Write-Host "OK  Telemetría de OpenSpec desactivada (config global: telemetry.enabled=false)"
}
else {
    Write-Warning ("No se pudo desactivar la telemetría. Ejecútalo a mano: " +
        "`$env:OPENSPEC_TELEMETRY='0'; npx @fission-ai/openspec@latest config set telemetry.enabled false")
}

Write-Host ""
Write-Host "Comprueba el schema con: npx @fission-ai/openspec@latest schema validate $Schema"
