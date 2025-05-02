#! /usr/bin/bash

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

#Funciones

# Producto escalar: Multiplicar cada elemento de la matriz por el número
producto_escalar() {
    echo "$1" | awk -v prod="$producto" -F"$separador" '
    {
        for(i=1; i<=NF; i++) {
            $i = $i * prod
        }
        print $0
    }' > "salida.$(basename "$matriz")"
}

# Trasponer la matriz (intercambiar filas por columnas)
transponer() {
    echo "$matriz_data" | awk -F"$separador" '
    {
        for(i=1; i<=NF; i++) {
            matriz[NR,i] = $i
        }
    }
    END {
        for(i=1; i<=NF; i++) {
            for(j=1; j<=NR; j++) {
                printf "%s", matriz[j,i]
                if(j < NR) { printf "%s", FS }
            }
            print ""
        }
    }' > "salida.$(basename "$matriz")"
}

# Si se pasa un archivo de matriz
if [[ -n "$matriz" ]]; then
    procesar_matriz "$matriz"
fi




#Procesa opciones
opciones=`getopt -o m:p:ts:h --long matriz:,producto:,trasponer,separador:,help -- "$@"`

if [ "$?" -ne 0 ]; then
	echo "Error en los parametros. Use -h para ayuda." >&2
	exit 1
fi

eval set -- "$opciones"

#Variables para los parametros y errores
matriz=""
producto=""
trasponer=false
separador=""
errores=false

#Lee parametros
while true; do
	case "$1" in
		-m | --matriz)
			if [[ -z "$2" || "$2" == -* || ! -f "$2" || ! $(file --mime-type "$2") =~ text ]]; then
        			errores=true
			else
				matriz="$2"
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

#Validaciones adicionales

# Si no hay errores previos, verificamos que los parámetros obligatorios estén presentes y sean coherentes
if [[ "$errores" == false  && ( 
      -z "$matriz" ||                     # Faltó el archivo de matriz
      ( -z "$producto" && "$trasponer" == false ) ||  # No se indicó ni producto escalar ni trasposición
      -z "$separador"                    # Faltó el separador
    ) ]]; then
    errores=true  
fi

if [ "$errores" == true ];then
	echo "Los parametros no son validos. Use -h para ayuda."
	exit 1
fi



nombre_archivo=$(basename "$matriz")
directorio_archivo=$(dirname "$matriz")
archivo_salida="${directorio_archivo}/salida.${nombre_archivo}"



# Leer el archivo y lo procesa con awk
    awk -v separador="$separador" -v producto="$producto" -v trasponer="$trasponer" '
    BEGIN {
        FS = separador
		primera_fila = 1
		numero_campos = -1
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
			print "Error: Los registros del archivo no son validos"
			exit 1  
		}
		
		#Almacenamos el campo del registro actual
        for(i = 1; i <= NF; i++) {
            if($i !~ /^[-+]?[0-9]+(\.[0-9]+)?$/){
				print "Error: El archivo posee campos no validos"
				exit 1
			}
			matriz[NR,i] = $i
        }
        
    }
    END {
        if( NR != campos || NR == 0){
			print "Archivo vacio o cantidad de filas no valida."
			exit 1
		}
		else	
			if (trasponer == "true") {
				#trasponer
				for (i = 1; i <= campos; i++) {
					for (j = 1; j <= NR; j++) {
						printf "%s", matriz[j,i]
						if (j < NR) 
							printf "|"
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
							printf "|"
					}
					print ""
					}
				} 
				else {
					print "Error: No se indicó ni producto ni trasposición."
					exit 1
				}
	}' "$matriz" > "$archivo_salida" 
	
	cat "$archivo_salida"
	
	
	
	
	
	
	
	