#!/bin/bash

# dynamic blocking (ban lists filled by rate limiter)
for p in ${lim[ports]}; do
  for n in ${lim[nets]}; do
    #/sbin/ipset --exist create ban-${p}-${n}4   hash:ip  family inet  timeout ${lim[${p}_${n}_time]}
    #/sbin/ipset --exist create ban-${p}-${n}6   hash:ip  family inet6 timeout ${lim[${p}_${n}_time]}
    #/sbin/ipset --exist create ban-${p}-${n}    list:set
    #/sbin/ipset --exist add    ban-${p}-${n}    ban-${p}-${n}4
    #/sbin/ipset --exist add    ban-${p}-${n}    ban-${p}-${n}6
    echo -e "create ban-${p}-${n}4   hash:ip  family inet  timeout ${lim[${p}_${n}_time]}"
    echo -e "create ban-${p}-${n}6   hash:ip  family inet6 timeout ${lim[${p}_${n}_time]}"
    echo -e "create ban-${p}-${n}    list:set"
    echo -e "add    ban-${p}-${n}    ban-${p}-${n}4"
    echo -e "add    ban-${p}-${n}    ban-${p}-${n}6"
  done
done
