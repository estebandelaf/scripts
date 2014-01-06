#!/bin/bash

#
# domains-check.sh
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
# Script que permite verificar cambios en la IP de un grupo de dominios y
# ejecutar un conjunto de comandos asociados a cada dominio en caso que dichos
# dominio haya cambiado su IP.
#
# Se debe crear un archivo para cada dominio, con el nombre del archivo el
# nombre del dominio. En cada archivo colocar, por cada línea, el comando que
# se desea ejecutar en caso que el dominio cambie de IP.
#
# Por ejemplo para verificar el dominio edward.sytes.net y reiniciar nginx en
# caso de que cambie crear en el directorio de los dominios el archivo
# edward.sytes.net con el contenido:
#   /etc/init.d/nginx restart
#
# Se puede programar con CRON usando algo similar a (ajustar rutas):
#   * * * * * /root/domains-check/domains-check.sh /root/domains-check/domains
#

# directorios para almacenar las ips y logs
DIR_IPS=/var/cache/domains-check
DIR_LOG=/var/log/domains-check

# verificar parámetro pasado
if [ $# -ne 1 ]; then
	echo "Modo de uso:"
	echo "	$0 <directorio con dominios>"
	exit 1
fi

# si se pasa el parámetro "clean" se borran directorios
if [ "$1" == "clean" ]; then
	rm -rf $DIR_IPS
	rm -rf $DIR_LOG
	echo "Directorios limpiados"
	exit 0
fi

# verificar que el directorio que se indicó exista
if [ ! -d $1 ]; then
	echo "Directorio $1 no existe"
	exit 1
fi

# crear directorios (por si no existen)
mkdir -p $DIR_IPS
mkdir -p $DIR_LOG

# nombre del archivo para log
LOG="$DIR_LOG/domains-check_`date +"%Y%m%d"`"

# procesar cada uno de los dominios
for DOMAIN in `ls $1`; do
	TIME=`date +"%Y-%m-%d %H:%M:%S"`
	IP_NEW=`dig +short $DOMAIN | tail -1`
	if [ $? -ne 0 ]; then
		echo "$TIME: dig $DOMAIN falló! omitiendo" >> $LOG
		continue
	fi
	echo "$TIME: $DOMAIN tiene la IP $IP_NEW" >> $LOG
	if [ -f $DIR_IPS/$DOMAIN ]; then
		IP_OLD=`cat $DIR_IPS/$DOMAIN`
	else
		IP_OLD="sin ip"
	fi
	# ejecutar cada uno de los comandos asociados al dominio en caso que
	# la ip haya cambiado
	if [ "$IP_OLD" != "$IP_NEW" ]; then
		echo "$TIME:     tenía la IP $IP_OLD" >> $LOG
		echo -n $IP_NEW > $DIR_IPS/$DOMAIN
		echo "$TIME:     ejecutando comandos" >> $LOG
		cat $1/$DOMAIN | while read CMD; do
			$CMD >> $LOG
		done
	fi
done
