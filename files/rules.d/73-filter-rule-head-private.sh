#!/bin/bash

if [[ "${deny_i_prv}" == "true" ]]; then
  for c in i f; do
    [[ "${c}" == "i" ]] && chain="INPUT  " && l="${log[i_any_s_prv_lvl]}"
    [[ "${c}" == "f" ]] && chain="FORWARD" && l="${log[f_any_s_prv_lvl]}"
    echo -e "-N ${c}-net-prv"
    echo -e "# Anything coming from the Internet should have a real Internet address"
    for v in 4 6; do
      # TODO: Deactivated code (for internal/external interfaces)
      #for i in ${if_ext}; do
      #  echo -e "-${v} -A ${chain} -m set --match-set prv${v} src -i ${i} -j ${c}-net-prv"
      #done
      #for i in ${if_br_ext}; do
      #  echo -e "-${v} -A ${chain} -m set --match-set prv${v} src -m physdev --physdev-in ${i} -j ${c}-net-prv"
      #done
      echo -e "-${v} -A ${chain} -m set --match-set prv${v} src -j ${c}-net-prv"
      echo -e "# Everything in the private address range gets denied, except our allowed ipv${v} networks"
      [[ "${LOG_LEVEL}" > ${l} ]] && echo -e "-${v} -A ${c}-net-prv -m set ! --match-set prvcan${v} src \
                                              -m limit --limit ${log[${c}_any_s_prv_limit]} --limit-burst ${log[${c}_any_s_prv_burst]} \
                                              -j LOG ${LOG_OPTS} \"[ipt-${c}]any-s-prv: \""
      echo -e "-${v} -A ${c}-net-prv -m set ! --match-set prvcan${v} src -j ${c}-deny"
    done
    echo -e "-A ${c}-net-prv -j RETURN"
  done
fi

echo -ne '\n'
