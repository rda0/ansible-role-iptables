#!/bin/bash

. /etc/iptables/iptables.conf

echo -e "## Allow icmp (ping)"
echo -e "# Allow inbound ping from trusted networks"
if [ "${ALLOW_PING_INET}" == "true" ]; then
  echo -e "-A INPUT  -p icmp --icmp-type echo-request -j ACCEPT"
else
  echo -e "-A INPUT  -p icmp --icmp-type echo-request -m set --match-set trusted src -j ACCEPT"
fi
echo -e "# Allow outbound ping to internet"
echo -e "-A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT"
