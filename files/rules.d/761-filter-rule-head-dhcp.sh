#!/bin/bash

if [[ "${allow_dhcpv6}" == "true" ]]; then
  echo -e "# Allow outbound multicast DHCPv6 and inbound DHCPv6 with link-local destination"
  echo -e "-6 -A OUTPUT -m conntrack --ctstate NEW -m udp -p udp --dport 547 -d ff02::1:2 -j ACCEPT"
  echo -e "-6 -A OUTPUT -m conntrack --ctstate NEW -m udp -p udp --dport 547 -d ff05::1:3 -j ACCEPT"
  echo -e "-6 -A INPUT -m conntrack --ctstate NEW -m udp -p udp --dport 546 -d fe80::/64 -j ACCEPT"
  echo -ne '\n'
fi
