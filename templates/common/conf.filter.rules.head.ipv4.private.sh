#!/bin/bash

. /etc/iptables/iptables.conf

echo -e "-N i-priv"
echo -e "-N f-priv"

echo -e "# Anything coming from the Internet should have a real Internet address"

for IF in ${IF_EXT}; do
  echo -e "-A INPUT   -m set --match-set private src -i ${IF} -j i-priv"
  echo -e "-A FORWARD -m set --match-set private src -i ${IF} -j f-priv"
done

for IF in ${IF_BR_EXT}; do
  echo -e "-A INPUT   -m set --match-set private src -m physdev --physdev-in ${IF} -j i-priv"
  echo -e "-A FORWARD -m set --match-set private src -m physdev --physdev-in ${IF} -j f-priv"
done

echo -e "# Everything in the private address range gets dropped, except our allowed networks"

echo -e "-A i-priv  -m set ! --match-set private-except src -j LOG ${LOG_OPTS} \"[ipt-i]any-s-priv: \""
echo -e "-A i-priv  -m set ! --match-set private-except src -j DROP"
echo -e "-A f-priv  -m set ! --match-set private-except src -j LOG ${LOG_OPTS} \"[ipt-f]any-s-priv: \""
echo -e "-A f-priv  -m set ! --match-set private-except src -j DROP"
