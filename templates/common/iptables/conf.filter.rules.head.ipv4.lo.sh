#!/bin/bash

. /etc/iptables/iptables.conf

# Allow local inbound loopback
echo -e "-A INPUT   -i lo -s 127.0.0.0/8 -d 127.0.0.0/8 -j ACCEPT"
echo -e "-A INPUT ! -i lo -d 127.0.0.0/8 -j LOG ${LOG_OPTS} \"[ipt-i]notlo-d-lo: \""
echo -e "-A INPUT ! -i lo -d 127.0.0.0/8 -j DROP"
echo -e "-A INPUT ! -i lo -s 127.0.0.0/8 -j LOG ${LOG_OPTS} \"[ipt-i]notlo-s-lo: \""
echo -e "-A INPUT ! -i lo -s 127.0.0.0/8 -j DROP"
