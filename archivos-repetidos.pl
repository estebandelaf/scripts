#!/usr/bin/perl

#
# archivos-repetidos.pl
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
# Programa que buscará archivos repetidos bajo un directorio
# Un archivo se considerará repetido si el nombre y el tamaño son el
# mismo.
#
# @author Esteban De La Fuente Rubio, DeLaF (esteban[at]delaf.cl)
# @version 2013-05-03
#

# Bibliotecas a utilizar
use Modern::Perl;
use File::Basename;

# Clase para guardar archivos existentes
package Archivo;

sub new {  
	my $class = shift;  
	my $self = {};

	# Atributos
	$self->{name} = "";
	$self->{size} = -1;
	$self->{'locations'} = [];

	bless $self, $class; 
	return $self; 
}

# Parte principal del programa
package main;

# Verificar que se haya pasado el directorio
if ($#ARGV != 0) {
    print "Debes indicar el directorio como parámetro\n";
    exit;
}

# Guardar salida de find, obtendrá todos los archivos del directorio y subdirectorios
my @find = `find $ARGV[0]`;

# Variable para guardar la info de los archivos
my @files;

# Procesar cada una de las entradas de find
my $location;
foreach $location (@find) {
	# Quitar salto de línea del final del nombre de archivo
	chomp($location);
	# Procesar solo si es un archivo
	if(-f $location) {
		# Obtener nombre y tamaño
		my $name = basename($location);
		my $size = -s $location;
		# Buscar archivo con mismo nombre y tamaño
		my $f;
		my $existia = 0;
		foreach $f (@files) {
			# Si el nombre y el tamaño son el mismo se agrega la ubicacion como archivo repetido
			if ($f->{name} eq $name && $f->{size}==$size) {
				# Agregar ubicación
				push(@{$f->{locations}}, $location);
				# Marcar como que ya existia
				$existia = 1;
			}
		}
		# Si el archivo (nombre/tamaño) no existia se agrega
		if(!$existia) {
			my $file = Archivo->new();
			$file->{name} = $name;
			$file->{size} = $size;
			push(@{$file->{locations}}, $location);
			push(@files, $file);
		}
	}
}

# Recorrer archivos encontrados y mostrar estadísticas
my $file;
foreach $file (@files) {
	if(scalar @{$file->{locations}} > 1) {
		print "Archivo ", $file->{name}, " de tamaño ", $file->{size}, " repetido ", scalar @{$file->{locations}}, " veces en:\n";
		my $location;
		foreach $location (@{$file->{locations}}) {
			print " $location\n";
		}
	}
}
