#!/bin/bash

#
# tunel.sh
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
# Script para realizar túnel reverso, esto permitirá acceder a un servidor que
# está en una red LAN detrás de un firewall desde una ubicación remota.
#
# En el servidor a donde nos conectaremos debemos editar el archivo de
# configuración del servicio de SSH y agregar:
#   GatewayPorts yes
# Esto permitirá que los puertos que se abren en dicho servidor sean
# accesibles desde fuera de la máquina (ya que por defecto solo son accesibles
# mediante localhost)
#
# Se requiere autenticación mediante RSA contra el servidor.
#   ssh-keygen
#   scp ~/.ssh/id_rsa.pub usuario@servidor:
# Luego en el servidor
#   mkdir -p ~/.ssh
#   cat id_rsa.pub >> ~/.ssh/authorized_keys
#   rm id_rsa.pub
#
# Para verificar el túnel cada 5 minutos y levantarlo si no existe agregar a
# cron (mediante: crontab -e)
#   */5 * * * * /root/bin/tunel.sh
# Lo anterior asumiendo que el script se encuentra en dicha ruta.
# 
# Finalmente, recordar que el script debe tener persmisos de ejecución:
#   chmod +x /root/bin/tunel.sh
#

# Configuración
USER=""
HOST=""
PORTS=(
	# ip		puerto local	puerto remoto
	127.0.0.1	22		2201
	127.0.0.1	80		8001
	192.168.1.10	80		8002
)

# Por cada puerto verificar si hay un túnel levantado, si no existe se crea
function tunel_check {
	i=0
	while [ $i -lt ${#PORTS[@]} ]; do
		# obtener puertos
		IP=${PORTS[$i]}
		LOCAL=${PORTS[$i+1]}
		REMOTE=${PORTS[$i+2]}
		# verificar conexion
		CONEXION="$REMOTE:$IP:$LOCAL $USER@$HOST"
		echo "Verificando conexión $CONEXION"
		EXISTE=`ps aux | grep -v grep | egrep "$CONEXION" | wc -l`
		if [ $EXISTE -eq 0 ]; then
			echo " No existe conexión, creando túnel..."
			ssh -R $CONEXION -N &
		else
			echo " Todo ok."
		fi
		i=`expr $i + 3`
	done
}

# Cerrar todos los túneles
function tunel_close {
	P=`ps -u $(whoami) x | grep "ssh -R" | grep -v grep | awk '{print $1}'`
	for p in $P; do
		echo "Terminando túnel de PID $p"
		kill $p
	done
}

# Ejecutar acción solicitada
case "$1" in
	close)
		tunel_close
	;;
	*)
		tunel_check
        ;;
esac
