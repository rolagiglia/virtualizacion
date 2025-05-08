#------------------------------------------------------------
# APL1. Ejercicio4
# Materia: Virtualizacion de hardware
# Ingeniería en Informática
# Universidad Nacional de La Matanza (UNLaM)
# Año: 2025
#
# Integrantes del grupo:
# - De Luca, Leonel Maximiliano DNI: 42.588.356
# - La Giglia, Rodrigo Ariel DNI: 33334248
# - Marco, Nicolás Agustín DNI: 40885841
# - Marrone, Micaela Abril DNI: 45683584
#-------------------------------------------------------------

param (
    [Parameter(HelpMessage="Ruta del directorio a monitorear")] 
    [string][Alias("d")]$directorio,

    [Parameter(HelpMessage="Ruta donde se guardarán los backups.")] 
    [string][Alias("s")]$salida,

    [Parameter(HelpMessage="Matar el demonio del directorio")] 
    [switch][Alias("k")]$kill,

    [Parameter(HelpMessage="Cantidad de elementos hasta hacer backup")] 
    [int][Alias("c")]$cantidad,

    [Parameter(HelpMessage="Iniciar en segundo plano (interno)")] 
    [switch]$bg,

    [Parameter(HelpMessage="Muestra esta ayuda.")] 
    [switch][Alias("h")]$help
)

if($help){
    Write-Host "Uso: .\Ejercicio.ps1 -directorio <ruta> [-salida <ruta>] [-kill] [-cantidad <n>] [-help]" -ForegroundColor Green
    Write-Host "-directorio: Ruta del directorio a monitorear." -ForegroundColor Green
    Write-Host "-salida: Ruta donde se guardarán los backups." -ForegroundColor Green
    Write-Host "-kill: Matar el demonio del directorio." -ForegroundColor Green
    Write-Host "-cantidad: Cantidad de elementos hasta hacer backup." -ForegroundColor Green
    Write-Host "-help: Muestra esta ayuda." -ForegroundColor Green
    exit
}

if (-not $directorio) {
    Write-Host "Error: El parametro -directorio es obligatorio." -ForegroundColor Red
    exit
}

if (-not $salida -and -not $kill) {
    Write-Host "Error: El parametro -salida es obligatorio." -ForegroundColor Red
    exit
}

function CrearBackup {
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $base = Split-Path $directorio -Leaf
    $zip = "$base`_$ts.zip"  
    $dest = Join-Path $salida $zip
    Compress-Archive -Path (Join-Path $directorio '*') -DestinationPath $dest -Force
    $global:contador = 0
}

function ProcesarArchivo($file) {
    Start-Sleep -Milliseconds 300
    try {
        if (-not (Test-Path $file -PathType Leaf)) { return }

        $ext = [IO.Path]::GetExtension($file).TrimStart('.')
        if ([string]::IsNullOrEmpty($ext)) { $ext = 'SinExtension' }

        $dest = Join-Path $directorio $ext.ToUpper()
        if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }

        Move-Item -Path $file -Destination $dest -Force
        
        $global:contador++
        if ($global:contador -ge $cantidad) { CrearBackup }
    }
    catch {
        Write-Warning "Error al mover archivo: $_"
    }
}

if (-not (Test-Path -Path $directorio -PathType Container)) {
    Write-Host "Error: directorio no existe: $directorio" -ForegroundColor Red
    exit 1
}

# Generar PID file único por hash del path
$hash = [System.BitConverter]::ToString((New-Object System.Security.Cryptography.SHA256Managed).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($directorio))) -replace '-', ''
$pidFile = Join-Path $env:TEMP "daemon_$hash.pid"

if($kill -and ($salida -or $cantidad)) {
    Write-Host "Error: no se puede usar -kill con -salida o -cantidad." -ForegroundColor Red
    exit 1
}

if ($kill) {
    if (Test-Path $pidFile) {
        $existingPID = Get-Content $pidFile -ErrorAction SilentlyContinue
        Stop-Process -Id $existingPID -Force -ErrorAction SilentlyContinue
        Remove-Item $pidFile -Force
        Write-Host "Demonio detenido para: $directorio" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "No hay demonio en ejecución para: $directorio" -ForegroundColor Yellow
        exit 1
    }
}

if (Test-Path $pidFile) {
    $existingPID = Get-Content $pidFile -ErrorAction SilentlyContinue
    Get-Process -Id $existingPID -ErrorAction SilentlyContinue 
    Write-Host "Error: ya existe demonio (PID $existingPID) para: $directorio" -ForegroundColor Red
    exit 1
}

if (-not $salida -or -not $cantidad) {
    Write-Host "Error: falta -salida o -cantidad." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path -Path $salida -PathType Container)) {
    Write-Host "Error: salida no existe: $salida" -ForegroundColor Red
    exit 1
}

if (-not $bg) {
    $argumentos = @('-File', "`"$PSCommandPath`"", '-d', "`"$directorio`"", '-s', "`"$salida`"", '-c', $cantidad, '-bg')
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argumentos -WindowStyle Hidden | Out-Null
    Write-Host "Demonio iniciado en segundo plano para: $directorio" -ForegroundColor Green
    exit 0
}

$PID | Out-File $pidFile

$global:contador = 0

Get-ChildItem -Path $directorio -File | ForEach-Object {
    ProcesarArchivo $_.FullName
}

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $directorio
$watcher.Filter = '*.*'
$watcher.IncludeSubdirectories = $false
$watcher.EnableRaisingEvents = $true

$action = {
    ProcesarArchivo $Event.SourceEventArgs.FullPath
}

Register-ObjectEvent -InputObject $watcher -EventName Created -SourceIdentifier 'OnNuevoArchivo' -Action $action

while ($true) { Start-Sleep -Seconds 5 }

