#!/bin/bash

. /etc/iptables/iptables.conf

export SET_ADM="admin6"
export SET_UPD="update6"
export SET_SRV="server6"
export SET_CUS="custom6"
export SET_TRU="trusted6" # includes: Trusted, Server, Admin

/etc/iptables/conf.filter.rules.body.sh
