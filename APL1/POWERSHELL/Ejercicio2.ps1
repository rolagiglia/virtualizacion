#------------------------------------------------------------
# APL1. Ejercicio2
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
    [Parameter(HelpMessage="Ruta de la matriz.")]
    [string][Alias("m")]$matriz,
    
    [Parameter(HelpMessage="Separador del archivo.")]
    [string][Alias("s")]$separador,
    
    [Parameter(HelpMessage="Transponer matriz.")]
    [switch][Alias("t")]$trasponer,
    
    [Parameter(HelpMessage="producto por matriz.")]
    [double][Alias("p")]$producto,

    [Parameter(HelpMessage="Muestra esta ayuda.")]
    [switch][Alias("h")]$help
)

function VerificarSeparador {
    param (
        [Parameter(Mandatory=$true)]
        [string]$separador
    )
    if($separador -match '[0-9,\-]'){
        Write-Host "El separador no es válido: $separador" -ForegroundColor Red
        exit
    }
}
function ObtenerMatriz {
    param (
        [Parameter(Mandatory=$true)]
        [string]$origen,

        [Parameter(Mandatory=$true)]
        [string]$separador
    )

    $matrizArray = @()
    $lineas = Get-Content -Path $origen

    foreach ($linea in $lineas) {
        $elementos = $linea -split [regex]::Escape($separador)
        $fila = @()

        foreach ($elemento in $elementos) {
            $valor = $elemento.Trim()

            # Reemplazar , por . ANTES de intentar parsearlo
            if ($valor -match '^-?\d+([.,]\d+)?$') {
                $valor = $valor -replace ',', '.'
                try {
                    $fila += [double]::Parse($valor, [System.Globalization.CultureInfo]::InvariantCulture)
                } catch {
                    Write-Host "Error al convertir '$valor' a número." -ForegroundColor Red
                }
            } else {
                Write-Host "Error: Valor no numérico '$valor'" -ForegroundColor Red
            }
        }

        $matrizArray += ,$fila
    }

    return $matrizArray
}
#
function VerificarMatriz {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$rutaArchivo,
        
        [Parameter(Mandatory=$true)]
        [string]$separador
    )

    # Leer contenido del archivo
    $contenido = Get-Content -Path $RutaArchivo
    
    # Verificar archivo no vacío
    if ($contenido.Count -eq 0) {
        Write-Host "Error: El archivo está vacío - $RutaArchivo" -ForegroundColor Red
        exit 1
    }

    # Verificar consistencia de columnas y valores numéricos
    $numeroColumnas = -1
    foreach ($linea in $contenido) {
        $elementos = $linea -split [regex]::Escape($Separador)
        
        if ($numeroColumnas -eq -1) {
            $numeroColumnas = $elementos.Count
            if ($numeroColumnas -eq 0) {
                Write-Host "Error: No hay columnas detectadas" -ForegroundColor Red
                exit 1
            }
        }
        elseif ($elementos.Count -ne $numeroColumnas) {
            Write-Host "Error: Inconsistencia en columnas (línea $($contenido.IndexOf($linea)+1))" -ForegroundColor Red
            exit 1
        }

        foreach ($elemento in $elementos) {
            if (-not ($elemento -match '^-?\d+([.,]\d+)?$')) {
                Write-Host "Error: Valor no numérico - '$elemento'" -ForegroundColor Red
                exit 1
            }
        }
    }
}
#
function TrasponerMatriz {
    param (
        [Parameter(Mandatory=$true)]
        [array]$matriz
    )

    $matrizTraspuesta = @()

    $filas = $matriz.Count
    $columnas = $matriz[0].Count

    for ($i = 0; $i -lt $columnas; $i++) {
        $nuevaFila = @()
        for ($j = 0; $j -lt $filas; $j++) {
            $nuevaFila += $matriz[$j][$i]
        }
        $matrizTraspuesta += ,$nuevaFila
    }

    return $matrizTraspuesta
}
function ProductoMatriz {
    param (
        [Parameter(Mandatory=$true)]
        [array]$matriz,

        [Parameter(Mandatory=$true)]
        [double]$producto
    )
    $resultado = @()
    foreach ($line in $matriz) {
        
        $filaResultado = @()
        foreach ($element in $line) {
            $resultadoDouble = [double]0.0
            $resultadoDouble += [double]$element * $producto
            $filaResultado += $resultadoDouble
        }
        $resultado += ,$filaResultado 
    }
    return $resultado
}
function GuardarMatrizEnArchivo {
    param (
        [Parameter(Mandatory=$true)]
        [array]$matriz,

        [Parameter(Mandatory=$true)]
        [string]$archivoEntrada,

        [Parameter()]
        [string]$separador
    )

    # Obtener nombre y carpeta del archivo original
    $nombreEntrada = [System.IO.Path]::GetFileName($archivoEntrada)
    $carpeta = [System.IO.Path]::GetDirectoryName((Resolve-Path $archivoEntrada))
    $nombreSalida = "salida.$nombreEntrada"
    $rutaSalida = Join-Path -Path $carpeta -ChildPath $nombreSalida

    # Preparar contenido como texto
    $lineas = @()
    foreach ($fila in $matriz) {
        $lineas += ($fila -join $separador)
    }

    # Escribir en archivo
    Set-Content -Path $rutaSalida -Value $lineas -Encoding UTF8
    Write-Host "Matriz escrita en: $rutaSalida" -ForegroundColor Green
}

if ($help) {
    Write-Host "Uso: .\Ejercicio2.ps1 -matriz <ruta> [-separador <archivo salida>] ([-trasponer] ó [-producto]) [-help]" -ForegroundColor Green
    Write-Host "-matriz: Ruta del directorio donde se buscara la matriz." -ForegroundColor Green
    Write-Host "-separador: Caracter por el cual se separara cada elemento de la matriz ." -ForegroundColor Green
    Write-Host "-trasponer: Muestra el resultado en pantalla." -ForegroundColor Green
    Write-Host "-producto: Muestra el resultado en pantalla, ingresar numero para multiplicar." -ForegroundColor Green
    Write-Host "-help: Muestra esta ayuda." -ForegroundColor Green
    exit
}

if (-not $matriz) {
    Write-Host "Error: El parametro -matriz es obligatorio." -ForegroundColor Red
    exit
}

if (-not $separador) {
    Write-Host "Error: El parametro -separador es obligatorio." -ForegroundColor Red
    exit
}

if($trasponer -and $producto){
    Write-Host "Debe seleccionar trasponer o producto, no se pueden los dos a la vez" -ForegroundColor Red
    exit
}
if(-not( $trasponer -or $producto)){
    Write-Host "Debe seleccionar trasponer o producto." -ForegroundColor Red
    exit
}
VerificarSeparador -separador $separador

VerificarMatriz -rutaArchivo $matriz -separador $separador

$matrix = ObtenerMatriz -origen $matriz -separador $separador

if ($trasponer) {
    $resultado = TrasponerMatriz -matriz $matrix
} elseif ($producto) {
    $resultado = ProductoMatriz -matriz $matrix -producto $producto
}

GuardarMatrizEnArchivo -matriz $resultado -archivoEntrada $matriz -separador $separador