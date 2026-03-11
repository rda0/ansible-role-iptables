#!/bin/bash
# rules.d/812-filter-rule-net-as-rate.sh

# AS/CC-based rate limiting for inbound traffic with optional hard block
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
#  - lim[cc_on]        enable/disable
#  - lim[cc_list]      list of country codes
#  - lim[cc_block]     subset of lim[cc_list] to hard REJECT/DROP
#  - lim[cc_ports]     ports to rate-limit/block; if empty -> apply to all ports
#  - lim[cc_rate]      CC-global limit expression for -m limit (e.g. "100/minute")
#  - lim[cc_burst]     CC-global burst for -m limit (e.g. "100")
#  - lim[cc_udp_on]    also apply rules to UDP (otherwise TCP only)
#  - lim[cc_ip_on]     enable per-IP limits via -m hashlimit
#  - lim[cc_ip_rate]   per-IP limit expression (e.g. "5/minute")
#  - lim[cc_ip_burst]  per-IP burst for -m hashlimit (e.g. "10")
#
# Requires ipsets:
#  - overall "as"/"cc" list:set with members "<id>4" and "<id>6" (hash:net)
#  - per id: "<a><id>_4" (list:set, inet), "<a><id>_6" (list:set, inet6)
#
# Requires xt_hashlimit kernel module for per-IP limits.

