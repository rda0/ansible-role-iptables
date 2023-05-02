#!/bin/bash

if [[ -n "${lim[on]}" ]]; then
  echo -e "# Add chain for ssh rate limit"
  echo -e "-N i-lim-ssh"
  echo -e "-4 -A INPUT   -p tcp -m tcp --dport 22 -m set ! --match-set adm4 src -j i-lim-ssh"
  echo -e "-6 -A INPUT   -p tcp -m tcp --dport 22 -m set ! --match-set adm6 src -j i-lim-ssh"

  if [[ -n "${lim[nets_exclude]}" ]]; then
    echo -e "# Exclude networks from rate limiting"
    for n in ${lim[nets_exclude]}; do
      echo -e "-A i-lim-ssh  -m set   --match-set ${n} src -j RETURN"
    done
  fi

  echo -e "# Track connection source in ssh-rate recent table"
  echo -e "-A i-lim-ssh  -m recent --set --name lim-ssh"

  if [[ -n "${lim[ssh_can_on]}" ]]; then
    echo -e "# Check if source (can) exceeds threshold -> add to set ban-ssh-can, log"
    echo -e "-A i-lim-ssh  -m set   --match-set can src \
             -m recent --rcheck --rttl \
             --seconds ${lim[ssh_can_secs]} \
             --hitcount ${lim[ssh_can_hits]} \
             --name lim-ssh \
             -j SET --add-set ban-ssh-can src --exist"
    [[ "${LOG_LEVEL}" > "${log[i_lim_ssh_can_lvl]}" ]] && echo -e "\
             -A i-lim-ssh  -m set   --match-set can src \
             -m recent --rcheck --rttl \
             --seconds ${lim[ssh_can_secs]} \
             --hitcount ${lim[ssh_can_hits]} \
             --name lim-ssh \
             -m limit --limit ${log[i_lim_ssh_limit]} --limit-burst ${log[i_lim_ssh_burst]} \
             -j LOG ${LOG_OPTS} \"[ipt-i]lim-ssh-can: \""
  fi

  if [[ -n "${lim[ssh_any_on]}" ]]; then
    echo -e "# Check if source (not can) exceeds threshold -> add to set ban-ssh-any, log"
    echo -e "-A i-lim-ssh  -m set ! --match-set can src \
             -m recent --rcheck --rttl \
             --seconds ${lim[ssh_any_secs]} \
             --hitcount ${lim[ssh_any_hits]} \
             --name lim-ssh \
             -j SET --add-set ban-ssh-any src --exist"
    [[ "${LOG_LEVEL}" > "${log[i_lim_ssh_any_lvl]}" ]] && echo -e "\
             -A i-lim-ssh  -m set ! --match-set can src \
             -m recent --rcheck --rttl \
             --seconds ${lim[ssh_any_secs]} \
             --hitcount ${lim[ssh_any_hits]} \
             --name lim-ssh \
             -m limit --limit ${log[i_lim_ssh_limit]} --limit-burst ${log[i_lim_ssh_burst]} \
             -j LOG ${LOG_OPTS} \"[ipt-i]lim-ssh-any: \""
  fi

  echo -e "# Deny connections from sources in block-ssh* tables"
  if [[ "${deny_target_drop}" != "true" ]]; then
    echo -e "-4 -A i-lim-ssh -m set --match-set ban-ssh-can src -j REJECT --reject-with icmp-admin-prohibited"
    echo -e "-6 -A i-lim-ssh -m set --match-set ban-ssh-can src -j REJECT --reject-with icmp6-adm-prohibited"
    echo -e "-4 -A i-lim-ssh -m set --match-set ban-ssh-any src -j REJECT --reject-with icmp-admin-prohibited"
    echo -e "-6 -A i-lim-ssh -m set --match-set ban-ssh-any src -j REJECT --reject-with icmp6-adm-prohibited"
  else
    echo -e "-4 -A i-lim-ssh -m set --match-set ban-ssh-can src -j REJECT --reject-with icmp-admin-prohibited"
    echo -e "-6 -A i-lim-ssh -m set --match-set ban-ssh-can src -j REJECT --reject-with icmp6-adm-prohibited"
    echo -e "-4 -A i-lim-ssh -m set --match-set ban-ssh-any src -j DROP"
    echo -e "-6 -A i-lim-ssh -m set --match-set ban-ssh-any src -j DROP"
  fi

  echo -e "-A i-lim-ssh -j RETURN"
fi

echo -ne '\n'
