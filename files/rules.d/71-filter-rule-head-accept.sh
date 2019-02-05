#!/bin/bash

echo -e "# Enable statefull rules (after that, only need to allow NEW conections)"
echo -e "-A INPUT   -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT"
echo -e "-A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT"
if [[ "${allow_o_any}" != "true" ]]; then
  echo -e "-A OUTPUT  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT"
fi

echo -e "# Allow local inbound loopback"
echo -e "-A INPUT   -i lo -j ACCEPT"
# echo -e "-4 -A INPUT   -i lo -s 127.0.0.0/8 -d 127.0.0.0/8 -j ACCEPT"
# echo -e "-6 -A INPUT   -i lo -s ::1/128 -d ::1/128 -j ACCEPT"

if [[ "${allow_o_any}" != "true" ]]; then
  echo -e "# Allow local outbound loopback"
  echo -e "-A OUTPUT  -o lo -j ACCEPT"
fi

echo -ne '\n'
