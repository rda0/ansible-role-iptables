#!/bin/bash

echo -e "# Drop invalid state packets"
[[ "${LOG_LEVEL}" > "${log[i_invalid_lvl]}" ]] && echo -e "\
         -A INPUT   -m conntrack --ctstate INVALID \
         -m limit --limit ${log[i_invalid_limit]} --limit-burst ${log[i_invalid_burst]} \
         -j LOG ${LOG_OPTS} \"[ipt-i]invalid: \""
echo -e "-A INPUT   -m conntrack --ctstate INVALID -j DROP"
[[ "${LOG_LEVEL}" > "${log[f_invalid_lvl]}" ]] && echo -e "\
         -A FORWARD -m conntrack --ctstate INVALID \
         -m limit --limit ${log[f_invalid_limit]} --limit-burst ${log[f_invalid_burst]} \
         -j LOG ${LOG_OPTS} \"[ipt-f]invalid: \""
echo -e "-A FORWARD -m conntrack --ctstate INVALID -j DROP"
if [[ "${allow_o_any}" != "true" ]]; then
  [[ "${LOG_LEVEL}" > "${log[o_invalid_lvl]}" ]] && echo -e "\
           -A OUTPUT  -m conntrack --ctstate INVALID \
           -m limit --limit ${log[o_invalid_limit]} --limit-burst ${log[o_invalid_burst]} \
           -j LOG ${LOG_OPTS} \"[ipt-o]invalid: \""
  echo -e "-A OUTPUT  -m conntrack --ctstate INVALID -j DROP"
fi

echo -ne '\n'
