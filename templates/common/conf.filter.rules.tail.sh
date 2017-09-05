#!/bin/bash

. /etc/iptables/iptables.conf

echo -e "# All other connections are registered in syslog"
#echo -e "-A INPUT   -j LOG ${LOG_OPTS} \"[ipt-i]: \""
echo -e "-A OUTPUT  -j LOG ${LOG_OPTS} \"[ipt-o]: \""

for IF in ${IF_BR}; do
  echo -e "-A FORWARD -i ${IF} -o ${IF} -j ACCEPT"
done

echo -e "-A FORWARD -j LOG ${LOG_OPTS} \"[ipt-f]: \""
echo -e "# And finally rejected (trusted)"
echo -e "-A INPUT   -m set --match-set ${SET_TRU} src -j REJECT"
echo -e "-A OUTPUT  -m set --match-set ${SET_TRU} dst -j REJECT"
echo -e "-A FORWARD -m set --match-set ${SET_TRU} src -j REJECT"
echo -e "# Or finally dropped (internet)"
echo -e "-A INPUT   -j DROP"
echo -e "-A OUTPUT  -j DROP"
echo -e "-A FORWARD -j DROP"
