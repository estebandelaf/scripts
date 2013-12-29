#!/usr/bin/perl
#
# nic-update.pl
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
# Script para actualizar la dirección IP de los servidores de nombre en NIC.cl
#
# Se deben instalar los módulos de Perl usando:
#   cpan YAML Modern::Perl Net::IMAP::Simple DateTime::Format::Strptime \
#     Net::Nslookup
#
# Formato archivos de configuración:
#
#   - email.conf: son 5 líneas, donde en cada una va:
#
#       usuario del correo electrónico (incluyendo dominio)
#       contraseña del usuario del correo electrónico
#       servidor imap
#       puerto del servidor imap
#       carpeta dentro del servidor imap
#
#     Ejemplo para servidor IMAP Gmail:
#       nic@sasco.cl
#       XXXXXX
#       imap.gmail.com
#       993
#       INBOX
#
#   - nameservers.conf: un nombre de dns por línea (hostname, no la IP)
#
#   - domains.conf: un dominio por línea, sin .cl
#
# TODO:
#   - Chequear que el código enviado fuera correcto y se pueda modificar
#   - Mejorar cabeceras de formularios envíados (por ej Referer y UserAgent)
#   - Si no se puede establecer conexión con el servidor IMAP abortar script
#   - Chequear que los DNS que se quieran utilizar sean válidos (existan)
#

# módulos del sistema que se utilizarán
use Modern::Perl;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::Form;
use Net::IMAP::Simple;
use DateTime::Format::Strptime;
use Net::Nslookup;
use Encode qw(from_to);

# serán válidos correos que llegaron hace X horas
use constant EMAIL_RECEIVED_HOUR_AGO => 6;

# se reintentará obtener el código desde el correo X veces
use constant EMAIL_RETRY => 20;

# se esperará X segundos entre cada reintento para obtener el código
use constant EMAIL_WAIT => 5;

# obtener nombre de los archivos pasados como parámetros del script
my $email_file;
my $nameservers_file;
my $domains_file;
if ($#ARGV+1 == 3) {
	$email_file = $ARGV[0];
	$nameservers_file = $ARGV[1];
	$domains_file = $ARGV[2];
} else {
	print 'Modo de uso:',"\n";
	print "\t",$0,' <email file> <nameservers file | nameserver> ',
		'<domains file | domain>',"\n";
	exit 1;
}

# cargar archivos con las configuraciones de dns y dominios
my @nameservers = nameservers_load ($nameservers_file);
my @domains = domains_load ($domains_file);

# defininir configuración del correo
my @config = file_load ($email_file);
my $email = {
	user => $config[0],
	pass => $config[1],
	host => $config[2],
	port => $config[3],
	mbox => $config[4]
};

# procesar cada uno de los dominios
my $domain;
my $code;
foreach $domain (@domains) {
	print 'Configurando dominio ',$domain,'.cl',"\n";
	my $dt = DateTime->now();
	my $secs = $dt->epoch() - 3600*EMAIL_RECEIVED_HOUR_AGO;
	my $session_id = &nic_request_session_id ();
	my $stamp = &nic_request_stamp ($domain, $session_id);
	while ( &nic_request_auth_code ($domain, $stamp) ) {
		$session_id = &nic_request_session_id ();
		$stamp = &nic_request_stamp ($domain, $session_id);
	}
	for (my $i=0; $i<EMAIL_RETRY; $i++) {
		sleep (EMAIL_WAIT);
		$code = &nic_get_auth_code ($email, $domain, $secs);
		last if $code ne '';
	}
	if ($code eq '') {
		print "\t",'Código de autorización no obtenido, omitiendo',"\n";
		next;
	}
	print "\t",'Código de autorización: ',$code,"\n";
	while ( &nic_update( $domain, \@nameservers, $code, $session_id,
								$stamp ) ) {}
}

