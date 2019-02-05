#!/bin/bash

CONF=/etc/iptables
SBIN=/usr/local/sbin
ERROR=0
RULES_4_LAST="${CONF}/last.4.rules"
RULES_6_LAST="${CONF}/last.6.rules"
RULES_NEW="${CONF}/new.rules"
IPSETS_LAST="${CONF}/last.ipsets"
IPSETS_NEW="${CONF}/new.ipsets"

# prints messages when in debug mode
function debug {
    if [[ "${DEBUG}" > 0 ]]; then
        >&2 echo "${@}"
    fi
}

debug "load config"
. "${CONF}/iptables.conf"

debug "generate ipsets"
>"${IPSETS_NEW}"

for f in ${CONF}/ipsets.d/*; do
  debug "generate ${f}"
  . "${f}" >> "${IPSETS_NEW}"
done

debug "generate iptables"
>"${RULES_NEW}"

for f in ${CONF}/rules.d/*; do
  debug "generate ${f}"
  . "${f}" >> "${RULES_NEW}"
done

#debug "create ipsets"
#. "${CONF}/ipsets-create"

debug "restore ipsets"
/sbin/ipset restore -f "${IPSETS_NEW}"

if [ "${?}" != "0" ]; then
    ERROR=1
    >&2 echo "error restoring new ipsets"
fi

debug "restore ipv4 rules"
/sbin/iptables-restore "${RULES_NEW}"

if [ "${?}" != "0" ]; then
    ERROR=1
    >&2 echo "error restoring new iptables"
fi

debug "restore ipv6 rules"
/sbin/ip6tables-restore "${RULES_NEW}"

if [ "${?}" != "0" ]; then
    ERROR=1
    >&2 echo "error restoring new ip6tables"
fi

if [ "${ERROR}" != "0" ]; then
    >&2 echo "restoring last configuration"
    . "${SBIN}/iptables-flush"
    . "${SBIN}/ipsets-flush"
    /sbin/ipset restore -f "${IPSETS_LAST}"
    /sbin/iptables-restore "${RULES_4_LAST}"
    /sbin/ip6tables-restore "${RULES_6_LAST}"
    exit 1
fi
