#!/bin/bash

# dispositivo que se usará como candado
DEVICE="/dev/disk/by-uuid/D935-DC2D"

# definir verbose
if [ "$1" = "-v" ]; then
	VERBOSE=1
else
	VERBOSE=0
fi

# función para mostrar lo que está pasando
function log {
	if [ $VERBOSE -ge 1 ]; then
		echo $1
	fi
}

# función para determinar estado actual del screensaver
function screensaver_isOn {
	dbus-send --print-reply --session --dest=org.freedesktop.ScreenSaver \
		/ScreenSaver org.freedesktop.ScreenSaver.GetActive \
		| grep boolean \
		| awk '{ if ($2=="true") print "1"; else print "0" }'
}

# función que inicia el screensaver
function screensaver_on {
	dbus-send --session --dest=org.freedesktop.ScreenSaver \
		--type=method_call /ScreenSaver \
		org.freedesktop.ScreenSaver.SetActive boolean:true
}

# función que termina el screensaver
function screensaver_off {
	dbus-send --session --dest=org.freedesktop.ScreenSaver \
		--type=method_call /ScreenSaver \
		org.freedesktop.ScreenSaver.SetActive boolean:false
}

# se marca estado inicial del dispositivo
if [ -L "$DEVICE" ]; then
	log "Dispositivo inicialmente conectado"
	CONNECTED=1
else
	log "Dispositivo inicialmente desconectado"
	CONNECTED=0
fi

# ciclo infinito para determinar que se debe hacer
LOCKED=`screensaver_isOn`
while true; do
	if [ $CONNECTED -eq 0 ]; then
		if [ -L "$DEVICE" ]; then
			log "Se ha conectado el dispositivo"
			CONNECTED=1
		fi
	else
		if [ ! -L "$DEVICE" -a $LOCKED -eq 0 ]; then
			log "Bloqueando pantalla"
			screensaver_on
			LOCKED=1
		fi
		if [ -L "$DEVICE" -a $LOCKED -eq 1 ]; then
			log "Desbloqueando pantalla"
			screensaver_off
			LOCKED=0
		fi
	fi
	sleep 1
done
