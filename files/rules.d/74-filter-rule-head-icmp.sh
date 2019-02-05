#!/bin/bash

echo -e "## Allow icmp"

echo -e "# Allow all IPv4 ICMP, should not hurt much"
echo -e "-4 -A INPUT  -p icmp -j ACCEPT"
if [[ "${allow_o_any}" != "true" ]]; then
  echo -e "-4 -A OUTPUT -p icmp -j ACCEPT"
fi

echo -e "# Almost all IPv6 ICMP traffic is required for proper network function, thus allowed"
echo -e "# Check RFC4890: https://tools.ietf.org/html/rfc4890"
echo -e "-6 -A INPUT  -p ipv6-icmp -j ACCEPT"
if [[ "${allow_o_any}" != "true" ]]; then
  echo -e "-6 -A OUTPUT -p ipv6-icmp -j ACCEPT"
fi

echo -ne '\n'
