#!/usr/bin/perl -w
$passwd = $ARGV[0];
$salt = "\$1\$".$ARGV[1]."\$";
print(crypt($passwd, $salt)."\n");
