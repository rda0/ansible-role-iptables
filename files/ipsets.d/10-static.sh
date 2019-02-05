#!/bin/bash

# fill ipsets from config
for n in ${nets} prv prvcan; do
  #/sbin/ipset create "${n}" list:set
  echo -e "create ${n} list:set"
  for v in 4 6; do
    #[[ "${v}" == "4" ]] && /sbin/ipset create "${n}${v}" hash:net family inet
    #[[ "${v}" == "6" ]] && /sbin/ipset create "${n}${v}" hash:net family inet6
    [[ "${v}" == "4" ]] && echo -e "create ${n}${v} hash:net family inet"
    [[ "${v}" == "6" ]] && echo -e "create ${n}${v} hash:net family inet6"
    if [ -n "${net[${n}${v}]}" ]; then
      for i in ${net[${n}${v}]}; do
        #/sbin/ipset add "${n}${v}" "${i}"
        echo -e "add ${n}${v} ${i}"
      done
    fi
    #/sbin/ipset --exist add "${n}" "${n}${v}"
    echo -e "add ${n} ${n}${v}"
  done
done
