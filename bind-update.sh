#!/bin/bash

#
# bind-update.sh
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
# Script que permite actualizar la IP de un único registro A en un archivo de
# configuración de una zona de bind9
#
# Requisitos para que el script funcione:
#   - Se requiere que la línea del serial sea así:
#                             2013123004              ; Serial
#   - Se requiere  que la línea del registro A sea así:
#                     IN A            190.45.95.106           ; ip dominio
# Lo importante son los comentarios "Serial" e "ip dominio" ya que se usan para
# hacer el filtrado y poder reemplazar. Obviamente estos comentarios no pueden
# estar en otra parte del archivo
#
# Ejemplo ejecución:
#  /root/bind-update.sh /etc/bind/zones alphonse.zapto.org
#

# verificar parámetro pasado
if [ $# -ne 2 ]; then
	echo "Modo de uso:"
	echo "	$0 <directorio de zonas> <dominio para obtener IP>"
	exit 1
fi

# verificar que el directorio que se indicó exista
if [ ! -d $1 ]; then
	echo "Directorio $1 no existe"
	exit 1
fi

# obtener serial e ip nuevas
SERIAL_NEW=`date +%Y%m%d%H`
IP_NEW=`dig +short $2 | tail -1` 

# $1 Nonbre del archivo
# $2 ¿Qué reemplazar?
# $3 ¿Por qué reemplazar?
function file_replace {
        FILE_REPLACE="/tmp/file_replace_`date +%H%M%S%N`"
        sed s/$2/$3/g $1 > $FILE_REPLACE
        mv $FILE_REPLACE $1
}

# procesar cada una de las zonas
for FILE in `ls $1 | grep -v conf$`; do
	SERIAL_OLD=`grep -i "; Serial" $1/$FILE | awk '{print $1}'`
	IP_OLD=`grep -i "; ip dominio" $1/$FILE | awk '{print $3}'`
	file_replace $1/$FILE $SERIAL_OLD $SERIAL_NEW
	file_replace $1/$FILE $IP_OLD $IP_NEW
done

# reiniciar servidor dns
/etc/init.d/bind9 restart
