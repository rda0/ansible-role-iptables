#!/bin/bash
# rules.d/812-filter-rule-net-as-rate.sh

# AS-based rate limiting for inbound traffic with optional hard block
# Uses:
#  - lim[as_on]        enable/disable
#  - lim[as_list]      list of ASNs (with or without "AS" prefix)
#  - lim[as_block]     subset of lim[as_list] to hard REJECT/DROP
#  - lim[as_ports]     ports to rate-limit/block; if empty -> apply to all ports
#  - lim[as_rate]      AS-global limit expression for -m limit (e.g. "100/minute")
#  - lim[as_burst]     AS-global burst for -m limit (e.g. "100")
#  - lim[as_udp_on]    also apply rules to UDP (otherwise TCP only)
#  - lim[as_ip_on]     enable per-IP limits via -m hashlimit
#  - lim[as_ip_rate]   per-IP limit expression (e.g. "5/minute")
#  - lim[as_ip_burst]  per-IP burst for -m hashlimit (e.g. "10")
#
# Requires ipsets:
#  - overall "as" list:set with members "<AS>4" and "<AS>6" (hash:net)
#  - per AS: "as<asn>_4" (list:set, inet), "as<asn>_6" (list:set, inet6)
#
# Requires xt_hashlimit kernel module for per-IP limits.

