#!/bin/bash
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


# Muestra la ayuda del script
mostrarAyuda() {
  cat <<EOF
Ayuda del script: $0 [OPCIONES]

Descripcion:
Procesa archivos CSV con temperaturas y genera un resumen por día y ubicación en formato JSON. La salida puede ser por pantalla(-p) o por archivo (-a <nombre de archivo>).

Opciones:
  -d, --directorio <"ruta">   Directorio que contiene los archivos CSV a procesar (obligatorio). Las rutas de los directorios deben encomillarse si poseen espacios. <"ruta"> 
  -a, --archivo <"archivo">   Archivo JSON de salida. No permite utilizarse en simultaneo con -p. Los nombres de los archivos o sus rutas completas deben encomillarse si poseen espacios. <"archivo/ruta">
  -p, --pantalla            Muestra el JSON generado por pantalla. No permite su uso en simultaneo con -a
  -h, --help                Muestra esta ayuda.

Ejemplos:
  $0 -d "./datos" -p
  $0 --directorio /home/usuario/mediciones --archivo resultado.json
EOF
}

# Valida fechas en varios formatos
validar_fecha() {
	local fecha="$1"
	local fecha_normalizada=""

    if [[ "$fecha" =~ ^[0-9]{4}[-/][0-9]{2}[-/][0-9]{2}$ ]]; then
        # YYYY-MM-DD o YYYY/MM/DD
        fecha_normalizada="${fecha//\//-}"

    elif [[ "$fecha" =~ ^[0-9]{2}[-/][0-9]{2}[-/][0-9]{4}$ ]]; then
        # DD-MM-YYYY o DD/MM/YYYY
        fecha_normalizada="${fecha//\//-}"
        local dia="${fecha_normalizada:0:2}"
        local mes="${fecha_normalizada:3:2}"
        local anio="${fecha_normalizada:6:4}"
        fecha_normalizada="$anio-$mes-$dia"
    else
        return 1
    fi

    date -d "$fecha_normalizada" "+%Y-%m-%d" >/dev/null 2>&1
}

# Procesamiento de opciones
opciones=`getopt -o d:a:ph --long directorio:,archivo:,pantalla,help -- "$@"`

if [ "$?" -ne 0 ]; then
	echo "Error en los parametros de la llamada. Use -h para ayuda." >&2
	exit 1
fi

eval set -- "$opciones"

# Inicialización de variables
directorio=""
archivoOut=""
pantalla=false
errores=false

# Lectura de argumentos
while true; do
	case "$1" in
		-d | --directorio) 
			if [[ -z "$2" || "$2" == -* || ! -d "$2" ]]; then
        			errores=true
			else
				directorio="$2"
				shift
			fi
			shift 
			;;
		-a | --archivo) 
			if [[ -z "$2" || "$2" == -* || "$pantalla" == true ]]; then
				errores=true
			else
				archivoOut="$2"
				shift
			fi
            shift
			;;
		-p | --pantalla) 
			if [[ -n "$archivoOut" ]]; then 
				errores=true
			else
				pantalla=true;
			fi
			shift 
			;;
		-h | --help) mostrarAyuda;
		exit 0 
		;;
		--) shift;
		break 
		;;
		*) errors=true
		shift
		;;
	esac
done

#Validaciones adicionales

if [[ ( "$errores" == false && -z "$directorio") || (-z "$archivoOut" && "$pantalla" == false) ]]; then
    errores=true
fi

if [[ "$errores" == true ]]; then
    echo "Error en los parametros de la llamada. Use -h para ayuda." >&2
    exit 1
fi

# Validación de archivos .csv

