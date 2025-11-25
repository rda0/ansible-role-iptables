#!/bin/bash

# Generate ipsets for AS-based rate limiting.
# Requires lim_as[*] configuration in iptables.conf (already loaded by iptables-start).

CONF=/etc/iptables
CACHE_DIR="${CONF}/as-cache"
mkdir -p "${CACHE_DIR}" 2>/dev/null || true

# Only act if enabled
[[ -z "${lim_as[on]}" ]] && return

# Overall AS set (includes leaf v4/v6 sets for every AS; NOT nested list:set)
echo -e "create as list:set"

# Helper: fetch subnets (text/plain) using xh preferred, fallback to curl.
# On failure, use cache; if no cache, fallback to dumped.ipsets; log to stderr.
fetch_subnets() {
  local as_num="$1"
  local url="${lim_as[server]}/v1/as/n/AS${as_num}/subnets"
  local cache_file="${CACHE_DIR}/AS${as_num}.subnets"

  # Prefer xh
  local data=""
  if command -v xh >/dev/null 2>&1; then
    data="$(xh -b -I "${url}" Accept:text/plain 2>/dev/null || true)"
  fi
  # Fallback to curl
  if [[ -z "${data}" ]]; then
    data="$(curl -fsSL -H 'Accept: text/plain' "${url}" 2>/dev/null || true)"
  fi

  # Normalize lines: remove CR, drop blank lines
  if [[ -n "${data}" ]]; then
    data="$(printf "%s\n" "${data}" | tr -d '\r' | sed '/^[[:space:]]*$/d')"
  fi

  if [[ -n "${data}" ]]; then
    printf "%s\n" "${data}" > "${cache_file}.tmp" 2>/dev/null
    mv -f "${cache_file}.tmp" "${cache_file}" 2>/dev/null
    printf "%s\n" "${data}"
    return 0
  fi

  # Fallback to cache if available
  if [[ -s "${cache_file}" ]]; then
    >&2 echo "WARN: iptoasn fetch failed for AS${as_num}, using cache ${cache_file}"
    cat "${cache_file}"
    return 0
  fi

  # Last resort: try to read currently dumped ipsets and filter this AS
  local dumped="${CONF}/dumped.ipsets"
  if [[ -s "${dumped}" ]]; then
    >&2 echo "WARN: no cache for AS${as_num}, trying dumped.ipsets"
    while IFS=' ' read -r w1 w2 w3 rest; do
      if [[ "${w1}" == "add" && ( "${w2}" == "as${as_num}_4" || "${w2}" == "as${as_num}_6" ) ]]; then
        printf "%s\n" "${w3}"
      fi
    done < "${dumped}"
    return 0
  fi

  >&2 echo "ERROR: unable to obtain subnets for AS${as_num}; no fetch, cache, or dump available"
  return 1
}

for ASN in ${lim_as[list]}; do
  # normalize ASN: strip any leading AS/as and keep only digits
  as_num="$(echo "${ASN}" | sed 's/^[Aa][Ss]//; s/[^0-9]//g')"
  [[ -z "${as_num}" ]] && continue

  # Create per-AS sets
  echo -e "create as${as_num}_4 hash:net family inet"
  echo -e "create as${as_num}_6 hash:net family inet6"

  # Include leaf sets in as list
  echo -e "add as           as${as_num}_4"
  echo -e "add as           as${as_num}_6"

  ## Obtain subnets
  #subnets="$(fetch_subnets "${as_num}")"
  #if [[ -n "${subnets}" ]]; then
  #  while IFS= read -r prefix; do
  #    [[ -z "${prefix}" ]] && continue
  #    if [[ "${prefix}" == *:* ]]; then
  #      # IPv6
  #      echo -e "add as${as_num}_6 ${prefix} -exist"
  #    else
  #      # IPv4
  #      echo -e "add as${as_num}_4 ${prefix} -exist"
  #    fi
  #  done <<< "${subnets}"
  #else
  #  >&2 echo "WARN: no subnets known for AS${as_num}; sets created empty"
  #fi
done
