#!/bin/bash

[[ "${if_br}" != "" ]] && echo -e "# Allow bridge traffic"
for i in ${if_br}; do
  echo -e "-A FORWARD -i ${i} -o ${i} -j ACCEPT"
done

[[ "${if_tuntap}" != "" ]] && echo -e "# Allow tuntap traffic"
for i in ${if_tuntap}; do
  echo -e "-A FORWARD -i ${i} -j ACCEPT"
done

echo -e "# Create logging chain"
echo -e "-N i-log"
echo -e "-N f-log"
[[ "${allow_o_any}" != "true" ]] && echo -e "-N o-log"

echo -e "-A INPUT   -j i-log"
echo -e "-A FORWARD -j f-log"
[[ "${allow_o_any}" != "true" ]] && echo -e "-A OUTPUT  -j o-log"

echo -e "# Limit logging of BROADCAST, MULTICAST, ANYCAST address targets and DROP silently"
[[ "${LOG_LEVEL}" > "${log[i_bcast_lvl]}" ]] && echo -e "\
     -4 -A i-log   -m addrtype --dst-type BROADCAST \
     -m limit --limit ${log[i_bcast_limit]} --limit-burst ${log[i_bcast_burst]} \
     -j LOG ${LOG_OPTS} \"[ipt-i]bcast: \""
echo -e "-4 -A i-log   -m addrtype --dst-type BROADCAST -j DROP"
[[ "${LOG_LEVEL}" > "${log[i_mcast_lvl]}" ]] && echo -e "\
     -4 -A i-log   -m addrtype --dst-type MULTICAST \
     -m limit --limit ${log[i_mcast_limit]} --limit-burst ${log[i_mcast_burst]} \
     -j LOG ${LOG_OPTS} \"[ipt-i]mcast: \""
echo -e "-4 -A i-log   -m addrtype --dst-type MULTICAST -j DROP"
[[ "${LOG_LEVEL}" > "${log[i_acast_lvl]}" ]] && echo -e "\
     -4 -A i-log   -m addrtype --dst-type ANYCAST \
     -m limit --limit ${log[i_acast_limit]} --limit-burst ${log[i_acast_burst]} \
     -j LOG ${LOG_OPTS} \"[ipt-i]acast: \""
echo -e "-4 -A i-log   -m addrtype --dst-type ANYCAST -j DROP"
[[ "${LOG_LEVEL}" > "${log[i_mcast_lvl]}" ]] && echo -e "\
     -6 -A i-log   -m addrtype --dst-type MULTICAST \
     -m limit --limit ${log[i_mcast_limit]} --limit-burst ${log[i_mcast_burst]} \
     -j LOG ${LOG_OPTS} \"[ipt-i]mcast: \""
echo -e "-6 -A i-log   -m addrtype --dst-type MULTICAST -j DROP"

echo -e "# All other connections are registered in syslog"
[[ "${LOG_LEVEL}" > "${log[i_deny_lvl]}" ]] && echo -e "\
         -A i-log   -m limit --limit ${log[i_deny_limit]} --limit-burst ${log[i_deny_burst]} \
         -j LOG ${LOG_OPTS} \"[ipt-i]deny: \""
echo -e "-A i-log   -j RETURN"
[[ "${LOG_LEVEL}" > "${log[f_deny_lvl]}" ]] && echo -e "\
         -A f-log   -m limit --limit ${log[f_deny_limit]} --limit-burst ${log[f_deny_burst]} \
         -j LOG ${LOG_OPTS} \"[ipt-f]deny: \""
echo -e "-A f-log   -j RETURN"
if [[ "${allow_o_any}" != "true" ]]; then
  [[ "${LOG_LEVEL}" > "${log[o_deny_lvl]}" ]] && echo -e "\
           -A o-log   -m limit --limit ${log[o_deny_limit]} --limit-burst ${log[o_deny_burst]} \
           -j LOG ${LOG_OPTS} \"[ipt-o]deny: \""
  echo -e "-A o-log   -j RETURN"
fi

echo -e "# And finally denied"
echo -e "-A INPUT   -j i-deny"
echo -e "-A FORWARD -j f-deny"
[[ "${allow_o_any}" != "true" ]] && echo -e "-A OUTPUT  -j o-deny"

if [[ "${deny_target_drop}" != "true" ]]; then
  echo -e "# Reject rfc compliant"
  echo -e "-4 -A i-deny -p tcp -j REJECT --reject-with tcp-reset"
  echo -e "-4 -A i-deny -p udp -j REJECT --reject-with icmp-port-unreachable"
  echo -e "-4 -A i-deny        -j REJECT --reject-with icmp-proto-unreachable"
  echo -e "-6 -A i-deny -p tcp -j REJECT --reject-with tcp-reset"
  echo -e "-6 -A i-deny -p udp -j REJECT --reject-with icmp6-port-unreachable"
  echo -e "-6 -A i-deny        -j REJECT --reject-with icmp6-adm-prohibited"
  if [[ "${allow_o_any}" != "true" ]]; then
    echo -e "-4 -A o-deny -p tcp -j REJECT --reject-with tcp-reset"
    echo -e "-4 -A o-deny -p udp -j REJECT --reject-with icmp-port-unreachable"
    echo -e "-4 -A o-deny        -j REJECT --reject-with icmp-proto-unreachable"
    echo -e "-6 -A o-deny -p tcp -j REJECT --reject-with tcp-reset"
    echo -e "-6 -A o-deny -p udp -j REJECT --reject-with icmp6-port-unreachable"
    echo -e "-6 -A o-deny        -j REJECT --reject-with icmp6-adm-prohibited"
  fi
  echo -e "-4 -A f-deny        -j REJECT --reject-with icmp-host-unreachable"
  echo -e "-6 -A f-deny        -j REJECT --reject-with icmp6-addr-unreachable"
else
  echo -e "# Drop hard"
  echo -e "-A i-deny   -j DROP"
  echo -e "-A f-deny   -j DROP"
  [[ "${allow_o_any}" != "true" ]] && echo -e "-A o-deny   -j DROP"
fi

echo -e "-A i-deny   -j RETURN"
echo -e "-A f-deny   -j RETURN"
[[ "${allow_o_any}" != "true" ]] && echo -e "-A o-deny   -j RETURN"