for a in as cc; do
  if [[ -n "${lim[${a}_on]}" ]]; then
    # Defaults
    [[ -z "${lim[${a}_rate]}" ]]     && lim[${a}_rate]="40/minute"
    [[ -z "${lim[${a}_burst]}" ]]    && lim[${a}_burst]="40"
    [[ -n "${lim[${a}_ip_on]}" ]] && {
      [[ -z "${lim[${a}_ip_rate]}" ]]  && lim[${a}_ip_rate]="10/minute"
      [[ -z "${lim[${a}_ip_burst]}" ]] && lim[${a}_ip_burst]="20"
    }

    # Normalize block list for quick membership checks
    declare -A block
    for BID in ${lim[${a}_block]}; do
      if [[ "${a}" == "as" ]]; then
        bid="$(echo "${BID}" | sed 's/^[Aa][Ss]//; s/[^0-9]//g')"
      else
        bid="$(echo "${BID}" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z]//g')"
      fi
      [[ -z "${bid}" ]] && continue
      block["${bid}"]="1"
    done

    for ID in ${lim[${a}_list]}; do
      if [[ "${a}" == "as" ]]; then
        # normalize ASN: strip any leading AS/as and keep only digits
        id="$(echo "${ID}" | sed 's/^[Aa][Ss]//; s/[^0-9]//g')"
      else
        # normalize CC: keep A-Z only, upper-case
        id="$(echo "${ID}" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z]//g')"
      fi
      [[ -z "${id}" ]] && continue

      # Per-ID chains: dispatcher and per-ID chain
      echo -e "-N i-lim-${a}${id}"
      # Dispatch from aggregate set into per-ID chain
      echo -e "-4 -A i-lim-${a} -m set --match-set ${a}${id}_4 src -j i-lim-${a}${id}"
      echo -e "-6 -A i-lim-${a} -m set --match-set ${a}${id}_6 src -j i-lim-${a}${id}"

      # If this ID is in the block list, hard block (REJECT/DROP) instead of rate-limit
      if [[ -n "${block[${id}]}" ]]; then
        if [[ -n "${lim[${a}_ports]}" ]]; then
          for p in ${lim[${a}_ports]}; do
            # Logging (throttled)
            [[ "${LOG_LEVEL}" > "${log[i_lim_${a}_block_lvl]}" ]] && echo -e "\
              -4 -A i-lim-${a}${id} -p tcp -m tcp --dport ${p} \
              -m limit --limit ${log[i_lim_${a}_block_limit]} --limit-burst ${log[i_lim_${a}_block_burst]} \
              -j LOG ${LOG_OPTS} \"[ipt-i]block-${a}${id}-p${p}: \""
            [[ "${LOG_LEVEL}" > "${log[i_lim_${a}_block_lvl]}" ]] && echo -e "\
              -6 -A i-lim-${a}${id} -p tcp -m tcp --dport ${p} \
              -m limit --limit ${log[i_lim_${a}_block_limit]} --limit-burst ${log[i_lim_${a}_block_burst]} \
              -j LOG ${LOG_OPTS} \"[ipt-i]block-${a}${id}-p${p}: \""

            if [[ "${deny_target_drop}" != "true" ]]; then
              echo -e "-4 -A i-lim-${a}${id} -p tcp -m tcp --dport ${p} -j REJECT --reject-with icmp-admin-prohibited"
              echo -e "-6 -A i-lim-${a}${id} -p tcp -m tcp --dport ${p} -j REJECT --reject-with icmp6-adm-prohibited"
            else
              echo -e "-A i-lim-${a}${id} -p tcp -m tcp --dport ${p} -j DROP"
            fi

            if [[ -n "${lim[${a}_udp_on]}" ]]; then
              [[ "${LOG_LEVEL}" > "${log[i_lim_${a}_block_lvl]}" ]] && echo -e "\
                -4 -A i-lim-${a}${id} -p udp -m udp --dport ${p} \
                -m limit --limit ${log[i_lim_${a}_block_limit]} --limit-burst ${log[i_lim_${a}_block_burst]} \
                -j LOG ${LOG_OPTS} \"[ipt-i]block-${a}${id}-p${p}: \""
              [[ "${LOG_LEVEL}" > "${log[i_lim_${a}_block_lvl]}" ]] && echo -e "\
                -6 -A i-lim-${a}${id} -p udp -m udp --dport ${p} \
                -m limit --limit ${log[i_lim_${a}_block_limit]} --limit-burst ${log[i_lim_${a}_block_burst]} \
                -j LOG ${LOG_OPTS} \"[ipt-i]block-${a}${id}-p${p}: \""

              if [[ "${deny_target_drop}" != "true" ]]; then
                echo -e "-4 -A i-lim-${a}${id} -p udp -m udp --dport ${p} -j REJECT --reject-with icmp-admin-prohibited"
                echo -e "-6 -A i-lim-${a}${id} -p udp -m udp --dport ${p} -j REJECT --reject-with icmp6-adm-prohibited"
              else
                echo -e "-A i-lim-${a}${id} -p udp -m udp --dport ${p} -j DROP"
              fi
            fi
          done
        else
          # No ports configured: block all inbound traffic from the AS/CC
          [[ "${LOG_LEVEL}" > "${log[i_lim_${a}_block_lvl]}" ]] && echo -e "\
            -4 -A i-lim-${a}${id} \
            -m limit --limit ${log[i_lim_${a}_block_limit]} --limit-burst ${log[i_lim_${a}_block_burst]} \
            -j LOG ${LOG_OPTS} \"[ipt-i]block-${a}${id}: \""
          [[ "${LOG_LEVEL}" > "${log[i_lim_${a}_block_lvl]}" ]] && echo -e "\
            -6 -A i-lim-${a}${id} \
            -m limit --limit ${log[i_lim_${a}_block_limit]} --limit-burst ${log[i_lim_${a}_block_burst]} \
            -j LOG ${LOG_OPTS} \"[ipt-i]block-${a}${id}: \""

          if [[ "${deny_target_drop}" != "true" ]]; then
            echo -e "-4 -A i-lim-${a}${id} -j REJECT --reject-with icmp-admin-prohibited"
            echo -e "-6 -A i-lim-${a}${id} -j REJECT --reject-with icmp6-adm-prohibited"
          else
            echo -e "-A i-lim-${a}${id} -j DROP"
          fi
        fi

        # Allow unmatched traffic (e.g., other ports when ports are scoped)
        echo -e "-A i-lim-${a}${id} -j RETURN"
        continue
      fi

      # Not blocked: apply rate-limiting
      if [[ -n "${lim[${a}_ports]}" ]]; then
        # Limit only specific ports (tcp/udp)
        for p in ${lim[${a}_ports]}; do
          # Combined acceptance: both per-IP hashlimit (if enabled) AND global limit must be under thresholds
          if [[ -n "${lim[${a}_ip_on]}" ]]; then
            # TCP
            echo -e "-4 -A i-lim-${a}${id} -p tcp -m tcp --dport ${p} \
              -m hashlimit --hashlimit ${lim[${a}_ip_rate]} --hashlimit-burst ${lim[${a}_ip_burst]} \
              --hashlimit-mode srcip --hashlimit-name ${a}${id}_tcp_${p}_ip4 \
              -m limit --limit ${lim[${a}_rate]} --limit-burst ${lim[${a}_burst]} \
              -j RETURN"
            echo -e "-6 -A i-lim-${a}${id} -p tcp -m tcp --dport ${p} \
              -m hashlimit --hashlimit ${lim[${a}_ip_rate]} --hashlimit-burst ${lim[${a}_ip_burst]} \
              --hashlimit-mode srcip --hashlimit-name ${a}${id}_tcp_${p}_ip6 \
              -m limit --limit ${lim[${a}_rate]} --limit-burst ${lim[${a}_burst]} \
              -j RETURN"
            # UDP (optional)
            if [[ -n "${lim[${a}_udp_on]}" ]]; then
              echo -e "-4 -A i-lim-${a}${id} -p udp -m udp --dport ${p} \
                -m hashlimit --hashlimit ${lim[${a}_ip_rate]} --hashlimit-burst ${lim[${a}_ip_burst]} \
                --hashlimit-mode srcip --hashlimit-name ${a}${id}_udp_${p}_ip4 \
                -m limit --limit ${lim[${a}_rate]} --limit-burst ${lim[${a}_burst]} \
                -j RETURN"
              echo -e "-6 -A i-lim-${a}${id} -p udp -m udp --dport ${p} \
                -m hashlimit --hashlimit ${lim[${a}_ip_rate]} --hashlimit-burst ${lim[${a}_ip_burst]} \
                --hashlimit-mode srcip --hashlimit-name ${a}${id}_udp_${p}_ip6 \
                -m limit --limit ${lim[${a}_rate]} --limit-burst ${lim[${a}_burst]} \
                -j RETURN"
            fi
          else
            # No per-IP limit: keep global only
            echo -e "-A i-lim-${a}${id} -p tcp -m tcp --dport ${p} \
              -m limit --limit ${lim[${a}_rate]} --limit-burst ${lim[${a}_burst]} \
              -j RETURN"
            if [[ -n "${lim[${a}_udp_on]}" ]]; then
              echo -e "-A i-lim-${a}${id} -p udp -m udp --dport ${p} \
                -m limit --limit ${lim[${a}_rate]} --limit-burst ${lim[${a}_burst]} \
                -j RETURN"
            fi
          fi

          # Logging when either limit is exceeded (throttled)
          [[ "${LOG_LEVEL}" > "${log[i_lim_${a}_ratelimit_lvl]}" ]] && echo -e "\
            -4 -A i-lim-${a}${id} -p tcp -m tcp --dport ${p} \
            -m limit --limit ${log[i_lim_${a}_ratelimit_limit]} --limit-burst ${log[i_lim_${a}_ratelimit_burst]} \
            -j LOG ${LOG_OPTS} \"[ipt-i]lim-${a}${id}-p${p}: \""
          [[ "${LOG_LEVEL}" > "${log[i_lim_${a}_ratelimit_lvl]}" ]] && echo -e "\
            -6 -A i-lim-${a}${id} -p tcp -m tcp --dport ${p} \
            -m limit --limit ${log[i_lim_${a}_ratelimit_limit]} --limit-burst ${log[i_lim_${a}_ratelimit_burst]} \
            -j LOG ${LOG_OPTS} \"[ipt-i]lim-${a}${id}-p${p}: \""
          if [[ -n "${lim[${a}_udp_on]}" ]]; then
            [[ "${LOG_LEVEL}" > "${log[i_lim_${a}_ratelimit_lvl]}" ]] && echo -e "\
              -4 -A i-lim-${a}${id} -p udp -m udp --dport ${p} \
              -m limit --limit ${log[i_lim_${a}_ratelimit_limit]} --limit-burst ${log[i_lim_${a}_ratelimit_burst]} \
              -j LOG ${LOG_OPTS} \"[ipt-i]lim-${a}${id}-p${p}: \""
            [[ "${LOG_LEVEL}" > "${log[i_lim_${a}_ratelimit_lvl]}" ]] && echo -e "\
              -6 -A i-lim-${a}${id} -p udp -m udp --dport ${p} \
              -m limit --limit ${log[i_lim_${a}_ratelimit_limit]} --limit-burst ${log[i_lim_${a}_ratelimit_burst]} \
              -j LOG ${LOG_OPTS} \"[ipt-i]lim-${a}${id}-p${p}: \""
          fi

          # Deny when limits exceeded
          if [[ "${deny_target_drop}" != "true" ]]; then
            echo -e "-4 -A i-lim-${a}${id} -p tcp -m tcp --dport ${p} -j REJECT --reject-with icmp-admin-prohibited"
            echo -e "-6 -A i-lim-${a}${id} -p tcp -m tcp --dport ${p} -j REJECT --reject-with icmp6-adm-prohibited"
            if [[ -n "${lim[${a}_udp_on]}" ]]; then
              echo -e "-4 -A i-lim-${a}${id} -p udp -m udp --dport ${p} -j REJECT --reject-with icmp-admin-prohibited"
              echo -e "-6 -A i-lim-${a}${id} -p udp -m udp --dport ${p} -j REJECT --reject-with icmp6-adm-prohibited"
            fi
          else
            echo -e "-A i-lim-${a}${id} -p tcp -m tcp --dport ${p} -j DROP"
            if [[ -n "${lim[${a}_udp_on]}" ]]; then
              echo -e "-A i-lim-${a}${id} -p udp -m udp --dport ${p} -j DROP"
            fi
          fi
        done
      else
        # No ports configured: limit all inbound traffic from the AS/CC
        if [[ -n "${lim[${a}_ip_on]}" ]]; then
          echo -e "-4 -A i-lim-${a}${id} \
            -m hashlimit --hashlimit ${lim[${a}_ip_rate]} --hashlimit-burst ${lim[${a}_ip_burst]} \
            --hashlimit-mode srcip --hashlimit-name ${a}${id}_ip4 \
            -m limit --limit ${lim[${a}_rate]} --limit-burst ${lim[${a}_burst]} \
            -j RETURN"
          echo -e "-6 -A i-lim-${a}${id} \
            -m hashlimit --hashlimit ${lim[${a}_ip_rate]} --hashlimit-burst ${lim[${a}_ip_burst]} \
            --hashlimit-mode srcip --hashlimit-name ${a}${id}_ip6 \
            -m limit --limit ${lim[${a}_rate]} --limit-burst ${lim[${a}_burst]} \
            -j RETURN"
        else
          echo -e "-A i-lim-${a}${id} \
            -m limit --limit ${lim[${a}_rate]} --limit-burst ${lim[${a}_burst]} \
            -j RETURN"
        fi

        [[ "${LOG_LEVEL}" > "${log[i_lim_${a}_ratelimit_lvl]}" ]] && echo -e "\
          -4 -A i-lim-${a}${id} \
          -m limit --limit ${log[i_lim_${a}_ratelimit_limit]} --limit-burst ${log[i_lim_${a}_ratelimit_burst]} \
          -j LOG ${LOG_OPTS} \"[ipt-i]lim-${a}${id}: \""
        [[ "${LOG_LEVEL}" > "${log[i_lim_${a}_ratelimit_lvl]}" ]] && echo -e "\
          -6 -A i-lim-${a}${id} \
          -m limit --limit ${log[i_lim_${a}_ratelimit_limit]} --limit-burst ${log[i_lim_${a}_ratelimit_burst]} \
          -j LOG ${LOG_OPTS} \"[ipt-i]lim-${a}${id}: \""

        if [[ "${deny_target_drop}" != "true" ]]; then
          echo -e "-4 -A i-lim-${a}${id} -j REJECT --reject-with icmp-admin-prohibited"
          echo -e "-6 -A i-lim-${a}${id} -j REJECT --reject-with icmp6-adm-prohibited"
        else
          echo -e "-A i-lim-${a}${id} -j DROP"
        fi
      fi

      # Allow unmatched traffic (e.g., other ports when ports are scoped)
      echo -e "-A i-lim-${a}${id} -j RETURN"
    done

    # Dispatcher return
    echo -e "-A i-lim-${a} -j RETURN"
  fi
done

echo -ne '\n'
