#!/bin/bash

# Funciones 

#ayuda para mostrar cómo usar el script
mostrar_ayuda() {
    cat <<EOF
Uso: $0 [OPCIONES]

Este script actúa como un demonio para monitorear un directorio de descargas y organizar archivos 
según su extensión. También realiza backups periódicos después de un número determinado de ordenamientos.

Opciones:
  -d, --directorio <ruta>      Directorio de descargas a monitorear. (Obligatorio)
  --salida <ruta>              Directorio donde se guardarán los backups. (Obligatorio)
  -c, --cantidad <entero>      Cantidad de archivos procesados antes de generar un backup. (Opcional, por defecto 10)
  -k, --kill                   Detiene el demonio en ejecución para el directorio especificado.
  -h, --help                   Muestra esta ayuda y termina la ejecución del script.

Funcionamiento:
  - Ordena archivos automáticamente en subdirectorios según su extensión dentro de <directorio>.
  - Cada vez que el número de archivos organizados alcanza <cantidad>, se realiza un backup en <backup>.
  - Si el proceso ya está en ejecución, el script evita iniciar un duplicado.
  - Puede ejecutarse en segundo plano, permitiendo la independencia de la sesión de terminal.

Ejemplo de uso:
  ./script.sh --directorio /home/usuario/descargas --salida /home/usuario/backups -c 20
  ./script.sh -d /home/usuario/descargas -k   (Para detener el demonio en ejecución)

EOF
}


# Variable global para PID de inotifywait
INOTIFY_PID=""

# Limpieza al terminar
limpiar() {
    echo -n "Terminando demonio y procesos hijos..."
    
    # 1. Matar inotifywait si existe
    if [[ -n "$INOTIFY_PID" ]] && ps -p "$INOTIFY_PID" > /dev/null; then
        kill "$INOTIFY_PID" 2>/dev/null
        echo -n " inotifywait (PID $INOTIFY_PID) detenido."
    fi
    
    # 2. Matar todos los procesos hijos del grupo
    kill -- -$(ps -o pgid= $$ | grep -o '[0-9]*') 2>/dev/null
    
    # 3. Eliminar archivo PID
    rm -f "$pidfile"
    echo " Limpieza completada."
    exit 0
}

#Funcion para detener demonio
detener_demonio() {
	local pidfile="$1"

    if [[ -f "$pidfile" ]]; then
        local demonio_pid=$(head -n 1 "$pidfile")
        
        if ps -p "$demonio_pid" > /dev/null; then
            echo "Enviando señal de terminación al demonio (PID $demonio_pid)..."
            
            # Enviar señal al grupo completo de procesos
            kill -SIGTERM -- -$(ps -o pgid= $demonio_pid | grep -o '[0-9]*') 2>/dev/null
            
            # Esperar confirmación
            sleep 0.5
            if ps -p "$demonio_pid" > /dev/null; then
                echo "Fallo al terminar, intentando kill -9..."
                kill -9 "$demonio_pid"
            fi
            
            echo "Demonio y procesos asociados detenidos."
            rm -f "$pidfile"
            exit 0
        else
            echo "Proceso principal ya terminado. Limpiando archivo PID."
            rm -f "$pidfile"
            exit 1
        fi
    else
        echo "Error: No hay demonio ejecutándose para este directorio."
        exit 1
    fi
}

# Función para mover archivo a su directorio correspondiente
mover_archivo() {
    archivo="$1"

	# Ignorar si es un directorio
	if [ -d "$archivo" ]; then
		return
	fi

    nombre_archivo=$(basename "$archivo")

    # Obtener la extensión o usar 'sin_extension' si no tiene
    if [[ "$nombre_archivo" == *.* ]]; then
        extension="${nombre_archivo##*.}"
    else
        extension="sin_extension"
    fi

    carpeta_destino="$directorio_monitoreo/$extension"

    # Crear el directorio de destino si no existe
    mkdir -p "$carpeta_destino"

    # Mover el archivo al directorio correspondiente
    mv "$archivo" "$carpeta_destino/"
}

# Función para crear un backup comprimido del directorio monitoreado
crear_backup() {
    fecha=$(date +"%Y%m%d-%H%M%S")

    backup_nombre="descargas_$fecha.zip"

    # Verificar si el directorio de backups existe; si no, lo crea
    if [ ! -d "$directorio_backup" ]; then
        mkdir -p "$directorio_backup"
    fi

    # Crear el archivo .zip con todo el contenido del directorio monitoreado
    # Se excluye el directorio de backups para evitar incluir el archivo ZIP dentro del mismo ZIP
    zip -r "$directorio_backup/$backup_nombre" "$directorio_monitoreo" -x "$directorio_backup/*"
}

