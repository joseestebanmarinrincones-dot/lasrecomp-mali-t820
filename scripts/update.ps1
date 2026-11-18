#Requires -Version 5.1
<#
    Descarga el ultimo release de perfiles, verifica SHA-256 y lo aplica por ADB.
    Uso:
      .\update.ps1 -Profile beta6 -Package com.lasrecomp.android
      .\update.ps1 -Profile beta6 -Package com.lasrecomp.android.nightly
      .\update.ps1 -Profile fork  -Package com.lasrecomp.android
#>
[CmdletBinding()]
param(
    [ValidateSet('beta6', 'fork', 'quality')]
    [string]$Profile = 'beta6',

    [string]$Package = 'com.lasrecomp.android',

    [string]$Repo = 'joseestebanmarinrincones-dot/lasrecomp-mali-t820',

    [string]$Adb = ''
)

$ErrorActionPreference = 'Stop'

$zipUrl = "https://github.com/$Repo/releases/latest/download/lasrecomp-mali-profiles.zip"
$shaUrl = "$zipUrl.sha256"
$tmpRoot = Join-Path $env:TEMP 'lasrecomp-mali-update'
$zipPath = Join-Path $tmpRoot 'lasrecomp-mali-profiles.zip'
$extractPath = Join-Path $tmpRoot 'files'

New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null
if (Test-Path -LiteralPath $extractPath) { Remove-Item -LiteralPath $extractPath -Recurse -Force }

Write-Host "Descargando $zipUrl"
Invoke-WebRequest -UseBasicParsing -Uri $zipUrl -OutFile $zipPath

try {
    $shaResponse = Invoke-WebRequest -UseBasicParsing -Uri $shaUrl
    $shaText = if ($shaResponse.Content -is [byte[]]) {
        [System.Text.Encoding]::UTF8.GetString($shaResponse.Content)
    } else {
        [string]$shaResponse.Content
    }
    $expected = ($shaText -split '\s+')[0].Trim().ToLowerInvariant()
    $actual = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($expected -and ($expected -ne $actual)) {
        throw "SHA-256 no coincide. Esperado $expected, obtenido $actual."
    }
    Write-Host "SHA-256 OK: $actual"
} catch {
    Write-Warning "No se pudo verificar el SHA-256: $($_.Exception.Message)"
}

Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force

$apply = Join-Path $extractPath 'scripts\apply-config.ps1'
if (-not (Test-Path -LiteralPath $apply)) {
    throw "El release no trae scripts\apply-config.ps1."
}

& $apply -Profile $Profile -Package $Package -Adb $Adb
