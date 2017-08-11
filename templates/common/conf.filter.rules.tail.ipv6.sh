#!/bin/bash

. /etc/iptables/iptables.conf

export SET_TRU="trusted6"

/etc/iptables/conf.filter.rules.tail.sh
