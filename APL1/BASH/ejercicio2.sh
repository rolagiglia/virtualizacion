#!/bin/bash
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

#Funcion para mostrar ayuda
mostrarAyuda() {
  cat <<EOF
Ayuda del script: $0 [OPCIONES]
Objetivo:
    Realizar producto escalar o trasposición de matrices leídas desde un archivo de texto plano.

Parámetros obligatorios:
    -m, --matriz <archivo>        Ruta al archivo de texto plano que contiene la matriz.
    -s, --separador <carácter>    Carácter separador de columnas. Debe ser un único carácter
                                  distinto de números y el guion (-).

Operaciones (una sola debe especificarse):
    -p, --producto <entero>       Realiza el producto escalar de la matriz por el valor entero indicado.
                                  No puede usarse junto con -t / --trasponer.
    -t, --trasponer               Realiza la trasposición de la matriz.
                                  No puede usarse junto con -p / --producto.

Formato del archivo de entrada:
    - Cada fila representa una fila de la matriz.
    - Las columnas deben estar separadas por el carácter indicado con -s.
    - Todos los valores deben ser numéricos (enteros o decimales, positivos o negativos).
    - Ejemplo válido con separador "|":
        1|2|3
        4|5|6
        7|8|9

Validaciones:
    - Se rechazan matrices con filas de distinta longitud.
    - Se rechazan valores no numéricos.
    - El archivo no puede estar vacío.
    - El separador no puede ser un número ni el símbolo "-".

Salida:
    El resultado se guarda en un archivo llamado "salida.<nombreArchivoEntrada>".
    El archivo se ubicará en el mismo directorio donde se encuentra la matriz original.

Ejemplos:
    ./script.sh -m ./matrices/m1.txt -p 2 -s "|"
    ./script.sh --matriz m2.txt --trasponer --separador ","

EOF
}

# Escapa el separador si contiene caracteres especiales de regex
escape_regex() {
  echo "$1" | sed -E 's/[][\/.^$*+?(){}]/\\&/g'
}

#Procesa opciones
opciones=`getopt -o m:p:ts:h --long matriz:,producto:,trasponer,separador:,help -- "$@"`

if [ "$?" -ne 0 ]; then
	echo "Error en los parametros. Use -h para ayuda." >&2
	exit 1
fi

eval set -- "$opciones"

#Inicializacion de variables
archivo_matriz=""
producto=""
trasponer=false
separador=""
errores=false

#Lee parametros
while true; do
	case "$1" in
		-m | --matriz)
			if [[ -z "$2" || "$2" == -* || ! -f "$2" ]]; then
        			errores=true
			else
				archivo_matriz="$2"				
				
				# Conversión segura a formato Unix (CRLF -> LF)
				matriz_tmp="$(mktemp)"
				tr -d '\r' < "$archivo_matriz" > "$matriz_tmp" && mv "$matriz_tmp" "$archivo_matriz"
				shift
			fi
			shift 
			;;
		-p | --producto) 
			if [[ -z "$2" || ! "$2" =~ ^-?[0-9]+$ ]]; then
					errores=true
            else
				if [[ "$trasponer" == true ]];then
					errores=true
				else
					producto="$2"
				fi
				shift
			fi
            shift
			;;
		-t | --trasponer) 
			if [[ -n "$producto" ]]; then 
				errores=true
			else
				trasponer=true;
			fi
			shift 
			;;
		-h | --help) mostrarAyuda;
		exit 0 
		;;
		-s | --separador)
			if [[ -z "$2" || ! "$2" =~ ^[^0-9-]{1}$ || "$2" == -* ]]; then
				errores=true
			else
				separador="$2"
				shift
			fi
			shift
			;;
		--) shift;
		break 
		;;
		*) errores=true
			shift
			;;
	esac
done

#Trap eliminacion de archivo_temporal cuando el script finalice
trap "rm -f $matriz_tmp" EXIT


# Validacion de parámetros obligatorios
if [[ "$errores" == false  && ( 
      -z "$archivo_matriz" ||                     # Faltó el archivo de matriz
      ( -z "$producto" && "$trasponer" == false ) ||  # No se indicó ni producto escalar ni trasposición
      -z "$separador"                    # Faltó el separador
    ) ]]; then
    errores=true  
fi

if [ "$errores" == true ];then
	echo "Los parametros no son validos. Use -h para ayuda."
	exit 1
fi

#Validacion de archivo de entrada
if [[ ! "$(file --mime-type -b "$archivo_matriz")" =~ ^text/ ]]; then
	echo "El archivo proporcionado no es valido."
	exit 1
fi


nombre_archivo=$(basename "$archivo_matriz")
directorio_archivo=$(dirname "$archivo_matriz")
archivo_salida="${directorio_archivo}/salida.${nombre_archivo}"
separador_escapado=$(escape_regex "$separador")

#Procesamiento de la matriz con awk: validación, producto escalar o trasposición

awk_result=$(awk -v separador="$separador_escapado" -v producto="$producto" -v trasponer="$trasponer" '
BEGIN {
	FS = separador
	primera_fila = 1
	numero_campos = -1
	error = 0
}
{
	 # Contamos los campos de la fila actual
	campos = NF
	
	# Si es la primera fila, establecemos el número de campos
	if (primera_fila) {
		numero_campos = campos
		primera_fila = 0
	}
	
	# Si el número de campos no coincide con el de la primera fila, mostramos un error
	if (campos != numero_campos) {
		print "Error: matriz no valida. La cantidad de valores de las filas no coincide."
		error = 1
		exit 1  
	}
	
	#Almacenamos el campo del registro actual
	for(i = 1; i <= NF; i++) {
		 if ($i !~ /^[-+]?[0-9]+([.][0-9]+)?$/) {
			print "Error: El archivo posee campos no validos"
			error = 1
			exit 1
		}
		matriz[NR,i] = $i
	}
	
}
END {
	if (error) 
		exit 1  # No procesar si hubo errores
		
	if( NR == 0){
		print "Archivo vacio."
		exit 1
	}
	else	
		if (trasponer == "true") {
			
			# Trasposición			
			for (i = 1; i <= campos; i++) {
				for (j = 1; j <= NR; j++) {
					printf "%s", matriz[j,i]
					if (j < NR) 
						printf "%s", separador
				}
				print ""
			}
		} 
		else if (producto != "") {
		
			#Producto escalar
			for (i = 1; i <= NR; i++) {
				for (j = 1; j <= campos; j++) {
					printf "%s", matriz[i,j] * producto
					if (j < campos) 
						printf "%s", separador
				}
				print ""
				}
			} 
			else {
				print "Error: No se indicó ni producto ni trasposición."
				exit 1
			}
}' "$archivo_matriz" 2>&1) 

# Verificar si hubo errores en AWK
if [[ "$awk_result" =~ ^Error ]]; then
    echo "${awk_result//$'\n'/ }" >&2
    exit 1
fi

# Si todo está bien, guardar el resultado
echo "$awk_result" > "$archivo_salida"

echo "La operación se completó exitosamente. El resultado se guardó en: $archivo_salida"
	