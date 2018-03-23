#!/bin/bash

# Cambiador de pantallas :-)
#
# Permite rotar entre configuraciones de la pantalla. Si el cable VGA
# esta desconectado se deshabilita el VGA si esta conectado rota
# entre clonar la pantalla a la resolucion indicada o colocar una
# pantalla al lado de la otra a la resolucion optima de cada pantalla
# y la posicion indicada
#
# Instalar para usar en Fluxbox presionando Ctrl_L+Alt_L+space:
# echo Control Mod1 space :Exec screen.sh  >> ~/.fluxbox/keys
# Copiar dentro de la carpeta ~/bin, asumiendo que esta está dentro
# del PATH, sino copiar donde corresponda
#
# @author Esteban De La Fuente, DeLaF (esteban@delaf.cl)
# @license GPLv3

# variables
INT="LVDS"
EXT="DFP1"
RESOLUTION="1360x768"
POSITION="right"

NEXT="/tmp/screen.next"

CONNECTED=`xrandr | grep "$EXT connected"`
if [ "$CONNECTED" ]; then
	OPTION=`cat $NEXT 2> /dev/null || echo -n 0`
	case "$OPTION" in
		0|1)
			xrandr --output $INT --mode $RESOLUTION --output $EXT --mode $RESOLUTION --same-as $INT
			echo -n 2 > $NEXT
		;;
		2)
			[ $# -eq 1 ] && POSITION=$1
			xrandr --output $INT --auto --output $EXT --auto --$POSITION-of $INT
			echo -n 1 > $NEXT
		;;
	esac
else
	xrandr --output $INT --auto --output $EXT --off
	echo -n 1 > $NEXT
fi
