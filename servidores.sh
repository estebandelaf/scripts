#!/bin/bash

#
# Domains check
# Copyright (C) 2013 Esteban De La Fuente Rubio (esteban[at]delaf.cl)
#
# Este programa es software libre: usted puede redistribuirlo y/o modificarlo
# bajo los términos de la Licencia Pública General GNU publicada
# por la Fundación para el Software Libre, ya sea la versión 3
# de la Licencia, o (a su elección) cualquier versión posterior de la misma.
#
# Este programa se distribuye con la esperanza de que sea útil, pero
# SIN GARANTÍA ALGUNA; ni siquiera la garantía implícita
# MERCANTIL o de APTITUD PARA UN PROPÓSITO DETERMINADO.
# Consulte los detalles de la Licencia Pública General GNU para obtener
# una información más detallada.
#
# Debería haber recibido una copia de la Licencia Pública General GNU
# junto a este programa.
# En caso contrario, consulte <http://www.gnu.org/licenses/gpl.html>.
#

#
# Script que permite sincronizar un conjunto de directorios en servidores.
#
# Modo de uso:
#   - Sincronización de todos los servidores (los que tengan AUTO="yes"):
#       $ ./servidores
#   - Sincronizar un servidor (server) en particular (aunque tenga AUTO="no")
#       $ ./servidores server
#
# El script buscará los directorios existentes en $DIR, cada directorio se
# considerará como un servidor. Adicionalmente para cada directorio deberá
# existir al mismo nivel un archivo .conf que contendrá la configuración para
# el servidor (host, port, etc). De esta forma tendremos:
#
#   $ ls $DIR
#   servidor1 servidor1.conf servidor2 servidor2.conf
#
# Cada directorio servidorX tendrá dentro los directorios que se deseen
# sincronizar con el servidor, para esto se deberá declarar un mapeo de
# directorio local a directorio remoto mediante el archivo de configuración.
#
# El archivo de configuración actualmente soporta las siguientes opciones:
#
#   AUTO    : string "yes" o "no" que indica si se debe sincronizar
#             automáticamente el servidor. Si es "no" solo se podrá hacer la
#             sincronización de forma explícita (default: "yes")
#   HOST    : string con el dominio o IP del servidor (default: "") 
#   PORT    : entero con el número de puerto del servidor (default: 22)
#   DIRS    : mapeo entre directorios locales y remotos (incluyendo usuario)
#   EXCLUDE : arreglo con el directorio local y los archivos que se deben
#             excluir al hacer la sincronización
#
# Ejemplo de archivo de configuración para servidor toshiro (directorio toshiro
# y configuración toshiro.conf):
#
# HOST=edward.delaf.cl
# PORT=22035
# DIRS=(
#	delaf		app		/home/delaf/app
#	delaf		mipagina	/usr/share/mipagina
#	delaf		www		/home/delaf/www
# )
# EXCLUDE=(
# 	app		easyvhosts/.git
#	mipagina	.git
# )
#

# directorio donde se encuentran los directorios de cada servidor y su
# configuración
DIR="/home/delaf/servidores"

# programa rsync y los parámetros con los que se ejecutará
RSYNC="rsync -vv --human-readable --archive --copy-links --compress --delete"

# función para crear el string real con los exclude para cada aplicación
function crearExclude {
	EX=""
	i=0
	while [ $i -lt ${#EXCLUDE[@]} ]; do
		if [ "${EXCLUDE[$i]}" = "$1" ]; then
			EX="$EX --exclude ${EXCLUDE[$i+1]}"
		fi
		i=`expr $i + 2`
	done
	echo $EX
}

# ingresar al directorio de los servidores
cd $DIR

# limpiar la pantalla
clear

# procesar cada uno de los directorios
for SERVIDOR in `ls $DIR`; do
	# si se pidió un servidor en particular
	if [ -n "$1" ]; then
		if [ "$1" != "$SERVIDOR" ]; then
			continue
		fi
	fi
	# si es directorio => es un servidor, además se chequea que exista
	# un archivo de configuración para el servidor, de no existir no se
	# considerará para la sincronización
	if [ -d $DIR/$SERVIDOR -a -f $DIR/$SERVIDOR.conf ]; then
		# configuraciones por defecto
		AUTO="yes"
		HOST=""
		PORT=22
		DIRS=()
		EXCLUDE=()
		# cargar configuración para el servidor (sobreescribirá valores
		# por defecto)
		. $DIR/$SERVIDOR.conf
		# procesar solo si el servidor está activado para ser procesado
		# de forma automática o si se pidió de forma explícita
		if [ "$AUTO" = "yes" -o "$1" == "$SERVIDOR" ]; then
			# procesar cada uno de los directorios locales del
			# servidor
			i=0
			while [ $i -lt ${#DIRS[@]} ]; do
				# recuperar datos del directorio
				USUARIO=${DIRS[$i]}
				DIR_LOCAL=${DIRS[$i+1]}
				DIR_REMOTE=${DIRS[$i+2]}
				i=`expr $i + 3`
				# generar string con los posibles exclude
				EXCLUDE=`crearExclude $DIR_LOCAL`
				# enviar actualizaciones
				$RSYNC --rsh="ssh -p$PORT" $EXCLUDE \
					$DIR/$SERVIDOR/$DIR_LOCAL/ \
					$USUARIO@$HOST:$DIR_REMOTE | \
					grep -v "is uptodate"
			done
		fi
	fi
done