#Shopt: los patrones que no coincidan con ningún archivo se expanden a una cadena vacía.
shopt -s nullglob
csv_files=("$directorio"/*.csv)
cantidad_archivos=0
archivos_validos=()

for archivo in "${csv_files[@]}"; do
    fecha_archivo=$(basename "$archivo" .csv)
    # Verificar que la fecha sea válida y que el archivo no esté vacío
	if validar_fecha "$fecha_archivo" && [[ -s "$archivo" && -f "$archivo" ]]; then
		archivos_validos+=("$archivo")
		((cantidad_archivos++))
	fi
done

if [[ ${#csv_files[@]} -eq 0 || "$cantidad_archivos" -eq 0 ]]; then
    echo "Error: No hay archivos CSV válidos en el directorio." >&2
    exit 1
fi

#Crea archivo temporal y asegurar su limpieza al salir
archivo_temporal=$(mktemp) || { 
								echo "Error: No se pudo crear un archivo temporal." >&2; 
								exit 1; 
								}
								
trap "rm -f $archivo_temporal" EXIT

# Procesamiento con awk
awk -F',' '
    function validar_fecha(f) {
        return f ~ /^[0-9]{4}[-/][0-9]{2}[-/][0-9]{2}$/ || f ~ /^[0-9]{2}[-/][0-9]{2}[-/][0-9]{4}$/
    }
    function normalizar_fecha(f) {
           gsub(/[\/\-]/, "-", f);
        split(f, a, "-");
        if (length(a[1]) == 4) {
                return a[1]"-"a[2]"-"a[3]
        } else {
                return a[3]"-"a[2]"-"a[1]
        }
    }
    function validar_hora(h) {
        return h ~ /^[0-9]{2}:[0-9]{2}:[0-9]{2}$/
    }
    function validar_temperatura(t) {
        return t ~ /^-?[0-9]+(\.[0-9]+)?$/
    }
    function validar_ubicacion(u) {
        return (u == "Norte" || u == "Sur" || u == "Este" || u == "Oeste")
    }
    
    {
		fecha=$2;
		hora=$3;
		ubicacion=$4;
		temp=$5;
		gsub(/\r/, "", fecha)
		gsub(/\r/, "", hora)
		gsub(/\r/, "", ubicacion)
		gsub(/\r/, "", temp)
		 
		# Validar fecha
		if (!validar_fecha(fecha)){
				next
		}
		
		fecha=normalizar_fecha(fecha)
		
		# Validar hora, temperatura y ubicación
		if (!validar_hora(hora) || !validar_temperatura(temp) || !validar_ubicacion(ubicacion)) {
			next
		}

		key = fecha SUBSEP ubicacion

		suma[key] += temp
		conteo[key]++

		if ((key in min) == 0 || temp < min[key])
			min[key] = temp
		if ((key in max) == 0 || temp > max[key])
			max[key] = temp

		fechas[fecha] = 1
	}
END {
    print "{"
    primer_fecha = 1
    for (f in fechas) {
        if (!primer_fecha)
            print "  },"
        print "  \"" f "\": {"

        primer_ubicacion = 1
        for (k in suma) {
            split(k, arr, SUBSEP)
            fecha_actual = arr[1]
            ubicacion = arr[2]

            if (fecha_actual == f) {
                if (!primer_ubicacion)
                    print "    },"
                print "    \"" ubicacion "\": {"
                print "      \"Min\": " min[k] ","
                print "      \"Max\": " max[k] ","
                print "      \"Promedio\": " suma[k] / conteo[k]
                primer_ubicacion = 0
            }
        }
        print "    }"
        primer_fecha = 0
    }
    print "  }"
    print "}"
}
' "${archivos_validos[@]}" >> "$archivo_temporal"

if [[ $? -ne 0 ]]; then
  echo "Ocurrió un error al procesar los archivos CSV." >&2
  exit 1
fi

# Mostrar resultado según opción
if [ "$pantalla" = true ]; then
    cat "$archivo_temporal"
else
    mv "$archivo_temporal" "$archivoOut.json" || {
												echo "No se pudo guardar el archivo de salida '$archivoOut.json'." >&2
												exit 1
												}
    echo "Procesamiento completado. Resultados guardados en $archivoOut.json."
fi

echo "Se procesaron $cantidad_archivos archivos .csv ." 
