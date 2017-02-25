#!/bin/bash

#
# playlist_create.sh
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

function playlist_create {
    MUSIC_DIR=$1
    FILE_M3U=$2
    IFS_ORI=$IFS
    IFS=$'\n'
    for f in `find $MUSIC_DIR | grep mp3$`; do
        echo $f >> $FILE_M3U.m3u
    done
    IFS=$IFS_ORI
}

playlist_create $1 $2
