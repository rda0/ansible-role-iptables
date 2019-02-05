#!/bin/bash

# clear out everything
for ipt in iptables ip6tables; do
    /sbin/${ipt} -P INPUT ACCEPT
    /sbin/${ipt} -P OUTPUT ACCEPT
    /sbin/${ipt} -P FORWARD ACCEPT
    for table in filter mangle nat raw; do
        /sbin/${ipt} -t ${table} -nL >/dev/null 2>&1 || continue  # non-existing table
        /sbin/${ipt} -t ${table} -F                               # delete rules
        /sbin/${ipt} -t ${table} -X                               # delete custom chains
        /sbin/${ipt} -t ${table} -Z                               # zero counters
    done
done
