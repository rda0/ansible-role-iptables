#!/bin/bash

# AS-based rate limiting for inbound traffic
# Uses:
#  - lim_as[on]      enable/disable
#  - lim_as[list]    list of ASNs (with or without "AS" prefix)
#  - lim_as[ports]   ports to rate-limit; if empty -> limit all ports
#  - lim_as[rate]    limit expression for -m limit (e.g. "100/minute")
#  - lim_as[burst]   burst for -m limit (e.g. "100")
#
# Requires ipsets:
#  - overall "as" list:set with members "<AS>4" and "<AS>6" (hash:net)
#  - per AS: "as<asn>4" (hash:net, inet), "as<asn>6" (hash:net, inet6)

if [[ -n "${lim_as[on]}" ]]; then
  # Default limits if not provided
  [[ -z "${lim_as[rate]}" ]] && lim_as[rate]="100/minute"
  [[ -z "${lim_as[burst]}" ]] && lim_as[burst]="100"

  for ASN in ${lim_as[list]}; do
    # normalize ASN: strip any leading AS/as and keep only digits
    as_num="$(echo "${ASN}" | sed 's/^[Aa][Ss]//; s/[^0-9]//g')"
    [[ -z "${as_num}" ]] && continue

    echo -e "-N i-lim-as${as_num}"
    # Per-AS match: use the per-AS list:set to reach the per-AS chain
    echo -e "-4 -A i-lim-as -m set --match-set as${as_num}_4 src -j i-lim-as${as_num}"
    echo -e "-6 -A i-lim-as -m set --match-set as${as_num}_6 src -j i-lim-as${as_num}"

    if [[ -n "${lim_as[ports]}" ]]; then
      # Limit only specific ports (tcp+udp)
      for p in ${lim_as[ports]}; do
        # Allow within limit, then log+deny over limit
        echo -e "-A i-lim-as${as_num} -p tcp -m tcp --dport ${p} -m limit --limit ${lim_as[rate]} --limit-burst ${lim_as[burst]} -j RETURN"
        if [[ -n "${lim_as[udp_on]}" ]]; then
          echo -e "-A i-lim-as${as_num} -p udp -m udp --dport ${p} -m limit --limit ${lim_as[rate]} --limit-burst ${lim_as[burst]} -j RETURN"
        fi

        [[ "${LOG_LEVEL}" > "${log[i_deny_lvl]}" ]] && echo -e "\
          -A i-lim-as${as_num} -p tcp -m tcp --dport ${p} \
          -m limit --limit ${log[i_deny_limit]} --limit-burst ${log[i_deny_burst]} \
          -j LOG ${LOG_OPTS} \"[ipt-i]lim-as${as_num}-p${p}: \""
        if [[ -n "${lim_as[udp_on]}" ]]; then
          [[ "${LOG_LEVEL}" > "${log[i_deny_lvl]}" ]] && echo -e "\
            -A i-lim-as${as_num} -p udp -m udp --dport ${p} \
            -m limit --limit ${log[i_deny_limit]} --limit-burst ${log[i_deny_burst]} \
            -j LOG ${LOG_OPTS} \"[ipt-i]lim-as${as_num}-p${p}: \""
        fi

        if [[ "${deny_target_drop}" != "true" ]]; then
          echo -e "-4 -A i-lim-as${as_num} -p tcp -m tcp --dport ${p} -j REJECT --reject-with icmp-admin-prohibited"
          echo -e "-6 -A i-lim-as${as_num} -p tcp -m tcp --dport ${p} -j REJECT --reject-with icmp6-adm-prohibited"
          if [[ -n "${lim_as[udp_on]}" ]]; then
            echo -e "-4 -A i-lim-as${as_num} -p udp -m udp --dport ${p} -j REJECT --reject-with icmp-admin-prohibited"
            echo -e "-6 -A i-lim-as${as_num} -p udp -m udp --dport ${p} -j REJECT --reject-with icmp6-adm-prohibited"
          fi
        else
          echo -e "-A i-lim-as${as_num} -p tcp -m tcp --dport ${p} -j DROP"
          if [[ -n "${lim_as[udp_on]}" ]]; then
            echo -e "-A i-lim-as${as_num} -p udp -m udp --dport ${p} -j DROP"
          fi
        fi
      done
    else
      # No ports configured: limit all inbound traffic from the AS
      echo -e "-A i-lim-as${as_num} -m limit --limit ${lim_as[rate]} --limit-burst ${lim_as[burst]} -j RETURN"
      [[ "${LOG_LEVEL}" > "${log[i_deny_lvl]}" ]] && echo -e "\
        -A i-lim-as${as_num} \
        -m limit --limit ${log[i_deny_limit]} --limit-burst ${log[i_deny_burst]} \
        -j LOG ${LOG_OPTS} \"[ipt-i]lim-as${as_num}: \""
      if [[ "${deny_target_drop}" != "true" ]]; then
        echo -e "-4 -A i-lim-as${as_num} -j REJECT --reject-with icmp-admin-prohibited"
        echo -e "-6 -A i-lim-as${as_num} -j REJECT --reject-with icmp6-adm-prohibited"
      else
        echo -e "-A i-lim-as${as_num} -j DROP"
      fi
    fi

    echo -e "-A i-lim-as${as_num} -j RETURN"
  done

  echo -e "-A i-lim-as -j RETURN"
fi

echo -ne '\n'
