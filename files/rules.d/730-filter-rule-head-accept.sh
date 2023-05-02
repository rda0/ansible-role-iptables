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

[[ "${if_accept}" != "" ]] && echo -e "# Allow any inbound traffic from specific interfaces"
for i in ${if_accept}; do
  echo -e "-A INPUT   -i ${i} -j ACCEPT"
done

if [[ "${allow_o_any}" != "true" ]]; then
  echo -e "# Allow local outbound loopback"
  echo -e "-A OUTPUT  -o lo -j ACCEPT"

  [[ "${if_accept}" != "" ]] && echo -e "# Allow any outbound traffic to specific interfaces"
  for i in ${if_accept}; do
    echo -e "-A OUTPUT  -o ${i} -j ACCEPT"
  done
fi

[[ "${if_physdev_in}" != "" ]] && echo -e "# Allow any forwarded traffic from physical interfaces"
for i in ${if_physdev_in}; do
  echo -e "-A FORWARD -m physdev --physdev-in ${i} -j ACCEPT"
done

echo -ne '\n'
