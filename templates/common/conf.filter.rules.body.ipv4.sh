#!/bin/bash

. /etc/iptables/iptables.conf

export SET_ADM="admin"
export SET_UPD="update"
export SET_SRV="server"
export SET_CUS="custom"
export SET_TRU="trusted" # includes: Trusted, Server, Admin

/etc/iptables/conf.filter.rules.body.sh
