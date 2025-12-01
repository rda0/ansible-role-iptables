#!/bin/bash

CONF=/etc/iptables
SBIN=/usr/local/sbin
ERROR=0
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

# load all variables from config (settings, intefaces, networks, ports)

debug "load config"
. "${CONF}/iptables.conf"

# generate new ipsets and rules from the configuration

debug "generate ipsets"
>"${IPSETS_GENERATED}"

for f in ${CONF}/ipsets.d/*; do
  debug "generate ${f}"
  . "${f}" >> "${IPSETS_GENERATED}"
done

debug "generate iptables"
>"${RULES_GENERATED}"

for f in ${CONF}/rules.d/*; do
  debug "generate ${f}"
  . "${f}" >> "${RULES_GENERATED}"
done

# flush iptables and ipsets
# this step is needed in the case when the systemd service is in a failed state,
# we always need to start with empty ip- and rulesets.

debug "flush iptables"
. "${SBIN}/iptables-flush"

debug "flush ipsets"
. "${SBIN}/ipset-flush"

# load the generated ipsets and rules

debug "load generated ipsets"
/sbin/ipset restore -f "${IPSETS_GENERATED}"

if [ "${?}" != "0" ]; then
    ERROR=1
    >&2 echo "error loading generated ipsets"
fi

debug "load generated ipv4 rules"
/sbin/iptables-restore "${RULES_GENERATED}"

if [ "${?}" != "0" ]; then
    ERROR=1
    >&2 echo "error loading generated iptables"
fi

debug "load generated ipv6 rules"
/sbin/ip6tables-restore "${RULES_GENERATED}"

if [ "${?}" != "0" ]; then
    ERROR=1
    >&2 echo "error loading generated ip6tables"
fi

# if any of the previous load operations fails, restore the dumped ipsets and rules
# of the last working configuration and put the systemd service in a failed state.
# the active working configuration is dumped before the systemd service is stopped
# and after a successful start using the generated ipsets and rules.

if [ "${ERROR}" != "0" ]; then
    >&2 echo "restoring dumped configuration"
    . "${SBIN}/iptables-flush"
    . "${SBIN}/ipset-flush"
    /sbin/ipset restore -f "${IPSETS_DUMPED}"
    /sbin/iptables-restore "${RULES_4_DUMPED}"
    /sbin/ip6tables-restore "${RULES_6_DUMPED}"
    exit 1
else
    debug "dump active ipsets"
    /sbin/ipset save > "${IPSETS_DUMPED}"
    debug "dump active iptables"
    /sbin/iptables-save > "${RULES_4_DUMPED}"
    /sbin/ip6tables-save > "${RULES_6_DUMPED}"
fi
