#!/bin/bash

#
# domains_check.sh
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
# ejecutar un conjunto de comandos en caso que alguno de dichos dominios haya
# cambiado su IP
#

# listado con los dominios que se deben chequear por si cambiaron de IP
DOMAINS=(
	edward.sytes.net
)

# comandos que se deberán ejecutar al detectar un cambio de IP
COMANDOS=(
	"/etc/init.d/nginx restart"
)

# directorios para almacenar las ips y logs
DIR_IPS=/var/cache/domains_check
DIR_LOG=/var/log/domains_check

# crear directorios (por si no existen)
mkdir -p $DIR_IPS
mkdir -p $DIR_LOG

# asumir que no han habido cambios
CHANGES=0

# nombre del archivo para log
LOG="$DIR_LOG/domains_check_`date +"%Y%m%d"`"

# revisar la ip de cada dominio
for DOMAIN in ${DOMAINS[*]}; do
	TIME=`date +"%Y-%m-%d %H:%M:%S"`
	IP_NEW=`dig +short $DOMAIN`
	if [ -f $DIR_IPS/$DOMAIN ]; then
		IP_OLD=`cat $DIR_IPS/$DOMAIN`
	else
		IP_OLD="sin ip"
	fi
	echo "$TIME: $DOMAIN tiene la IP $IP_NEW" >> $LOG
	if [ "$IP_OLD" != "$IP_NEW" ]; then
		echo "$TIME:     tenía la IP $IP_OLD" >> $LOG
		echo -n $IP_NEW > $DIR_IPS/$DOMAIN
		CHANGES=1
	fi
done

# si se detectó algún cambio de IP ejecutar los comandos
if [ $CHANGES -eq 1 ]; then
	for COMANDO in "${COMANDOS[@]}"; do
		$COMANDO >> $LOG
	done
fi
