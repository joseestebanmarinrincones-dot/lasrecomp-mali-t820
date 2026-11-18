#Requires -Version 5.1
<#
    Aplica un perfil de LAS Recomp a un telefono Android por ADB.
    Uso:
      .\apply-config.ps1 -Profile beta6 -Package com.lasrecomp.android
      .\apply-config.ps1 -Profile beta6 -Package com.lasrecomp.android.nightly
      .\apply-config.ps1 -Profile fork  -Package com.lasrecomp.android
      .\apply-config.ps1 -Profile quality -Package com.lasrecomp.android.nightly
#>
[CmdletBinding()]
param(
    [ValidateSet('beta6', 'fork', 'quality')]
    [string]$Profile = 'beta6',

    [string]$Package = 'com.lasrecomp.android',

    [string]$Adb = ''
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

$fileName = switch ($Profile) {
    'fork'    { 'larecomp-fork-stability.ini' }
    'quality' { 'larecomp-beta6-quality.ini' }
    default   { 'larecomp-beta6-stability.ini' }
}

$source = Join-Path $root "profiles\$fileName"
if (-not (Test-Path -LiteralPath $source)) {
    throw "No encuentro el perfil: $source"
}

if (-not $Adb) {
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { $Adb = $cmd.Source }
    else { $Adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe' }
}
if (-not (Test-Path -LiteralPath $Adb)) {
    throw "No encuentro adb. Pasa la ruta con -Adb 'C:\ruta\adb.exe' o instala platform-tools."
}

$devices = & $Adb devices
$online = $devices | Where-Object { $_ -match '^\S+\s+device$' } | Select-Object -First 1
if (-not $online) {
    throw "No hay ningun telefono autorizado en 'adb devices'. Conecta el USB, acepta 'Permitir depuracion USB' y vuelve a intentar."
}

$dest = "/sdcard/Android/data/$Package/files/larecomp.ini"

$backupDir = Join-Path $root 'backups'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$backup = Join-Path $backupDir ("larecomp-{0}-{1}.ini" -f $Package, (Get-Date -Format 'yyyyMMdd-HHmmss'))
& $Adb pull $dest $backup 2>$null | Out-Null
if (Test-Path -LiteralPath $backup) {
    Write-Host "Backup: $backup"
} else {
    Write-Host "No habia larecomp.ini previo (o no se pudo leer); sigo."
}

& $Adb shell "am force-stop $Package" | Out-Null
& $Adb push $source $dest
if ($LASTEXITCODE -ne 0) {
    throw "adb push fallo. Verifica que la app este instalada y su carpeta Android/data/$Package/files exista."
}

$activity = (& $Adb shell "cmd package resolve-activity --brief $Package" 2>$null) |
    Where-Object { $_ -match '/' } |
    Select-Object -Last 1
if ($activity) {
    $activity = $activity.Trim()
    & $Adb shell "am start -n $activity" | Out-Null
}

Write-Host "Perfil '$Profile' aplicado a $Package."
Write-Host "Abri la app y comproba que en el log aparezca '[settings] ... resolution 50% (chosen)'."
