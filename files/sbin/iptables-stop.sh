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

debug "save last ipsets"
/sbin/ipset save > "${IPSETS_LAST}"
debug "save last iptables"
/sbin/iptables-save > "${RULES_4_LAST}"
/sbin/ip6tables-save > "${RULES_6_LAST}"

debug "flush iptables (required to destroy sets)"
. "${SBIN}/iptables-flush"

debug "flush ipsets"
. "${SBIN}/ipsets-flush"