# Función demonio que monitorea el directorio en busca de nuevos archivos
demonio() {
    contador_ordenamientos=0
	# Configurar nuevo grupo de procesos

	trap limpiar SIGTERM SIGINT

    # Primero procesar archivos ya existentes en el directorio
    for archivo in "$directorio_monitoreo"/*; do
        # Ignorar si no existe o si es un directorio
        if [ ! -f "$archivo" ]; then
			continue
		fi
        mover_archivo "$archivo"
        contador_ordenamientos=$((contador_ordenamientos + 1))

        # Crear un backup si se alcanza el límite de ordenamientos
        if [ "$contador_ordenamientos" -ge "$cantidad_ordenamientos_para_backup" ]; then
            crear_backup
            contador_ordenamientos=0
        fi
    done

    # Monitorear el directorio en tiempo real con inotify
	inotifywait -m -e create --format "%w%f" "$directorio_monitoreo" |
	while read archivo; do
		if [[ -f "$archivo" ]]; then
			mover_archivo "$archivo"
			contador_ordenamientos=$((contador_ordenamientos + 1))
			if [[ "$contador_ordenamientos" -ge "$cantidad_ordenamientos_para_backup" ]]; then
				crear_backup
				contador_ordenamientos=0
			fi
		fi
	done &
	
	INOTIFY_PID=$!
    echo $$ > "$pidfile"  # almaceno solo el PID del demonio principal
    # Restaurar manejo de señales y esperar
 
    wait  # ###############################no logro terminar los procesos
}



#---------------------------------FIN FUNCIONES------------------------------------------------------#



# Verificación de dependencias
if ! command -v inotifywait &> /dev/null
then
    echo "inotifywait no está instalado. Por favor, instala inotify-tools para continuar."
    exit 1
fi


#Procesa opciones
opciones=`getopt -o d:s:kc:h --long directorio:,salida:,kill,cantidad:,help -- "$@"`

if [ "$?" -ne 0 ]; then
	echo "Error en los parametros. Use -h para ayuda." >&2
	exit 1
fi

eval set -- "$opciones"

# Inicialización de variables
directorio_monitoreo=""
directorio_backup=""
flag_kill=0
cantidad_ordenamientos_para_backup=0

# Parseo de parámetros
#Lee parametros
while true; do
	case "$1" in
		-d | --directorio)
			if [[ -z "$2" || "$2" == -* || ! -d "$2" ]]; then
        		errores=1
			else
				directorio_monitoreo="$2"
				shift
			fi
			shift 
			;;
		-s | --salida) 
			if [[ -z "$2" || "$2" == -* ]]; then
				errores=1
            else
				directorio_backup="$2"
				shift			
			fi
            shift
			;;
		-c | --cantidad)
			if [[ -z "$2" || "$2" == -* || ! "$2" =~ ^[0-9]+$ || "$2" -le 0 ]]; then
				errores=1
			else
				cantidad_ordenamientos_para_backup="$2"
				shift			
			fi
            shift
			;;			
		-k | --kill) 
			flag_kill=1
            shift
			;;
		-h | --help) mostrar_ayuda;
		exit 0 
		;;
		--) shift;
		break 
		;;
		*) errores=1
			shift
			;;
	esac
done

if [[ "$errores" == 1 ]]; then
    echo "Error en los parametros de la llamada. Use -h para ayuda." >&2
    exit 1
fi

if [[ -z "$directorio_monitoreo" ]]; then
	echo "Error: Debes proporcionar el directorio a monitorear. Use -h para ayuda." >&2
	exit 1
fi

# Convertir ruta
directorio_monitoreo=$(realpath "$directorio_monitoreo")

#Genera un nombre de archivo .pid único para el directorio monitoreado usando su hash MD5.
#Evita conflictos entre demonios que se ejecutan en el sistema.
pidfile="/tmp/demonio_monitor_$(echo "$directorio_monitoreo" | md5sum | cut -d' ' -f1).pid"
	
if [[ "$flag_kill" -eq 1 && -n "$directorio_backup" ]]; then
	echo "Error: No se puede utilizar -s (salida) y -k (kill) a la vez. Use -h para ayuda." >&2
    exit 1
elif [[ "$flag_kill" -eq 1 ]]; then
	 detener_demonio "$pidfile"
fi


# Validar directorio backup
if [[ -z "$directorio_backup" ]]; then
    echo "Error: Debes proporcionar un directorio de backup valido. Use -h para ayuda."
    exit 1
	elif [[ "$directorio_backup" == */ ]]; then
		directorio_backup="${directorio_backup%/}"
fi

# Validar cantidad de archivos a ordenar antes del backup
if [[ -z "$cantidad_ordenamientos_para_backup" ]]; then
    echo "Error: Debes proporcionar la cantidad de archivos a ordenar antes del backup. Use -h para ayuda."
    exit 1
fi

# Comprobar si ya existe un demonio en ejecución para este directorio
if [[ -f "$pidfile" ]]; then
    pid_guardado=$(cat "$pidfile")
    if ps -p "$pid_guardado" > /dev/null 2>&1; then
        echo "Ya hay un demonio en ejecución para el directorio '$directorio_monitoreo' (PID $pid_guardado)."
        exit 1
    else
        echo "Se encontró un archivo PID huérfano. Eliminándolo..."
        rm -f "$pidfile"
    fi
fi




# Ejecutar el demonio en segundo plano
echo "Iniciando demonio para monitorear '$directorio_monitoreo'..."
demonio &

# Capturo el nuevo PID y verifico que se lanzó bien
pid_demonio="$!"
if ps -p "$pid_demonio" > /dev/null 2>&1; then
   echo "$pid_demonio" > "$pidfile"
   disown
   echo "Demonio iniciado correctamente (PID $pid_demonio)."
else
    echo "Error: el demonio no se pudo iniciar." >&2
    exit 1
fi


echo "Demonio en ejecución. Puedes continuar usando la terminal."
