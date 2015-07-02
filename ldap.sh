#!/bin/bash

#
# ldap.sh
# Copyright (C) 2012 Esteban De La Fuente Rubio (esteban[at]delaf.cl)
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
# Script para administrar directorio OpenLDAP
#

# Configuración
DOMAIN=""
ADMIN="administrador"
PASS=""
UIDFROM=2000
GIDFROM=2000
QUOTA_GROUP="alumnos"
QUOTA_BYTES=102400
QUOTA_INODES=10000
PASSWORD_EXP="(?=^.{8,}$)(?=^[^\s]*$)(?=.*\d)(?=.*[A-Z])(?=.*[a-z])"
PASSWORD_MSG="al menos 8 caracteres que tengan 1 mayúscula, 1 minúscula y 1 número"
PASSWORD_NOT=(
Password1
Password123
Clave123
Qwerty123
)

# Obtener DC a partir de un nombre de dominio
function getDC {
	OIFS=$IFS
	IFS='.'
	AUX=''
	for parte in $1; do
		if [ "$AUX" != "" ]; then
			AUX="$AUX,"
		fi
		AUX="${AUX}dc=$parte"
	done
	IFS=$OIFS
	echo $AUX
}

# Fijar DC
DC=`getDC $DOMAIN`

# Fijar argumentos que se pasarán
if [ "$PASS" = "" ]; then
	ARGS="-v -D cn=$ADMIN,$DC -W"
else
	ARGS="-v -D cn=$ADMIN,$DC -w $PASS"
fi

# Obtener el árbol completo de directorio
function getall {
	ldapsearch -x -b "$DC" '(objectclass=*)' | less
}

# Inicializar el directorio (crea la raíz)
function initialize {
	echo -n "Organización: "; read ORGANIZATION
	ldapadd $ARGS << EOF
	dn: $DC
	objectClass: top
	objectClass: dcObject
	objectClass: organization
	o: $ORGANIZATION
EOF
}

# Agregar una unidad organizacional
function ouadd {
	ldapadd $ARGS << EOF
	dn: ou=$1,$DC
	ou: $1
	objectclass: organizationalUnit
EOF
}

# Agregar un grupo (se asume ou=groups)
function groupadd {
	# obtener siguiente id
	GRUPO_ID=`nextGID`
	# agregar grupo
	ldapadd $ARGS << EOF
	dn: cn=$1,ou=groups,$DC
	cn: $1
	objectClass: top
	objectClass: posixGroup
	gidNumber: $GRUPO_ID
EOF
}

# Eliminar un grupo
function groupdel {
	ldapdelete $ARGS "cn=$1,ou=groups,$DC"
}

# Agregar un usuario
function useradd {
	# solicitar usuario (si existe se pide otro)
	echo -n "Usuario: "; read USUARIO
	while [ "`userexist $USUARIO`" = "1" ]; do
		echo -n "Usuario $USUARIO ya existe, ingrese nuevo: "; read USUARIO
	done
	# preguntar otros campos del usuario
	echo -n "Nombre: "; read NOMBRE
	echo -n "Apellido: "; read APELLIDO
	echo -n "Grupo principal (`groupList`): "; read GRUPO
	GRUPO_ID=`groupID $GRUPO`
	USUARIO_ID=`nextUID`
	# fechas
	SECS=`date +%s`
        HOY=`echo $(($SECS/(3600*24)))`
        UNANIOMAS=$(($HOY+365))
	# agregar a ldap
	ldapadd $ARGS << EOF
	dn: uid=$USUARIO,ou=people,$DC
	cn: $NOMBRE $APELLIDO
	givenName: $NOMBRE
	sn: $APELLIDO
	uid: $USUARIO
	uidNumber: $USUARIO_ID
	gidNumber: $GRUPO_ID
	homeDirectory: /home/$USUARIO
	mail: $USUARIO@$DOMAIN
	objectClass: top
	objectClass: posixAccount
	objectClass: shadowAccount
	objectClass: inetOrgPerson
	objectClass: organizationalPerson
	objectClass: person
	loginShell: /bin/bash
	userPassword: {CRYPT}*
	shadowLastChange: $HOY
	shadowExpire: $UNANIOMAS
EOF
	# asignar clave al usuario
	passwd $USUARIO
	# Crear home del usuario
	mkdir -p /home/$USUARIO
	cp /etc/skel/.* /home/$USUARIO 2> /dev/null
	chown $USUARIO: /home/$USUARIO -R
	chmod 701 /home/$USUARIO
	# asignar quota al usuario si es del grupo donde
	# se deben aplicar quotas
	if [ "$GRUPO" = "$QUOTA_GROUP" ]; then
		userquota $USUARIO	
	fi
}

# Eliminar un usuario
function userdel {
	ldapdelete $ARGS "uid=$1,ou=people,$DC"
}

# Generar clave
function user_genpasswd {
	local l=$1
       	[ "$l" == "" ] && l=20
      	tr -dc A-Za-z0-9_ < /dev/urandom | head -c ${l} | xargs 
}

