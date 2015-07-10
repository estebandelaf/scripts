#!/bin/bash
#
# Script para administrar una base de datos PostgreSQL
# @author Esteban De La Fuente Rubio, DeLaF (esteban[at]delaf.cl)
#

function useradd {
	su - postgres -c "createuser $1"
	passwd $1
}

function userdel {
	dbdel $1
	su - postgres -c "dropuser $1"
}

function passwd {
	echo -n "¿Cambiar clave al usuario $1? [n]: "; read OK
	if [ "$OK" = "y" ]; then
		# iterar hasta tener una clave válida
		while true; do
			# solicitar clave hasta que haya una válida
			passwd_get
			# si todo esta ok se rompe el ciclo
			if [ "$PASSWORD" != "1" ]; then
				break
			fi
		done
		# cambiar la clave
		su - postgres -c "psql -d template1" << EOF
			ALTER USER $1 WITH PASSWORD '$PASSWORD';
EOF
	fi
}

# Solicitar clave al usuario (2 veces)
function passwd_get {
	echo -n "Ingresar clave: "
	stty -echo; read PASSWORD1; stty echo; echo ""
	echo -n "Repetir clave: "
	stty -echo; read PASSWORD2; stty echo; echo ""
	# si las claves son diferentes se piden denuevo
	if [ "$PASSWORD1" != "$PASSWORD2" ]; then
		PASSWORD=1
	else
		PASSWORD=$PASSWORD1
	fi
}

function dbadd {
	su - postgres -c "createdb --owner=$1 $2"
}

function dbdel {
	su - postgres -c "dropdb $1"
}

function help {
	echo "Modo de ejecución: $0 {opción}"
	echo "Opciones: useradd USUARIO"
	echo "          userdel USUARIO"
	echo "          passwd USUARIO"
	echo "          dbadd USUARIO BASE_DE_DATOS"
	echo "          dbdel BASE_DE_DATOS"
	exit 1
}

# Determinar que ejecutar según se haya indicado por $1
case "$1" in
	useradd) useradd $2;;
	userdel) userdel $2;;
	passwd) passwd $2;;
	dbadd) dbadd $2 $3;;
	dbdel) dbdel $2;;
	*) help;;
esac
