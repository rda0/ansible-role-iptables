#!/bin/bash

. /etc/iptables/iptables.conf

for IF in ${IF_EXT}; do
  echo -e "# Anything coming from the Internet should have a real Internet address"
  echo -e "-N i-priv"
  echo -e "-N f-priv"
  echo -e "-A INPUT   -m set --match-set private src -i ${IF} -j i-priv"
  echo -e "-A FORWARD -m set --match-set private src -i ${IF} -j f-priv"
  echo -e "# Everything in the private address range gets dropped, except our allowed networks"
  echo -e "-A i-priv  -m set ! --match-set private-except src -j LOG ${LOG_OPTS} \"[ipt-i]${IF}-s-priv: \""
  echo -e "-A i-priv  -m set ! --match-set private-except src -j DROP"
  echo -e "-A f-priv  -m set ! --match-set private-except src -j LOG ${LOG_OPTS} \"[ipt-f]${IF}-s-priv: \""
  echo -e "-A f-priv  -m set ! --match-set private-except src -j DROP"
done
