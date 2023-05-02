#!/bin/bash

echo -e "# Close all net chains"
for n in ${nets} any; do
  declare -A ch
  for c in i o f; do
    ch[${c}]=1
    [[ ! -n "${port[${c}_tcp_${n}]}" ]] && [[ ! -n "${port[${c}_udp_${n}]}" ]] && ch[${c}]=""
  done
  [[ -n "${ch[i]}" ]] &&                                     echo -e "-A i-net-${n} -j RETURN"
  [[ -n "${ch[o]}" ]] && [[ "${allow_o_any}" != "true" ]] && echo -e "-A o-net-${n} -j RETURN"
  [[ -n "${ch[f]}" ]] &&                                     echo -e "-A f-net-${n} -j RETURN"
done
