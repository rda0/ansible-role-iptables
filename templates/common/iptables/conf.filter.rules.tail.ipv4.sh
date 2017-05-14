#!/bin/bash

. /etc/iptables/iptables.conf

export SET_TRU="trusted"

/etc/iptables/conf.filter.rules.tail.sh
