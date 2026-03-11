#!/bin/bash

# Generate ipsets for AS/CC-based rate limiting.
# Requires lim_as[*] / lim_cc[*] configuration in iptables.conf (already loaded by iptables-start).

CONF=/etc/iptables
CACHE_DIR="${CONF}/as-cache"
mkdir -p "${CACHE_DIR}" 2>/dev/null || true

for a in as cc; do
  # Only act if enabled
  [[ -z "${lim[${a}_on]}" ]] && continue

  # Overall set (includes leaf v4/v6 sets for every AS/CC; NOT nested list:set)
  echo -e "create ${a} list:set"

  # Helper: fetch subnets (text/plain) using xh preferred, fallback to curl.
  # On failure, use cache; if no cache, fallback to dumped.ipsets; log to stderr.
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
      if [[ "${a}" == "as" ]]; then
        >&2 echo "WARN: iptoasn fetch failed for AS${id}, using cache ${cache_file}"
      else
        >&2 echo "WARN: iptoasn fetch failed for cc${id}, using cache ${cache_file}"
      fi
      cat "${cache_file}"
      return 0
    fi

    # Last resort: try to read currently dumped ipsets and filter this AS/CC
    local dumped="${CONF}/dumped.ipsets"
    if [[ -s "${dumped}" ]]; then
      if [[ "${a}" == "as" ]]; then
        >&2 echo "WARN: no cache for AS${id}, trying dumped.ipsets"
      else
        >&2 echo "WARN: no cache for cc${id}, trying dumped.ipsets"
      fi
      while IFS=' ' read -r w1 w2 w3 rest; do
        if [[ "${w1}" == "add" && ( "${w2}" == "${a}${id}_4" || "${w2}" == "${a}${id}_6" ) ]]; then
          printf "%s\n" "${w3}"
        fi
      done < "${dumped}"
      return 0
    fi

    if [[ "${a}" == "as" ]]; then
      >&2 echo "ERROR: unable to obtain subnets for AS${id}; no fetch, cache, or dump available"
    else
      >&2 echo "ERROR: unable to obtain subnets for cc${id}; no fetch, cache, or dump available"
    fi
    return 1
  }

  for ID in ${lim[${a}_list]}; do
    if [[ "${a}" == "as" ]]; then
      # normalize ASN: strip any leading AS/as and keep only digits
      id="$(echo "${ID}" | sed 's/^[Aa][Ss]//; s/[^0-9]//g')"
      [[ -z "${id}" ]] && continue
    else
      # normalize CC: keep A-Z only, upper-case
      id="$(echo "${ID}" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z]//g')"
      [[ -z "${id}" ]] && continue
    fi

    # Create per-ID sets
    if [[ " ${lim[${a}_large]} " == *" ${id} "* ]]; then
      echo -e "create ${a}${id}_4 hash:net family inet  hashsize 2048 maxelem 131072"
      echo -e "create ${a}${id}_6 hash:net family inet6 hashsize 2048 maxelem 131072"
    else
      echo -e "create ${a}${id}_4 hash:net family inet"
      echo -e "create ${a}${id}_6 hash:net family inet6"
    fi

    # Include leaf sets in overall list
    echo -e "add ${a}           ${a}${id}_4"
    echo -e "add ${a}           ${a}${id}_6"

    ## Obtain subnets
    #subnets="$(fetch_subnets "${a}" "${id}")"
    #if [[ -n "${subnets}" ]]; then
    #  while IFS= read -r prefix; do
    #    [[ -z "${prefix}" ]] && continue
    #    if [[ "${prefix}" == *:* ]]; then
    #      # IPv6
    #      echo -e "add ${a}${id}_6 ${prefix} -exist"
    #    else
    #      # IPv4
    #      echo -e "add ${a}${id}_4 ${prefix} -exist"
    #    fi
    #  done <<< "${subnets}"
    #else
    #  >&2 echo "WARN: no subnets known for ${a}${id}; sets created empty"
    #fi
  done
done
