#!/bin/sh
#
# Script para generar firewall utilizando IPTables
# @author Esteban De La Fuente, DeLaF (esteban[at]delaf.cl)
#

### VARIABLES
LAN="192.168.1.0/24"

### INICIA SCRIPT
echo -n "Iniciando las reglas del Firewall... "

### IPTABLES 

## REGLAS GENERALES

# Flush (limpieza) de las reglas
iptables -F
iptables -X
iptables -Z
iptables -t nat -F

# Políticas por defecto para las tablas FILTER y NAT respectivamente
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -t nat -P PREROUTING ACCEPT
iptables -t nat -P POSTROUTING ACCEPT
iptables -t nat -P OUTPUT ACCEPT

# Paquetes entrando al equipo
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state NEW -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -m state --state NEW -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -m state --state NEW -p udp --dport 53 -j ACCEPT
iptables -A INPUT -m state --state NEW -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -m state --state NEW -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -m state --state NEW -p tcp --dport 389 --source $LAN -j ACCEPT # ldap
iptables -A INPUT -m state --state NEW -p tcp --dport 636 --source $LAN -j ACCEPT # ssl/ldap
iptables -A INPUT -j REJECT --reject-with icmp-host-prohibited

### FIN

echo "[OK]"
echo "Verificar con iptables -L -n"