# Rutina para quitar espacios y saltos de línea al inicio y fin de un string
# @param string String que se desea limpiar
# @return String limpiado
sub trim {
	my $string = shift;
	chomp ($string);
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

# Rutina para cargar las líneas de un arcivo en un arreglo, se omiten líneas
# vacías o que inician por un # (esto es para comentarios)
# @param file Ruta del archivo que se desea cargar
# @return Arreglo con las líneas del archivo
sub file_load {
	# verificar que archivo exista
	my $file = shift;
	if (not -e $file) {
		print 'Archivo ',$file,' no encontrado!',"\n";
		exit 1;
	}
	# cargar líneas del archivo a un arreglo y retornar
	open FILE, $file or die $!;
	my @lines = grep { not $_ =~ /^#/ and not $_ =~ /^\n/ } <FILE>;
	close (FILE);
	chomp (@lines);
	return @lines;
}

# Rutina que carga los DNS desde un archivo, si el archivo no existe se asume
# que el nombre del archivo es el DNS que se quiere utilizar
# @param file Nombre del archivo con los dns
# @return Arreglo con los DNS
sub nameservers_load {
	my $file = shift;
	if (-e $file) {
		return file_load ($file);
	} else {
		my @aux = ($file);
		return @aux;
	}
}

# Rutina que carga los dominios desde un archivo, si el archivo no existe se
# asume que el nombre del archivo es el dominio que se quiere configurar
# @param file Nombre del archivo con los dominios
# @return Arreglo con los dominios
sub domains_load {
	return nameservers_load (shift);
}

# Rutina que solicita el identificador de la sesión
# @return Identificador de la sesión o vacío en caso de error
sub nic_request_session_id {
	my $ua = LWP::UserAgent->new;
	my $r = $ua->get('https://www.nic.cl/cgi-bin/ingresa-solicitud');
	if ($r->is_success) {
		my @forms = HTML::Form->parse ($r);
		return $forms[1]->find_input('sessionid')->value;
	}
	return '';
}

# Rutina para solicitar el stamp para el proceso
# @param dominio Dominio para el que se solicitará el stamp (sin .cl)
# @param session_id Identificador de la sesión
# @return Stamp o vacío en caso de error
sub nic_request_stamp {
	my $dominio = shift;
	my $session_id = shift;
	return '' if $session_id eq '';
	from_to ($dominio, 'utf-8', 'iso-8859-1');
	my $ua = LWP::UserAgent->new;
	my $r = $ua->request (
		POST 'https://www.nic.cl/cgi-bin/ingresa-solicitud',
		Content_Type => 'form-data',
		Content => [
			dominio => $dominio,
			sessionid => $session_id,
			opcode => 'M',
			pantalla => 1,
			i => 'E'
		]
	);
	if ($r->is_success) {
		my @forms = HTML::Form->parse ($r);
		return $forms[1]->find_input('stamp')->value;
	}
	return '';
}

# Rutina para solicitar el códdigo de autorización a NIC.cl
# @param dominio Dominio para el que se solicitará el código (sin .cl)
# @param stamp Marca utilizada para el proceso
# @return 0 en caso de éxito, 1 en caso de error
sub nic_request_auth_code {
	my $dominio = shift;
	my $stamp = shift;
	return 1 if $stamp eq '';
	from_to ($dominio, 'utf-8', 'iso-8859-1');
	my $ua = LWP::UserAgent->new;
	my $r = $ua->request (
		POST 'https://www.nic.cl/cgi-bin/dame-codigo',
		Content_Type => 'form-data',
		Content => [
			dominio => $dominio,
			stamp => $stamp,
			opcode => 'M'
		]
	);
	if ($r->is_success) {
		return 0;
	}
	return 1;
}

# Rutina para obtener el código de autorización desde el correo electrónico
# @param email Hash con la configuración del correo electrónico
# @param dominio Dominio para el que se desea buscar el código (sin .cl)
# @param secs Timestamp (epoch) desde cuando el correo será válido
# @return Código de autorización o vació en caso de error
sub nic_get_auth_code {
	# parámetros pasados
	my $email = shift;
	my $dominio = shift;
	my $secs = shift;
	# variable auxiliar para filtrados
	my @aux;
	# establecer conexión con el servidor de correo
	my $server = new Net::IMAP::Simple(
		$email->{host}.':'.$email->{port},
		use_ssl => ($email->{port} eq 993 ? 1 : 0)
	);
	$server->login($email->{user}, $email->{pass});
	# buscar correo con el código
	from_to ($dominio, 'utf-8', 'iso-8859-1');
	my $filter = '';
	$filter .= 'FROM "hostmaster@nic.cl" ';
	$filter .= 'SUBJECT "Codigo de autorizacion para '.$dominio.'.cl"';
	my @ids = $server->search ($filter);
	# si no se encontró un correo retornar vacío
	return '' if $#ids+1==0;
	# procesar correos buscando uno que se haya recibido de forma posterior
	# a secs (segundos desde cuando se debe considerar el correo)
	my $parser = DateTime::Format::Strptime->new(
		pattern => '%a, %d %b %Y %H:%M:%S %z',
		on_error => 'croak',
	);
	my @lines;
	my $id;
	my $found = 0;
	foreach $id (@ids) {
		@lines = $server->get ($id);
		@aux = grep { $_ =~ /^Date: / } @lines;
		my $date = substr ($aux[0], 6);
		my $email_dt = $parser->parse_datetime ($date);
		if ($email_dt->epoch() >= $secs) {
			$found = 1;
		}
	}
	return '' if not $found;
	# obtener código
	@aux = grep { $_ =~ /^  / } @lines;
	my $codigo = trim($aux[-2]);
	# terminar conexión con el servidor
	$server->quit();
	# entregar código encontrado
	return $codigo;
}

# Rutina que se conecta a NIC.cl para hacer la actualización de los DNS del
# dominio
# @param dominio Dominio que se desea actualizar (sin .cl)
# @param nameservers Referencia a arreglo con el listado de DNS
# @param code Código de autorización para modificar el dominio
# @param session_id Identificador de la sesión
# @param stamp Marca utilizada para el proceso
# @return 0 en caso de éxito, 1 en caso de error
sub nic_update {
	# parámetros pasados a la función
	my $dominio = shift;
	my ($nameservers) = shift;
	my $code = shift;
	my $session_id = shift;
	my $stamp = shift;
	# enviar código de autorización
	print "\t",'Enviando código de autorización',"\n";
	from_to ($dominio, 'utf-8', 'iso-8859-1');
	my $ua = LWP::UserAgent->new;
	my $r = $ua->request (
		POST 'https://www.nic.cl/cgi-bin/ingresa-solicitud',
		Content_Type => 'form-data',
		Content => [
			dominio => $dominio,
			sessionid => $session_id,
			stamp => $stamp,
			auth_code => $code,
			opcode => 'M',
			pantalla => 1,
			i => 'E',
			Continuar => 'Continuar'
		]
	);
	if ($r->is_success) {
		my @forms = HTML::Form->parse ($r);
		# actualizar DNSs
		my $i = 1;
		my $nameserver;
		foreach $nameserver (@$nameservers) {
			$nameserver = trim ($nameserver);
			my $ip = nslookup $nameserver;
			print "\t",'Agregando DNS ',$nameserver,' con IP ',
								$ip,"\n";
			$forms[1]->value('ns'.$i, $nameserver);
			$forms[1]->value('ipns'.$i, $ip);
			$i = $i + 1;
			last if $i==8; # máx 8 DNS permite NIC.cl
		}
		# si solo se configuró un primario se deja a NIC.cl como DNS
		# secundario
		if ($i==2) {
			print "\t",'Configurando NIC.cl como secundario',"\n";
			$forms[1]->find_input('nic-secundario')->value(1);
		} else {
			$forms[1]->find_input('nic-secundario')->value(0);
		}
		# limpiar los campos de DNSs que no se escribieron
		for (my $j=$i; $j<=8; $j++) {
			$forms[1]->value('ns'.$j, '');
			$forms[1]->value('ipns'.$j, '');
		}
		# enviar formulario con los cambios
		$r = $ua->request($forms[1]->click);
		if ($r->is_success) {
			return 0;
		}
		return 1;
	}
	return 1;
}
