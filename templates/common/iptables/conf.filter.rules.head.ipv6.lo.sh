#!/bin/bash

. /etc/iptables/iptables.conf

echo -e "# Allow local inbound loopback"
echo -e "-A INPUT   -i lo -s ::1/128 -d ::1/128 -j ACCEPT"
echo -e "-A INPUT ! -i lo -d ::1/128 -j LOG ${LOG_OPTS} \"[ipt-i]notlo-d-lo: \""
echo -e "-A INPUT ! -i lo -d ::1/128 -j DROP"
echo -e "-A INPUT ! -i lo -s ::1/128 -j LOG ${LOG_OPTS} \"[ipt-i]notlo-s-lo: \""
echo -e "-A INPUT ! -i lo -s ::1/128 -j DROP"
