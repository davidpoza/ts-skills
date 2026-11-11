# Instala el schema sdd-incremental, la config de ejemplo y los skills sdd-* (también como comandos) en un proyecto
# que ya usa OpenSpec, y desactiva la telemetría de OpenSpec en la configuración global del
# usuario. Idempotente: no toca los skills openspec-* ni una config.yaml existente.
# Equivalente a install.sh para Windows PowerShell 5.1+ y PowerShell 7+.
#
# Uso desde un clon:  scripts\install.ps1 <ruta-proyecto> [-Tools claude,codex,github-copilot,opencode,roocode]
# Uso sin clonar:     & ([scriptblock]::Create((Invoke-RestMethod https://raw.githubusercontent.com/davidpoza/ts-skills/main/scripts/install.ps1).TrimStart([char]0xFEFF))) <ruta-proyecto> -Tools opencode
#                     (TrimStart quita el BOM UTF-8 del fichero, que impediría crear el scriptblock)
# Sin clon, descarga el repo de GitHub (rama o tag en $env:TS_SKILLS_REF, por defecto main).
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Target,

    [string[]]$Tools = @('claude', 'codex', 'github-copilot')
)

$ErrorActionPreference = 'Stop'

$Schema = 'sdd-incremental'
$RepoRef = if ($env:TS_SKILLS_REF) { $env:TS_SKILLS_REF } else { 'main' }
$ToolDirs = @{
    'claude'         = '.claude/skills'
    'codex'          = '.agents/skills'
    'github-copilot' = '.github/skills'
    'opencode'       = '.opencode/skills'
    'roocode'        = '.roo/skills'
}

$Target = (Resolve-Path -LiteralPath $Target).Path
# Admite tanto -Tools claude,codex como -Tools "claude,codex"
$Tools = @($Tools | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$OpenSpecDir = Join-Path $Target 'openspec'
if (-not (Test-Path -LiteralPath $OpenSpecDir -PathType Container)) {
    [Console]::Error.WriteLine("No existe $OpenSpecDir. Inicializa OpenSpec primero:")
    [Console]::Error.WriteLine("  cd $Target; openspec init --tools $($Tools -join ',')")
    exit 1
}

# Origen de los ficheros: el clon donde está este script o, si se ejecuta sin clon
# (por ejemplo, desde Invoke-RestMethod), una descarga temporal del repo.
$TempDir = $null
if ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) "openspec/schemas/$Schema"))) {
    $RepoDir = Split-Path -Parent $PSScriptRoot
}
else {
    $TempDir = Join-Path ([IO.Path]::GetTempPath()) ("ts-skills-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $TempDir | Out-Null
    $Archive = "https://github.com/davidpoza/ts-skills/archive/$RepoRef.zip"
    Write-Host "Descargando $Archive"
    # Windows PowerShell 5.1 puede no tener TLS 1.2 activado por defecto
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $Zip = Join-Path $TempDir 'repo.zip'
    Invoke-WebRequest -Uri $Archive -OutFile $Zip -UseBasicParsing
    Expand-Archive -LiteralPath $Zip -DestinationPath $TempDir
    $RepoDir = (Get-ChildItem -LiteralPath $TempDir -Directory | Select-Object -First 1).FullName
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
    Write-Host "    https://github.com/davidpoza/ts-skills/blob/$RepoRef/openspec/config.example.yaml"
}
else {
    Copy-Item -LiteralPath $ExampleConfig -Destination $Config -Force
    Write-Host "OK  Config  openspec\config.yaml"
}

# 3. Skills y comandos
#    Cada skill se instala también como comando con el mismo formato que usa 'openspec init'
#    para /opsx:*. Claude y Codex no lo necesitan: Claude invoca los skills como /sdd-pair
#    (un comando con el mismo nombre quedaría oculto por el skill) y Codex no tiene comandos
#    por proyecto (los skills se invocan con $sdd-pair).
$CommandDirs = @{
    'github-copilot' = @('.github/prompts', '.prompt.md')
    'opencode'       = @('.opencode/commands', '.md')
    'roocode'        = @('.roo/commands', '.md')
}
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

function New-SkillCommand([string]$Tool, [string]$Name, [string]$SkillFile, [string]$Destination) {
    $Lines = @(Get-Content -LiteralPath $SkillFile -Encoding UTF8)
    $End = -1
    if ($Lines.Count -gt 0 -and $Lines[0] -match '^---\s*$') {
        for ($i = 1; $i -lt $Lines.Count; $i++) {
            if ($Lines[$i] -match '^---\s*$') { $End = $i; break }
        }
    }
    $Description = ''
    if ($End -gt 0) {
        $Description = @($Lines[1..($End - 1)] | Where-Object { $_ -match '^description:' })[0]
    }
    $Body = if ($End -ge 0) { $Lines[($End + 1)..($Lines.Count - 1)] } else { $Lines }

    $Out = New-Object System.Collections.Generic.List[string]
    if ($Tool -eq 'roocode') {
        $Out.Add("# $Name"); $Out.Add(''); $Out.Add(($Description -replace '^description:\s*', ''))
    }
    else {
        $Out.Add('---'); $Out.Add($Description); $Out.Add('---')
    }
    foreach ($Line in $Body) { $Out.Add($Line) }
    if ($Tool -eq 'opencode') { $Out.Add(''); $Out.Add('**Provided arguments**: $ARGUMENTS') }
    [IO.File]::WriteAllText($Destination, (($Out -join "`n") + "`n"), $Utf8NoBom)
}

foreach ($Tool in $Tools) {
    if (-not $ToolDirs.ContainsKey($Tool)) {
        Write-Warning "Herramienta desconocida: $Tool (usa claude, codex, github-copilot, opencode o roocode)"
        continue
    }
    $SkillsDir = Join-Path $Target $ToolDirs[$Tool]
    New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null
    $CommandDir = $null
    if ($CommandDirs.ContainsKey($Tool)) {
        $CommandDir = Join-Path $Target $CommandDirs[$Tool][0]
        $CommandExt = $CommandDirs[$Tool][1]
        New-Item -ItemType Directory -Force -Path $CommandDir | Out-Null
    }
    foreach ($Skill in Get-ChildItem -LiteralPath (Join-Path $RepoDir 'skills') -Directory) {
        Copy-Fresh $Skill.FullName (Join-Path $SkillsDir $Skill.Name)
        if ($CommandDir) {
            New-SkillCommand $Tool $Skill.Name (Join-Path $Skill.FullName 'SKILL.md') (Join-Path $CommandDir "$($Skill.Name)$CommandExt")
        }
    }
    Write-Host "OK  Skills  $($ToolDirs[$Tool])/sdd-*"
    if ($CommandDir) { Write-Host "OK  Comandos $($CommandDirs[$Tool][0])/sdd-*$CommandExt" }
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

if ($TempDir) {
    Remove-Item -LiteralPath $TempDir -Recurse -Force
}

Write-Host ""
Write-Host "Comprueba el schema con: openspec schema validate $Schema"
