#!/bin/bash

/sbin/iptables -P INPUT ACCEPT
/sbin/iptables -P OUTPUT ACCEPT
/sbin/iptables -P FORWARD ACCEPT
/sbin/iptables -F
/sbin/iptables -X
/sbin/iptables -Z
/sbin/ip6tables -P INPUT ACCEPT
/sbin/ip6tables -P OUTPUT ACCEPT
/sbin/ip6tables -P FORWARD ACCEPT
/sbin/ip6tables -F
/sbin/ip6tables -X
/sbin/ip6tables -Z
/sbin/ipset flush
