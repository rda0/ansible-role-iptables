#!/bin/bash
set -euo pipefail

CONF=/etc/iptables

function debug {
    if [[ "${DEBUG:-0}" > 0 ]]; then
        >&2 echo "${@}"
    fi
}

# Load config to get lim_as[*] / lim_cc[*]
. "${CONF}/iptables.conf"

CACHE_DIR="${CONF}/as-cache"
mkdir -p "${CACHE_DIR}" 2>/dev/null || true

# Helper: fetch subnets (text/plain) using xh preferred, fallback to curl.
# On failure, try cache; log to stderr and skip AS/CC if nothing available.
fetch_subnets() {
  local a="$1"
  local id="$2"
  local url=""
  local cache_file=""

  if [[ "${a}" == "as" ]]; then
    url="${lim[as_server]}/v1/as/n/AS${id}/subnets"
    cache_file="${CACHE_DIR}/AS${id}.subnets"
  else
    url="${lim[cc_server]}/v1/as/country/${id}/subnets"
    cache_file="${CACHE_DIR}/cc${id}.subnets"
  fi

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
    if [[ "${a}" == "as" ]]; then
      >&2 echo "WARN: iptoasn fetch failed for AS${id}, using cache ${cache_file}"
    else
      >&2 echo "WARN: iptoasn fetch failed for cc${id}, using cache ${cache_file}"
    fi
    cat "${cache_file}"
    return 0
  fi

  if [[ "${a}" == "as" ]]; then
    >&2 echo "ERROR: unable to obtain subnets for AS${id}; skipping refresh for this AS"
  else
    >&2 echo "ERROR: unable to obtain subnets for cc${id}; skipping refresh for this CC"
  fi
  return 1
}

# Prepare restore script
tmpfile="$(mktemp)"
trap 'rm -f "${tmpfile}"' EXIT

{
  for a in as cc; do
    # Only act if enabled
    [[ -z "${lim[${a}_on]}" ]] && continue

    # Ensure aggregated sets exist and are wired
    /sbin/ipset -exist create "${a}" list:set

    for ID in ${lim[${a}_list]}; do
      if [[ "${a}" == "as" ]]; then
        id="$(echo "${ID}" | sed 's/^[Aa][Ss]//; s/[^0-9]//g')"
      else
        id="$(echo "${ID}" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z]//g')"
      fi
      [[ -z "${id}" ]] && continue

      # Ensure sets exist
      if [[ " ${lim[${a}_large]} " == *" ${id} "* ]]; then
        # factor 2
        #/sbin/ipset -exist create "${a}${id}_4" hash:net family inet  hashsize 2048 maxelem 131072
        #/sbin/ipset -exist create "${a}${id}_6" hash:net family inet6 hashsize 2048 maxelem 131072
        # factor 4
        /sbin/ipset -exist create "${a}${id}_4" hash:net family inet  hashsize 4096 maxelem 262144
        /sbin/ipset -exist create "${a}${id}_6" hash:net family inet6 hashsize 4096 maxelem 262144
      else
        # uses the default hashsize 1024 maxelem 65536
        /sbin/ipset -exist create "${a}${id}_4" hash:net family inet
        /sbin/ipset -exist create "${a}${id}_6" hash:net family inet6
      fi

      # Wire membership (no nested list:set in overall set)
      /sbin/ipset -exist add    "${a}"         "${a}${id}_4"      >/dev/null 2>&1 || true
      /sbin/ipset -exist add    "${a}"         "${a}${id}_6"      >/dev/null 2>&1 || true

      subnets="$(fetch_subnets "${a}" "${id}" || true)"
      if [[ -z "${subnets}" ]]; then
        if [[ "${a}" == "as" ]]; then
          >&2 echo "WARN: no data for AS${id}; leaving current set content unchanged"
        else
          >&2 echo "WARN: no data for cc${id}; leaving current set content unchanged"
        fi
        continue
      fi

      # Flush and repopulate leaf sets
      echo "flush ${a}${id}_4"
      echo "flush ${a}${id}_6"
      while IFS= read -r prefix; do
        [[ -z "${prefix}" ]] && continue
        if [[ "${prefix}" == *:* ]]; then
          [[ "${DEBUG}" > 1 ]] && >&2 echo "add ${a}${id}_6 ${prefix} -exist"
          echo "add ${a}${id}_6 ${prefix} -exist"
        else
          [[ "${DEBUG}" > 1 ]] && >&2 echo "add ${a}${id}_6 ${prefix} -exist"
          echo "add ${a}${id}_4 ${prefix} -exist"
        fi
      done <<< "${subnets}"
    done
  done
} > "${tmpfile}"

# Apply refresh atomically
if [[ -s "${tmpfile}" ]]; then
  debug "Refreshing AS/CC ipsets"
  /sbin/ipset restore -f "${tmpfile}"
else
  >&2 echo "WARN: ipset-refresh: nothing to update (no data)."
fi
