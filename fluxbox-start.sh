#!/bin/bash

# colocar fondo de pantalla
fbsetbg -f /home/delaf/fotos/backgrounds/dark-woman-face_1366x768_13298.jpg

# iniciar programas que no requieren de la red conectada
conky &
#yeahconsole &
fdpowermon &

# iniciar programas de red solo si hay una puerta de enlace predeterminada
# usando wicd se asume que la conexion a la red se hara antes de iniciar sesion
GW_OK=` /sbin/route -n | egrep "^0.0.0.0" | awk '{if($2 != "0.0.0.0") print 1}'`
if [ $GW_OK -eq 1 ]; then
	chromium &
	pidgin &
	deluge &
fi
