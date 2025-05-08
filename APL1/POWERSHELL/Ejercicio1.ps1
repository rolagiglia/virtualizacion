#------------------------------------------------------------
# APL1. Ejercicio1
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
    [Parameter(HelpMessage="Ruta del directorio donde se buscarán los CSV.")]
    [string][Alias("d")]$directorio,
    
    [Parameter(HelpMessage="Ruta del archivo de salida JSON.")]
    [string][Alias("a")]$archivo,
    
    [Parameter(HelpMessage="Muestra el resultado en pantalla.")]
    [switch][Alias("p")]$pantalla,
    
    [Parameter(HelpMessage="Muestra esta ayuda.")]
    [switch][Alias("h")]$help
)
# Mostrar ayuda si se solicita
if ($help) {
    Write-Host "Uso: .\Ejercicio.ps1 -directorio <ruta> [-archivo <archivo salida>] [-pantalla] [-help]" -ForegroundColor Green
    Write-Host "-directorio: Ruta del directorio donde se buscarán los CSV." -ForegroundColor Green
    Write-Host "-archivo: Archivo JSON donde se guardará el resultado (opcional)." -ForegroundColor Green
    Write-Host "-pantalla: Muestra el resultado en pantalla (opcional)." -ForegroundColor Green
    Write-Host "-help: Muestra esta ayuda." -ForegroundColor Green
    exit
}

# Ahora validacion manual ingreso directorio.
if (-not $directorio) {
    Write-Host "Error: El parámetro -directorio es obligatorio." -ForegroundColor Red
    exit
}

function ConvertirTemperatura {
    param ($valorCrudo)

    $limpio = $valorCrudo.Trim() -replace '[^\d\-,\.]', ''

    if ($limpio -match ',' -and -not ($limpio -match '\.')) {
        $limpio = $limpio -replace ',', '.'
    }
    elseif ($limpio -match ',' -and $limpio -match '\.') {
        $limpio = $limpio -replace ',', ''
    }

    try {
        return [double]$limpio
    } catch {
        return $null
    }
}
if($pantalla -and $archivo){
    Write-Host "Debe seleccionar pantalla o archivo, no se pueden los dos a la vez" -ForegroundColor Red
    exit
}
if(-not $pantalla -and -not $archivo){
    Write-Host "Debe seleccionar pantalla o archivo, al menos uno es requerido" -ForegroundColor Red
    exit
}
# Verificar si el directorio existe
if (-not (Test-Path -Path $directorio -PathType Container)) {
    Write-Host "El directorio especificado no existe: $directorio" -ForegroundColor Red
    exit
}
# Acumulador de temperaturas
$temperaturasPorFechaUbicacion = @{}

# Procesar todos los archivos CSV
$archivos = Get-ChildItem -Path $directorio -Filter "*.csv" -File
Write-Host "Se encontraron $($archivos.Count) archivos CSV." -ForegroundColor Yellow

$archivos | ForEach-Object {
    $csvFile = $_.FullName
    Write-Host "Procesando archivo: $($_.Name)" -ForegroundColor Cyan

    try {
        $csvContent = Import-Csv -Path $csvFile  -Header @("id_dispositivo", "Fecha", "Hora", "Ubicacion", "Temperatura") -Delimiter ","

        $csvContent | ForEach-Object {
            $fecha = $_.Fecha
            $ubicacion = $_.Ubicacion
            $temperatura = ConvertirTemperatura $_.Temperatura

            if (-not $temperatura) {
                Write-Warning "Valor inválido en $ubicacion ($fecha): $($_.Temperatura)"
                return
            }

            if (-not $temperaturasPorFechaUbicacion.ContainsKey($fecha)) {
                $temperaturasPorFechaUbicacion[$fecha] = @{}
            }
            if (-not $temperaturasPorFechaUbicacion[$fecha].ContainsKey($ubicacion)) {
                $temperaturasPorFechaUbicacion[$fecha][$ubicacion] = @()
            }

            $temperaturasPorFechaUbicacion[$fecha][$ubicacion] += $temperatura
        }
    }
    catch {
        Write-Host "Error procesando archivo $($_.Name): $_" -ForegroundColor Red
    }
}

# Calcular estadísticas finales
$resultados = @{}

foreach ($fecha in $temperaturasPorFechaUbicacion.Keys) {
    $resultados[$fecha] = @{}
    foreach ($ubicacion in $temperaturasPorFechaUbicacion[$fecha].Keys) {
        $temps = $temperaturasPorFechaUbicacion[$fecha][$ubicacion]
        $stats = $temps | Measure-Object -Minimum -Maximum -Average

        $resultados[$fecha][$ubicacion] = @{
            Min = [math]::Round($stats.Minimum, 2)
            Max = [math]::Round($stats.Maximum, 2)
            Promedio = [math]::Round($stats.Average, 2)
        }
    }
}

# Crear formato final de salida
$jsonOutput = @{
    fechas = $resultados
} | ConvertTo-Json -Depth 5

# Mostrar por pantalla si está activado
if ($pantalla) {
    $jsonOutput | Out-Host
}

# Guardar en archivo JSON si se especificó
if ($archivo) {
    try {
        $jsonOutput | Out-File -FilePath $archivo -Encoding utf8 -Force
        Write-Host "Resultados exportados correctamente a: $archivo" -ForegroundColor Green
    }
    catch {
        Write-Host "Error al guardar el archivo JSON: $_" -ForegroundColor Red
    }
}

if ($resultados.Count -eq 0) {
    Write-Host "No se encontraron datos válidos para procesar." -ForegroundColor Yellow
}