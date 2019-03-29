#!/bin/bash

for n in ${nets} any; do
  declare -A ch
  for c in i o f; do
    ch[${c}]=1
    [[ ! -n "${port[${c}_tcp_${n}]}" ]] && [[ ! -n "${port[${c}_udp_${n}]}" ]] && ch[${c}]=""
  done
  echo -e "# Define chains for network ${n} if required (open ports)"
  [[ -n "${ch[i]}" ]] &&                                     echo -e "-N i-net-${n}"
  [[ -n "${ch[o]}" ]] && [[ "${allow_o_any}" != "true" ]] && echo -e "-N o-net-${n}"
  [[ -n "${ch[f]}" ]] &&                                     echo -e "-N f-net-${n}"
  for v in 4 6; do
    if [[ "${n}" == "any" ]]; then
      [[ -n "${ch[i]}" ]] &&                                     echo -e "-${v} -A INPUT   -j i-net-${n}"
      [[ -n "${ch[o]}" ]] && [[ "${allow_o_any}" != "true" ]] && echo -e "-${v} -A OUTPUT  -j o-net-${n}"
      [[ -n "${ch[f]}" ]] && [[ "${v}" == "4" ]] &&              echo -e "-${v} -A FORWARD -j f-net-${n}"
    elif [ -n "${net[${n}${v}]}" ]; then
      [[ -n "${ch[i]}" ]] &&                                     echo -e "-${v} -A INPUT   -m set --match-set ${n}${v} src -j i-net-${n}"
      [[ -n "${ch[o]}" ]] && [[ "${allow_o_any}" != "true" ]] && echo -e "-${v} -A OUTPUT  -m set --match-set ${n}${v} dst -j o-net-${n}"
      [[ -n "${ch[f]}" ]] && [[ "${v}" == "4" ]] &&              echo -e "-${v} -A FORWARD -m set --match-set ${n}${v} src -j f-net-${n}"
    fi
  done
  for p in tcp udp; do
    for c in i o; do
      if [ -n "${port[${c}_${p}_${n}]}" ]; then
        for port in ${port[${c}_${p}_${n}]}; do
          if [[ "${c}" == "i" ]]; then
            echo -e "-A ${c}-net-${n} -p ${p} -m ${p} --dport ${port} -j ACCEPT"
            [[ "${DEBUG}" > 1 ]] && >&2 echo -e "-A ${c}-net-${n} -p ${p} -m ${p} --dport ${port} -j ACCEPT"
          elif [[ "${c}" == "o" ]] && [[ "${allow_o_any}" != "true" ]]; then
            echo -e "-A ${c}-net-${n} -p ${p} -m ${p} --dport ${port} -j ACCEPT"
            [[ "${DEBUG}" > 1 ]] && >&2 echo -e "-A ${c}-net-${n} -p ${p} -m ${p} --dport ${port} -j ACCEPT"
          elif [[ "${c}" == "f" ]]; then
            i=""
            dst_ip=""
            dst_port=""
            i="$(echo ${port} | cut -d'_' -f1)"
            dst_ip="$(echo ${port} | cut -d'_' -f2)"
            dst_port="$(echo ${port} | cut -d'_' -f3)"
            echo -e "-4 -A ${c}-net-${n} -i ${i} -p ${p} -m ${p} -d ${dst_ip} --dport ${dst_port} -j ACCEPT"
            [[ "${DEBUG}" > 1 ]] && >&2 echo -e "-4 -A ${c}-net-${n} -i ${i} -p ${p} -m ${p} -d ${dst_ip} --dport ${dst_port} -j ACCEPT"
          fi
        done
      fi
    done
  done
  [[ -n "${ch[i]}" ]] &&                                     echo -e "-A i-net-${n} -j RETURN"
  [[ -n "${ch[o]}" ]] && [[ "${allow_o_any}" != "true" ]] && echo -e "-A o-net-${n} -j RETURN"
  [[ -n "${ch[f]}" ]] &&                                     echo -e "-A f-net-${n} -j RETURN"
done

echo -ne '\n'
