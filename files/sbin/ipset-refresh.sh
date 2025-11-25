#!/bin/bash
set -euo pipefail

CONF=/etc/iptables

function debug {
    if [[ "${DEBUG:-0}" > 0 ]]; then
        >&2 echo "${@}"
    fi
}

# Load config to get lim_as[*]
. "${CONF}/iptables.conf"

# Only act if enabled
[[ -z "${lim_as[on]}" ]] && exit 0

CACHE_DIR="${CONF}/as-cache"
mkdir -p "${CACHE_DIR}" 2>/dev/null || true

# Helper: fetch subnets (text/plain) using xh preferred, fallback to curl.
# On failure, try cache; log to stderr and skip AS if nothing available.
fetch_subnets() {
  local as_num="$1"
  local url="${lim_as[server]}/v1/as/n/AS${as_num}/subnets"
  local cache_file="${CACHE_DIR}/AS${as_num}.subnets"

  local data=""
  if command -v xh >/dev/null 2>&1; then
    data="$(xh -b -I "${url}" Accept:text/plain 2>/dev/null || true)"
  fi
  if [[ -z "${data}" ]]; then
    data="$(curl -fsSL -H 'Accept: text/plain' "${url}" 2>/dev/null || true)"
  fi

  if [[ -n "${data}" ]]; then
    data="$(printf "%s\n" "${data}" | tr -d '\r' | sed '/^[[:space:]]*$/d')"
  fi

  if [[ -n "${data}" ]]; then
    printf "%s\n" "${data}" > "${cache_file}.tmp" 2>/dev/null || true
    mv -f "${cache_file}.tmp" "${cache_file}" 2>/dev/null || true
    printf "%s\n" "${data}"
    return 0
  fi

  if [[ -s "${cache_file}" ]]; then
    >&2 echo "WARN: iptoasn fetch failed for AS${as_num}, using cache ${cache_file}"
    cat "${cache_file}"
    return 0
  fi

  >&2 echo "ERROR: unable to obtain subnets for AS${as_num}; skipping refresh for this AS"
  return 1
}

# Ensure aggregated sets exist and are wired
/sbin/ipset -exist create as list:set

# Prepare restore script
tmpfile="$(mktemp)"
trap 'rm -f "${tmpfile}"' EXIT

{
  for ASN in ${lim_as[list]}; do
    as_num="$(echo "${ASN}" | sed 's/^[Aa][Ss]//; s/[^0-9]//g')"
    [[ -z "${as_num}" ]] && continue

    # Ensure sets exist
    /sbin/ipset -exist create "as${as_num}_4" hash:net family inet
    /sbin/ipset -exist create "as${as_num}_6" hash:net family inet6
    # Wire membership (no nested list:set in overall set)
    /sbin/ipset -exist add    "as"            "as${as_num}_4"      >/dev/null 2>&1 || true
    /sbin/ipset -exist add    "as"            "as${as_num}_6"      >/dev/null 2>&1 || true

    subnets="$(fetch_subnets "${as_num}" || true)"
    if [[ -z "${subnets}" ]]; then
      >&2 echo "WARN: no data for AS${as_num}; leaving current set content unchanged"
      continue
    fi

    # Flush and repopulate leaf sets
    echo "flush as${as_num}_4"
    echo "flush as${as_num}_6"
    while IFS= read -r prefix; do
      [[ -z "${prefix}" ]] && continue
      if [[ "${prefix}" == *:* ]]; then
        echo "add as${as_num}_6 ${prefix} -exist"
      else
        echo "add as${as_num}_4 ${prefix} -exist"
      fi
    done <<< "${subnets}"
  done
} > "${tmpfile}"

# Apply refresh atomically
if [[ -s "${tmpfile}" ]]; then
  debug "Refreshing AS ipsets"
  /sbin/ipset restore -f "${tmpfile}"
else
  >&2 echo "WARN: ipset-refresh: nothing to update (no data)."
fi
