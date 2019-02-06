#!/bin/bash

CONF=/etc/iptables
SBIN=/usr/local/sbin
RULES_4_DUMPED="${CONF}/dumped.4.rules"
RULES_6_DUMPED="${CONF}/dumped.6.rules"
RULES_GENERATED="${CONF}/generated.rules"
IPSETS_DUMPED="${CONF}/dumped.ipsets"
IPSETS_GENERATED="${CONF}/generated.ipsets"

# prints messages when in debug mode
function debug {
    if [[ "${DEBUG}" > 0 ]]; then
        >&2 echo "${@}"
    fi
}

# dump the active configuration

debug "dump active ipsets"
/sbin/ipset save > "${IPSETS_DUMPED}"
debug "dump active iptables"
/sbin/iptables-save > "${RULES_4_DUMPED}"
/sbin/ip6tables-save > "${RULES_6_DUMPED}"

# flush iptables and ipsets

debug "flush iptables (required to destroy sets)"
. "${SBIN}/iptables-flush"

debug "flush ipsets"
. "${SBIN}/ipsets-flush"
