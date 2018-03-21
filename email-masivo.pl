#!/usr/bin/perl

#
# envio-masivo.pl
# Copyright (C) 2017 Esteban De La Fuente Rubio (esteban[at]delaf.cl)
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
# Aplicación para envios masivos de correos electrónicos
#
# Moso de uso:
#   $ ./email-masivo.pl plantilla_dir emails.txt [de]
#
# Errores son redireccionados a la salida de error, por lo cual se puede ejecutar así:
#   $ ./email-masivo.pl plantilla_dir emails.x [de] 2> email-masivo.log
#
# - El directorio plantilla_dir debe contener los siguientes archivos:
#    - asunto.txt Asunto del correo electrónico
#    - mensaje.html Cuerpo del correo electrónico en formato HTML
#    - mensaje.txt Cuerpo del correo electrónico en formato texto plano
#
#   Todos los archivos del directorio plantilla_dir deben estar codificados en UTF-8
#
# - El archivo emails.txt es un archivo con un correo por cada línea
#
# - El parámetro [de] es opcional, y puede ser el correo del remitente. En este caso
#   se usa este correo indicado en vez del usuario configurado.
#
# @author Esteban De La Fuente Rubio, DeLaF (esteban[at]delaf.cl)
# @date 2017-01-16
#

# definiciones para el envio de mensajes
use constant HOST => 'smtp.empresa.cl';
use constant PORT => 25;
use constant USER => 'remitente@empresa.cl';
use constant PASS => 'password';
use constant DEBUG => 0;

# bibliotecas a utilizar
use Modern::Perl;
use MIME::Lite::TT::HTML;
use Net::SMTP;

# verificar que se hayan pasado parametros
if ($#ARGV<1) {
	print "\n[error] modo de uso: email-masivo.pl plantilla_dir emails.txt [de]\n\n";
	exit;
}
my $plantilla_dir = $ARGV[0]; # directorio con la plantilla de los correos a enviar
my $emails_txt = $ARGV[1]; # archivo TXT con los correos
my $de = $#ARGV==2 ? $ARGV[2] : USER;

# plantilla del mensaje
open my $fd_asunto, '<', $plantilla_dir.'/asunto.txt';
my $asunto = <$fd_asunto>;
chomp $asunto;
close $fd_asunto;
my $mensaje_html = 'mensaje.html';
my $mensaje_txt = 'mensaje.txt';

# datos que seran utilizados en la plantilla, fijos para todas las notificaciones
my %params;

# contadores
my $n_emails = 0;
my $n_enviados = 0;

# procesar correos
open my $fd, '<', $emails_txt or die 'No fue posible abrir el archivo de correos';
while (<$fd>) {
    next if /^\s*$/;
    next if /^#/;
    chomp;
    my $a = $_;
    ++$n_emails;
    # definir mensaje que se enviará
    my %options;
    $options{INCLUDE_PATH} = $plantilla_dir;
    $params{email_a} = $a;
    my $msg = MIME::Lite::TT::HTML->new(
        From        =>  $de,
        To          =>  $a,
        Subject     =>  $asunto,
        Template    =>  {text => $mensaje_txt, html => $mensaje_html},
        TmplOptions =>  \%options,
        TmplParams  =>  \%params,
        Encoding    => 'quoted-printable',
        Charset     => [ 'utf8' => 'iso8859-1' ]
    );
    # enviar mensaje
    my $smtp = Net::SMTP->new(HOST, Port=>PORT, Hello => USER, Debug => DEBUG) or ( print STDERR "No ha sido posible realizar la conexión\n" and next );
    $smtp->auth(USER, PASS) or ( print STDERR "Error: ".$smtp->message() and next );
    $smtp->mail(USER) or ( print STDERR "Error: ".$smtp->message() and next );
    $smtp->to($a) or ( print STDERR "Error: ".$smtp->message() and next );
    $smtp->data() or ( print STDERR "Error: ".$smtp->message() and next );
    $smtp->datasend($msg->as_string) or ( print STDERR "Error: ".$smtp->message() and next );
    $smtp->dataend() or ( print STDERR "Error: ".$smtp->message() and next );
    $smtp->quit() or ( print STDERR "Error: ".$smtp->message() and next );
    ++$n_enviados;
    # mostrar estado de avance
    print "Se enviaron $n_enviados de $n_emails correos\n";
}
close $fd;