# Cambiar clave a un usuario
function passwd {
	# obtener nombre completo del usuario
	FULLNAME=`ldapsearch -x -b "uid=$1,ou=people,$DC" '(objectclass=*)' | grep ^cn:`
	FULLNAME=${FULLNAME:4}
	# si el usuario no existe error
	if [ "$FULLNAME" = "" ]; then
		echo "[error] nombre de usuario $1 no existe"
		exit 1
	fi
	# mostrar nombre completo del usuario y confirmar que se cambiará clave
	echo -n "¿Cambiar clave al usuario $FULLNAME ($1)? [n]: "; read OK
	if [ "$OK" = "y" ]; then
		# iterar hasta tener una clave válida
		while true; do
			# solicitar clave hasta que haya una válida
			passwd_get
			# verificar clave (si no es valida se vuelve a pedir)
			passwd_check $PASSWORD
			# si todo esta ok se rompe el ciclo
			if [ $PASSWORD_OK -eq 0 ]; then
				break
			fi
		done
		# actualizar fecha de cambio de clave y expiracion de la cuenta
		SECS=`date +%s`
	        HOY=`echo $(($SECS/(3600*24)))`
        	UNANIOMAS=$(($HOY+365))
		ldapmodify $ARGS << EOF
		dn: uid=$1,ou=people,$DC
		changetype: modify
		replace: shadowLastChange
		shadowLastChange: $HOY

		dn: uid=$1,ou=people,$DC
		changetype: modify
		replace: shadowExpire
		shadowExpire: $UNANIOMAS
EOF
		# Hacer el cambio de clave (FIXME: no usar -s!!)
		ldappasswd $ARGS "uid=$1,ou=people,$DC" -s "$PASSWORD"
	fi
}

# Solicitar clave al usuario (2 veces)
function passwd_get {
	echo -n "Ingresar clave ($PASSWORD_MSG): "
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

# Verificar que la clave cumpla condiciones mínimas
function passwd_check {
	# copiar password
	PASSWORD=$1
	# se asume que todo esta ok
	PASSWORD_OK=0
	# si la clave es 1 es porque eran diferentes
	if [ "$PASSWORD" = "1" ]; then
		echo "[error] las claves son diferentes"
		PASSWORD_OK=1
	else
		# verificar expresion regular
		export PASSWORD_EXP
		if [ `perl -e 'exit $ARGV[0] =~ $ENV{"PASSWORD_EXP"} ? 0 : 1' "$PASSWORD"; echo $?` -eq 0 ]; then
			echo "[error] la clave no respeta lo mínimo requerido ($PASSWORD_MSG)"
			PASSWORD_OK=1
		else
			# verificar que no este dentro de las claves no permitidas
			for i in `seq 0 $((${#PASSWORD_NOT[@]}-1))`; do
				if [ "$PASSWORD" = "${PASSWORD_NOT[$i]}" ]; then
					echo "[error] la clave no está permitida (muy simple)"
					PASSWORD_OK=1
					break
				fi
			done
		fi
	fi
}

# Cambiar UID de un usuario
function userid {
	# modificar UID
	ldapmodify $ARGS << EOF
	dn: uid=$1,ou=people,$DC
	changetype: modify
	replace: uidNumber
	uidNumber: $2
EOF
	# reasignar permisos
	chown $1: /home/$1 -R
}

# Fijar quota para un usuario
function userquota {
	# definir quotas duras
	QUOTA_BYTES_HARD=$(echo "$QUOTA_BYTES + $QUOTA_BYTES * 0.1" | bc | sed 's/[.].*//')
	QUOTA_INODES_HARD=$(echo "$QUOTA_INODES + $QUOTA_INODES * 0.1" | bc | sed 's/[.].*//')
	# asignar quotas al usuario
	setquota -u $1 $QUOTA_BYTES $QUOTA_BYTES_HARD $QUOTA_INODES $QUOTA_INODES_HARD --all
}

# Fijar quotas para todos los usuarios
function usersquota {
	# ontener usuarios (FIXME: sacar de ldap)
	USERS=`ls -l /home | awk -v grupo=$QUOTA_GROUP '{if($4==grupo) print $3}'`
	for USER in $USERS; do	
		userquota $USER
	done
}

# Verifica si un usuario existe
function userexist {
	ldapsearch -x -b "ou=people,$DC" '(objectclass=*)' | grep ^uid: | awk -v usuario=$1 '{if($2==usuario) print "1"}'
}

# Obtener próximo UID libre
function nextUID {
	LASTUID=`ldapsearch -x -b "ou=people,$DC" '(objectclass=*)' | grep uidNumber | awk '{print $2}' | sort -r | head -1`
	if [ "$LASTUID" = "" ]; then
		echo $UIDFROM
	else
		echo $(($LASTUID+1))
	fi
}

# Obtener próximo GID libre
function nextGID {
	LASTGID=`ldapsearch -x -b "ou=groups,$DC" '(objectclass=*)' | grep gidNumber | awk '{print $2}' | sort -r | head -1`
	if [ "$LASTGID" = "" ]; then
		echo $GIDFROM
	else
		echo $(($LASTGID+1))
	fi
}

# Obtener GID a partir del nombre del grupo
function groupID {
	ldapsearch -x -b "cn=$1,ou=groups,$DC" '(objectclass=*)' | grep gidNumber | awk '{printf $2}'
}

# Obtener listado de grupos
function groupList {
	ldapsearch -x -b "ou=groups,$DC" '(objectclass=*)' | grep cn: | sort | awk '{printf $2" "}'
}

# Mostrar mensaje de ayuda
function help {
	echo "Modo de ejecución: $0 {opción}"
	exit 1
}

# Determinar que ejecutar según se haya indicado por $1
case "$1" in
	getall) getall;;
	initialize) initialize;;
	ouadd) ouadd $2;;
	groupadd) groupadd $2;;
	groupdel) groupdel $2;;
	useradd) useradd;;
	userdel) userdel $2;;
	passwd) passwd $2;;
	userid) userid $2 $3;;
	usersquota) usersquota;;
	*) help;;
esac

