#!/bin/bash

for p in tcp udp; do
  if [ -n "${nat[4_f_${p}]}" ]; then
    for f in ${nat[4_f_${p}]}; do
      i=""
      port=""
      dst_ip=""
      dst_port=""
      i="$(echo ${f} | cut -d'_' -f1)"
      port="$(echo ${f} | cut -d'_' -f2)"
      dst_ip="$(echo ${f} | cut -d'_' -f3)"
      dst_port="$(echo ${f} | cut -d'_' -f4)"
      echo -e "-4 -A PREROUTING -i ${i} -p ${p} -m ${p} --dport ${port} -j DNAT --to-destination ${dst_ip}:${dst_port}"
      [[ "${DEBUG}" > 1 ]] && >&2 echo -e "-4 -A PREROUTING -i ${i} -p ${p} -m ${p} --dport ${port} -j DNAT --to-destination ${dst_ip}:${dst_port}"
    done
  fi
done

echo -ne '\nCOMMIT\n\n'
