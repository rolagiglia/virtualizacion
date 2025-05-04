#! /usr/bin/bash

#Funcion para mostrar ayuda
mostrarAyuda() {
  cat <<EOF
Uso: $0 [opciones]

Este script permite buscar y contar la cantidad de ocurrencias de ciertas palabras en archivos dentro de un directorio.

### Parámetros:
			
-d, --directorio  : Especifica el directorio donde se deben buscar los archivos. Si el directorio contiene espacios, debe ir entre comillas dobles ("").
-p, --palabras    : Especifica las palabras que se buscarán dentro de los archivos. Si las palabras contienen espacios, deben ir entre comillas dobles ("").
-a, --archivos    : Especifica las extensiones de los archivos que se deben buscar (por ejemplo, "txt", "log"). Si hay varias extensiones, sepáralas por espacio y ponlas entre comillas dobles.
-h, --help        : Muestra esta ayuda.
			
### Ejemplo de Uso:
./script.sh -d "/var/logs" -p "error advertencia" -a "log csv"
			
En este ejemplo:
- Se busca en el directorio "/var/logs".
- Se buscan las palabras "error" y "advertencia".
- Se buscarán archivos con la extensión .log y .cvs.
			
Si no usas comillas dobles, el script podría interpretar incorrectamente las rutas o palabras, causando errores.
EOF
}


#Procesa opciones
opciones=`getopt -o d:p:a:h --long directorio:,palabras:,archivos:,help -- "$@"`

if [ "$?" -ne 0 ]; then
	echo "Error en los parametros. Use -h para ayuda." >&2
	exit 1
fi

eval set -- "$opciones"

#Variables para los parametros y errores
directorio=""
palabras=""
archivos=""
errores=false

#Lee parametros
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
		-p | --palabras) 
			if [[ -z "$2" || "$2" == -* ]]; then
				errores=true
            else
				palabras="$2"
				shift			
			fi
            shift
			;;
		-a | --archivos) 
			if [[ -z "$2" || "$2" == -* ]]; then
				errores=true
            else
				archivos="$2"
				shift			
			fi
            shift
			;;
		-h | --help) mostrarAyuda;
		exit 0 
		;;
		--) shift;
		break 
		;;
		*) errores=true
			shift
			;;
	esac
done


#Validaciones adicionales

if [[ "$errores" == false && ( -z "$directorio" || -z "$archivos" || -z "$palabras" ) ]]; then
    errores=true
fi

if [[ "$errores" == true ]]; then
    echo "Error en los parametros de la llamada. Use -h para ayuda." >&2
    exit 1
fi


#Array
lista_archivos=()

#Almaceno las rutas de los archivos en el array lista_archivos
for ext in $archivos; do
	find "$directorio" -type f -iname "*.${ext}"
	# Valido extensiones
    if [[ "$ext" =~ ^[a-zA-Z0-9]{1,5}$ ]]; then
		#Leo la salida de find línea por línea y la añade al final del array lista_archivos
		 mapfile -t -O "${#lista_archivos[@]}" lista_archivos \
		< <(find "$directorio" -type f -iname "*.${ext}")
	fi
done


if [[ -z "$lista_archivos" ]]; then
	echo "No hay archivos con las extensiones suministradas en el directorio indicado."
	exit 1
fi

awk -v palabras="$palabras" '
BEGIN {
	#Guardo las palabras con índices numéricos en "claves"
	split(palabras, claves, " ")
	for (i in claves) {
		lista_palabras[claves[i]] = 0
	}
	total_palabras = length(claves)
}
{
	#Por cada linea del archivo actual
	#Y por cada palabra de la lista 
	for (palabra in lista_palabras) {
		# Cuenta coincidencias exactas
		patron = "\\<" palabra "\\>"
		lista_palabras[palabra] += gsub(patron, "")
	}
}
END {
	  print "Resultado del conteo:"

	# Ordenar claves[] por valor en lista_palabras[], descendente
	for (i = 1; i <= total_palabras; i++) {
		for (j = i + 1; j <= total_palabras; j++) {
			if (lista_palabras[claves[i]] < lista_palabras[claves[j]]) {
				tmp = claves[i]
				claves[i] = claves[j]
				claves[j] = tmp
			}
		}
	}

	# Imprimir resultados ordenados
	for (i = 1; i <= total_palabras; i++) {
		palabra = claves[i]
		print palabra ": " lista_palabras[palabra]
	}
}' "${lista_archivos[@]}"

