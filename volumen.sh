#!/bin/bash

# canal por el que se consultara el volumen
CHANNEL="Master"

# obtener datos del canal
STATUS=`amixer -c 0 get $CHANNEL | egrep -e "1?([1-9])?[0-9]%"`
echo $STATUS | egrep -o "\[on\]" > /dev/null

# si el canal esta en on se obtiene volumen
if [ $? -eq 0 ]; then
	# obtener volumen
	VOLUMEN=`echo $STATUS | egrep -o -e "100%" -e "1?([1-9])?[0-9]%"`
	# mostrar volumen
	echo ${VOLUMEN%\%}
else
	# si el canal esta mudo se muestra 0
	echo 0
fi

# salir del programa con exito
exit 0