if [[ -n "${lim[as_on]}" ]]; then
  # Defaults
  [[ -z "${lim[as_rate]}" ]]     && lim[as_rate]="40/minute"
  [[ -z "${lim[as_burst]}" ]]    && lim[as_burst]="40"
  [[ -n "${lim[as_ip_on]}" ]] && {
    [[ -z "${lim[as_ip_rate]}" ]]  && lim[as_ip_rate]="10/minute"
    [[ -z "${lim[as_ip_burst]}" ]] && lim[as_ip_burst]="20"
  }

  # Normalize block list to digits for quick membership checks
  declare -A as_block
  for BASN in ${lim[as_block]}; do
    bn="$(echo "${BASN}" | sed 's/^[Aa][Ss]//; s/[^0-9]//g')"
    [[ -z "${bn}" ]] && continue
    as_block["${bn}"]="1"
  done

  for ASN in ${lim[as_list]}; do
    # normalize ASN: strip any leading AS/as and keep only digits
    as_num="$(echo "${ASN}" | sed 's/^[Aa][Ss]//; s/[^0-9]//g')"
    [[ -z "${as_num}" ]] && continue

    # Per-AS chains: dispatcher and per-AS chain
    echo -e "-N i-lim-as${as_num}"
    # Dispatch from aggregate 'as' set into per-AS chain
    echo -e "-4 -A i-lim-as -m set --match-set as${as_num}_4 src -j i-lim-as${as_num}"
    echo -e "-6 -A i-lim-as -m set --match-set as${as_num}_6 src -j i-lim-as${as_num}"

    # If this ASN is in the block list, hard block (REJECT/DROP) instead of rate-limit
    if [[ -n "${as_block[${as_num}]}" ]]; then
      if [[ -n "${lim[as_ports]}" ]]; then
        for p in ${lim[as_ports]}; do
          # Logging (throttled)
          [[ "${LOG_LEVEL}" > "${log[i_lim_as_block_lvl]}" ]] && echo -e "\
            -4 -A i-lim-as${as_num} -p tcp -m tcp --dport ${p} \
            -m limit --limit ${log[i_lim_as_block_limit]} --limit-burst ${log[i_lim_as_block_burst]} \
            -j LOG ${LOG_OPTS} \"[ipt-i]block-as${as_num}-p${p}: \""
          [[ "${LOG_LEVEL}" > "${log[i_lim_as_block_lvl]}" ]] && echo -e "\
            -6 -A i-lim-as${as_num} -p tcp -m tcp --dport ${p} \
            -m limit --limit ${log[i_lim_as_block_limit]} --limit-burst ${log[i_lim_as_block_burst]} \
            -j LOG ${LOG_OPTS} \"[ipt-i]block-as${as_num}-p${p}: \""

          if [[ "${deny_target_drop}" != "true" ]]; then
            echo -e "-4 -A i-lim-as${as_num} -p tcp -m tcp --dport ${p} -j REJECT --reject-with icmp-admin-prohibited"
            echo -e "-6 -A i-lim-as${as_num} -p tcp -m tcp --dport ${p} -j REJECT --reject-with icmp6-adm-prohibited"
          else
            echo -e "-A i-lim-as${as_num} -p tcp -m tcp --dport ${p} -j DROP"
          fi

          if [[ -n "${lim[as_udp_on]}" ]]; then
            [[ "${LOG_LEVEL}" > "${log[i_lim_as_block_lvl]}" ]] && echo -e "\
              -4 -A i-lim-as${as_num} -p udp -m udp --dport ${p} \
              -m limit --limit ${log[i_lim_as_block_limit]} --limit-burst ${log[i_lim_as_block_burst]} \
              -j LOG ${LOG_OPTS} \"[ipt-i]block-as${as_num}-p${p}: \""
            [[ "${LOG_LEVEL}" > "${log[i_lim_as_block_lvl]}" ]] && echo -e "\
              -6 -A i-lim-as${as_num} -p udp -m udp --dport ${p} \
              -m limit --limit ${log[i_lim_as_block_limit]} --limit-burst ${log[i_lim_as_block_burst]} \
              -j LOG ${LOG_OPTS} \"[ipt-i]block-as${as_num}-p${p}: \""

            if [[ "${deny_target_drop}" != "true" ]]; then
              echo -e "-4 -A i-lim-as${as_num} -p udp -m udp --dport ${p} -j REJECT --reject-with icmp-admin-prohibited"
              echo -e "-6 -A i-lim-as${as_num} -p udp -m udp --dport ${p} -j REJECT --reject-with icmp6-adm-prohibited"
            else
              echo -e "-A i-lim-as${as_num} -p udp -m udp --dport ${p} -j DROP"
            fi
          fi
        done
      else
        # No ports configured: block all inbound traffic from the AS
        [[ "${LOG_LEVEL}" > "${log[i_lim_as_block_lvl]}" ]] && echo -e "\
          -4 -A i-lim-as${as_num} \
          -m limit --limit ${log[i_lim_as_block_limit]} --limit-burst ${log[i_lim_as_block_burst]} \
          -j LOG ${LOG_OPTS} \"[ipt-i]block-as${as_num}: \""
        [[ "${LOG_LEVEL}" > "${log[i_lim_as_block_lvl]}" ]] && echo -e "\
          -6 -A i-lim-as${as_num} \
          -m limit --limit ${log[i_lim_as_block_limit]} --limit-burst ${log[i_lim_as_block_burst]} \
          -j LOG ${LOG_OPTS} \"[ipt-i]block-as${as_num}: \""

        if [[ "${deny_target_drop}" != "true" ]]; then
          echo -e "-4 -A i-lim-as${as_num} -j REJECT --reject-with icmp-admin-prohibited"
          echo -e "-6 -A i-lim-as${as_num} -j REJECT --reject-with icmp6-adm-prohibited"
        else
          echo -e "-A i-lim-as${as_num} -j DROP"
        fi
      fi

      # Allow unmatched traffic (e.g., other ports when ports are scoped)
      echo -e "-A i-lim-as${as_num} -j RETURN"
      continue
    fi

    # Not blocked: apply rate-limiting
    if [[ -n "${lim[as_ports]}" ]]; then
      # Limit only specific ports (tcp/udp)
      for p in ${lim[as_ports]}; do
        # Combined acceptance: both per-IP hashlimit (if enabled) AND AS-global limit must be under thresholds
        if [[ -n "${lim[as_ip_on]}" ]]; then
          # TCP
          echo -e "-4 -A i-lim-as${as_num} -p tcp -m tcp --dport ${p} \
            -m hashlimit --hashlimit ${lim[as_ip_rate]} --hashlimit-burst ${lim[as_ip_burst]} \
            --hashlimit-mode srcip --hashlimit-name as${as_num}_tcp_${p}_ip4 \
            -m limit --limit ${lim[as_rate]} --limit-burst ${lim[as_burst]} \
            -j RETURN"
          echo -e "-6 -A i-lim-as${as_num} -p tcp -m tcp --dport ${p} \
            -m hashlimit --hashlimit ${lim[as_ip_rate]} --hashlimit-burst ${lim[as_ip_burst]} \
            --hashlimit-mode srcip --hashlimit-name as${as_num}_tcp_${p}_ip6 \
            -m limit --limit ${lim[as_rate]} --limit-burst ${lim[as_burst]} \
            -j RETURN"
          # UDP (optional)
          if [[ -n "${lim[as_udp_on]}" ]]; then
            echo -e "-4 -A i-lim-as${as_num} -p udp -m udp --dport ${p} \
              -m hashlimit --hashlimit ${lim[as_ip_rate]} --hashlimit-burst ${lim[as_ip_burst]} \
              --hashlimit-mode srcip --hashlimit-name as${as_num}_udp_${p}_ip4 \
              -m limit --limit ${lim[as_rate]} --limit-burst ${lim[as_burst]} \
              -j RETURN"
            echo -e "-6 -A i-lim-as${as_num} -p udp -m udp --dport ${p} \
              -m hashlimit --hashlimit ${lim[as_ip_rate]} --hashlimit-burst ${lim[as_ip_burst]} \
              --hashlimit-mode srcip --hashlimit-name as${as_num}_udp_${p}_ip6 \
              -m limit --limit ${lim[as_rate]} --limit-burst ${lim[as_burst]} \
              -j RETURN"
          fi
        else
          # No per-IP limit: keep AS-global only
          echo -e "-A i-lim-as${as_num} -p tcp -m tcp --dport ${p} \
            -m limit --limit ${lim[as_rate]} --limit-burst ${lim[as_burst]} \
            -j RETURN"
          if [[ -n "${lim[as_udp_on]}" ]]; then
            echo -e "-A i-lim-as${as_num} -p udp -m udp --dport ${p} \
              -m limit --limit ${lim[as_rate]} --limit-burst ${lim[as_burst]} \
              -j RETURN"
          fi
        fi

        # Logging when either limit is exceeded (throttled)
        [[ "${LOG_LEVEL}" > "${log[i_lim_as_ratelimit_lvl]}" ]] && echo -e "\
          -4 -A i-lim-as${as_num} -p tcp -m tcp --dport ${p} \
          -m limit --limit ${log[i_lim_as_ratelimit_limit]} --limit-burst ${log[i_lim_as_ratelimit_burst]} \
          -j LOG ${LOG_OPTS} \"[ipt-i]lim-as${as_num}-p${p}: \""
        [[ "${LOG_LEVEL}" > "${log[i_lim_as_ratelimit_lvl]}" ]] && echo -e "\
          -6 -A i-lim-as${as_num} -p tcp -m tcp --dport ${p} \
          -m limit --limit ${log[i_lim_as_ratelimit_limit]} --limit-burst ${log[i_lim_as_ratelimit_burst]} \
          -j LOG ${LOG_OPTS} \"[ipt-i]lim-as${as_num}-p${p}: \""
        if [[ -n "${lim[as_udp_on]}" ]]; then
          [[ "${LOG_LEVEL}" > "${log[i_lim_as_ratelimit_lvl]}" ]] && echo -e "\
            -4 -A i-lim-as${as_num} -p udp -m udp --dport ${p} \
            -m limit --limit ${log[i_lim_as_ratelimit_limit]} --limit-burst ${log[i_lim_as_ratelimit_burst]} \
            -j LOG ${LOG_OPTS} \"[ipt-i]lim-as${as_num}-p${p}: \""
          [[ "${LOG_LEVEL}" > "${log[i_lim_as_ratelimit_lvl]}" ]] && echo -e "\
            -6 -A i-lim-as${as_num} -p udp -m udp --dport ${p} \
            -m limit --limit ${log[i_lim_as_ratelimit_limit]} --limit-burst ${log[i_lim_as_ratelimit_burst]} \
            -j LOG ${LOG_OPTS} \"[ipt-i]lim-as${as_num}-p${p}: \""
        fi

        # Deny when limits exceeded
        if [[ "${deny_target_drop}" != "true" ]]; then
          echo -e "-4 -A i-lim-as${as_num} -p tcp -m tcp --dport ${p} -j REJECT --reject-with icmp-admin-prohibited"
          echo -e "-6 -A i-lim-as${as_num} -p tcp -m tcp --dport ${p} -j REJECT --reject-with icmp6-adm-prohibited"
          if [[ -n "${lim[as_udp_on]}" ]]; then
            echo -e "-4 -A i-lim-as${as_num} -p udp -m udp --dport ${p} -j REJECT --reject-with icmp-admin-prohibited"
            echo -e "-6 -A i-lim-as${as_num} -p udp -m udp --dport ${p} -j REJECT --reject-with icmp6-adm-prohibited"
          fi
        else
          echo -e "-A i-lim-as${as_num} -p tcp -m tcp --dport ${p} -j DROP"
          if [[ -n "${lim[as_udp_on]}" ]]; then
            echo -e "-A i-lim-as${as_num} -p udp -m udp --dport ${p} -j DROP"
          fi
        fi
      done
    else
      # No ports configured: limit all inbound traffic from the AS
      if [[ -n "${lim[as_ip_on]}" ]]; then
        echo -e "-4 -A i-lim-as${as_num} \
          -m hashlimit --hashlimit ${lim[as_ip_rate]} --hashlimit-burst ${lim[as_ip_burst]} \
          --hashlimit-mode srcip --hashlimit-name as${as_num}_ip4 \
          -m limit --limit ${lim[as_rate]} --limit-burst ${lim[as_burst]} \
          -j RETURN"
        echo -e "-6 -A i-lim-as${as_num} \
          -m hashlimit --hashlimit ${lim[as_ip_rate]} --hashlimit-burst ${lim[as_ip_burst]} \
          --hashlimit-mode srcip --hashlimit-name as${as_num}_ip6 \
          -m limit --limit ${lim[as_rate]} --limit-burst ${lim[as_burst]} \
          -j RETURN"
      else
        echo -e "-A i-lim-as${as_num} \
          -m limit --limit ${lim[as_rate]} --limit-burst ${lim[as_burst]} \
          -j RETURN"
      fi

      [[ "${LOG_LEVEL}" > "${log[i_lim_as_ratelimit_lvl]}" ]] && echo -e "\
        -4 -A i-lim-as${as_num} \
        -m limit --limit ${log[i_lim_as_ratelimit_limit]} --limit-burst ${log[i_lim_as_ratelimit_burst]} \
        -j LOG ${LOG_OPTS} \"[ipt-i]lim-as${as_num}: \""
      [[ "${LOG_LEVEL}" > "${log[i_lim_as_ratelimit_lvl]}" ]] && echo -e "\
        -6 -A i-lim-as${as_num} \
        -m limit --limit ${log[i_lim_as_ratelimit_limit]} --limit-burst ${log[i_lim_as_ratelimit_burst]} \
        -j LOG ${LOG_OPTS} \"[ipt-i]lim-as${as_num}: \""

      if [[ "${deny_target_drop}" != "true" ]]; then
        echo -e "-4 -A i-lim-as${as_num} -j REJECT --reject-with icmp-admin-prohibited"
        echo -e "-6 -A i-lim-as${as_num} -j REJECT --reject-with icmp6-adm-prohibited"
      else
        echo -e "-A i-lim-as${as_num} -j DROP"
      fi
    fi

    # Allow unmatched traffic (e.g., other ports when ports are scoped)
    echo -e "-A i-lim-as${as_num} -j RETURN"
  done

  # Dispatcher return
  echo -e "-A i-lim-as -j RETURN"
fi

echo -ne '\n'
