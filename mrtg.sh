#!/bin/bash

#
# mrtg.sh
# Copyright (C) 2015 Esteban De La Fuente Rubio (esteban[at]delaf.cl)
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
# Script para generar estadísticas para MRTG a partir de cierta configuración.
# Se asume configuración en /etc/mrtg.d
#
# Crear configuración de máquina a monitorear con algo como:
#   # cfgmaker public@192.168.1.1 > /etc/mrtg.d/firewall.cfg
# Luego editar archivo de configuración para ajustar WorkDir
#
# En cron agregar algo como:
# m   h  dom mon dow   command
# */5 *  *   *   *     /root/bin/mrtg.sh firewall
#

# si no se indicó configuración error
if [ "$1" = "" ]; then
	echo "[error] Modo de uso: $0 config"
	exit 1
fi
CONFIG="/etc/mrtg.d/${1}.cfg"
LOG="/var/log/mrtg/mrtg-${1}.log"

# verificar que exista la configuración y se pueda leer
if [ ! -r $CONFIG ]; then
	echo "[error] La configuración $CONFIG no es válida"
	exit 1
fi

# si el directorio de trabajo de MRTG no existe se crea
WORK_DIR=`grep '^WorkDir' $CONFIG | awk '{ print $NF }'`
if [ ! -d "$WORK_DIR" ]; then
	mkdir $WORK_DIR
	indexmaker --title="$1" --output $WORK_DIR/index.html $CONFIG >> $LOG 2>&1
	chown -R www-data:www-data $WORK_DIR
fi

# crear directorio para LOGs (por si no existe)
mkdir -p `dirname $LOG`

# ejecutar MRTG para crear estadísticas
env LANG=C /usr/bin/mrtg $CONFIG >> $LOG 2>&1

