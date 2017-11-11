#!/bin/sh

# clear out everything
for ipt in iptables ip6tables; do
    $ipt -P INPUT ACCEPT
    $ipt -P OUTPUT ACCEPT
    $ipt -P FORWARD ACCEPT
    for table in filter mangle nat raw; do
        $ipt -t $table -nL >/dev/null 2>&1 || continue # non-existing table
        $ipt -t $table -F        # delete rules
        $ipt -t $table -X        # delete custom chains
        $ipt -t $table -Z        # zero counters
    done
done
