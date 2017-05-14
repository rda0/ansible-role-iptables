#!/bin/bash

. /etc/iptables/iptables.conf

echo -e "# Enable statefull rules (after that, only need to allow NEW conections)"
echo -e "-A INPUT   -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT"
echo -e "-A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT"
echo -e "-A OUTPUT  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT"
echo -e "# Drop invalid state packets"
echo -e "-A INPUT   -m conntrack --ctstate INVALID -j DROP"
echo -e "-A FORWARD -m conntrack --ctstate INVALID -j LOG ${LOG_OPTS} \"[ipt-f]invalid: \""
echo -e "-A FORWARD -m conntrack --ctstate INVALID -j DROP"
echo -e "-A OUTPUT  -m conntrack --ctstate INVALID -j LOG ${LOG_OPTS} \"[ipt-o]invalid: \""
echo -e "-A OUTPUT  -m conntrack --ctstate INVALID -j DROP"
