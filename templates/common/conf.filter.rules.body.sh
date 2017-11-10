#!/bin/bash

. /etc/iptables/iptables.conf

# Internet (default)
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules: Internet (default)"

if [ -n "${I_TCP_INET}" ] ; then
  for PORT in ${I_TCP_INET}; do
    [[ "${DEBUG}" > 1 ]] && >&2 echo "-A INPUT -p tcp --dport ${PORT} -m conntrack --ctstate NEW -j ACCEPT"
    echo "-A INPUT -p tcp --dport ${PORT} -m conntrack --ctstate NEW -j ACCEPT"
  done
fi

if [ -n "${I_UDP_INET}" ] ; then
  for PORT in ${I_UDP_INET}; do
    [[ "${DEBUG}" > 1 ]] && >&2 echo "-A INPUT -p udp --dport ${PORT} -j ACCEPT"
    echo "-A INPUT -p udp --dport ${PORT} -j ACCEPT"
  done
fi

if [ -n "${O_TCP_INET}" ] ; then
  for PORT in ${O_TCP_INET}; do
    [[ "${DEBUG}" > 1 ]] && >&2 echo "-A OUTPUT -p tcp --dport ${PORT} -m conntrack --ctstate NEW -j ACCEPT"
    echo "-A OUTPUT -p tcp --dport ${PORT} -m conntrack --ctstate NEW -j ACCEPT"
  done
fi

if [ -n "${O_UDP_INET}" ] ; then
  for PORT in ${O_UDP_INET}; do
    [[ "${DEBUG}" > 1 ]] && >&2 echo "-A OUTPUT -p udp --dport "${PORT}" -j ACCEPT"
    echo "-A OUTPUT -p udp --dport "${PORT}" -j ACCEPT"
  done
fi

# Network (custom), host specific
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules: Network (custom), host specific"

if [ -n "${I_TCP}" ] ; then
  for PORT in ${I_TCP}; do
    [[ "${DEBUG}" > 1 ]] && >&2 echo "-A INPUT -m set --match-set ${SET_CUS} src -p tcp --dport ${PORT} -m conntrack --ctstate NEW -j ACCEPT"
    echo "-A INPUT -m set --match-set ${SET_CUS} src -p tcp --dport ${PORT} -m conntrack --ctstate NEW -j ACCEPT"
  done
fi

if [ -n "${I_UDP}" ] ; then
  for PORT in ${I_UDP}; do
    [[ "${DEBUG}" > 1 ]] && >&2 echo "A INPUT -m set --match-set ${SET_CUS} src -p udp --dport ${PORT} -j ACCEPT"
    echo "-A INPUT -m set --match-set ${SET_CUS} src -p udp --dport ${PORT} -j ACCEPT"
  done
fi

if [ -n "${O_TCP}" ] ; then
  for PORT in ${O_TCP}; do
    [[ "${DEBUG}" > 1 ]] && >&2 echo "-A OUTPUT -m set --match-set ${SET_CUS} dst -p tcp --dport ${PORT} -m conntrack --ctstate NEW -j ACCEPT"
    echo "-A OUTPUT -m set --match-set ${SET_CUS} dst -p tcp --dport ${PORT} -m conntrack --ctstate NEW -j ACCEPT"
  done
fi

if [ -n "${O_UDP}" ] ; then
  for PORT in ${O_UDP}; do
    [[ "${DEBUG}" > 1 ]] && >&2 echo "-A OUTPUT -m set --match-set ${SET_CUS} dst -p udp --dport "${PORT}" -j ACCEPT"
    echo "-A OUTPUT -m set --match-set ${SET_CUS} dst -p udp --dport "${PORT}" -j ACCEPT"
  done
fi

# Network (trusted), includes: Trusted, Server, Admin
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules: Network (trusted), includes: Trusted, Server, Admin"

if [ -n "${I_TCP_TRU}" ] ; then
  for PORT in ${I_TCP_TRU}; do
    [[ "${DEBUG}" > 1 ]] && >&2 echo "-A INPUT -m set --match-set ${SET_TRU} src -p tcp --dport ${PORT} -m conntrack --ctstate NEW -j ACCEPT"
    echo "-A INPUT -m set --match-set ${SET_TRU} src -p tcp --dport ${PORT} -m conntrack --ctstate NEW -j ACCEPT"
  done
fi

if [ -n "${I_UDP_TRU}" ] ; then
  for PORT in ${I_UDP_TRU}; do
    [[ "${DEBUG}" > 1 ]] && >&2 echo "-A INPUT -m set --match-set ${SET_TRU} src -p udp --dport ${PORT} -j ACCEPT"
    echo "-A INPUT -m set --match-set ${SET_TRU} src -p udp --dport ${PORT} -j ACCEPT"
  done
fi

if [ -n "${O_TCP_TRU}" ] ; then
  for PORT in ${O_TCP_TRU}; do
    [[ "${DEBUG}" > 1 ]] && >&2 echo "-A OUTPUT -m set --match-set ${SET_TRU} dst -p tcp --dport ${PORT} -m conntrack --ctstate NEW -j ACCEPT"
    echo "-A OUTPUT -m set --match-set ${SET_TRU} dst -p tcp --dport ${PORT} -m conntrack --ctstate NEW -j ACCEPT"
  done
fi

if [ -n "${O_UDP_TRU}" ] ; then
  for PORT in ${O_UDP_TRU}; do
    [[ "${DEBUG}" > 1 ]] && >&2 echo "-A OUTPUT -m set --match-set ${SET_TRU} dst -p udp --dport "${PORT}" -j ACCEPT"
    echo "-A OUTPUT -m set --match-set ${SET_TRU} dst -p udp --dport "${PORT}" -j ACCEPT"
  done
fi

# Network (server)
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules: Network (server)"

if [ -n "${I_TCP_SRV}" ] ; then
  for PORT in ${I_TCP_SRV}; do
    [[ "${DEBUG}" > 1 ]] && >&2 echo "-A INPUT -m set --match-set ${SET_SRV} src -p tcp --dport ${PORT} -m conntrack --ctstate NEW -j ACCEPT"
    echo "-A INPUT -m set --match-set ${SET_SRV} src -p tcp --dport ${PORT} -m conntrack --ctstate NEW -j ACCEPT"
  done
fi

if [ -n "${I_UDP_SRV}" ] ; then
  for PORT in ${I_UDP_SRV}; do
    [[ "${DEBUG}" > 1 ]] && >&2 echo "-A INPUT -m set --match-set ${SET_SRV} src -p udp --dport ${PORT} -j ACCEPT"
    echo "-A INPUT -m set --match-set ${SET_SRV} src -p udp --dport ${PORT} -j ACCEPT"
  done
fi

if [ -n "${O_TCP_SRV}" ] ; then
  for PORT in ${O_TCP_SRV}; do
    [[ "${DEBUG}" > 1 ]] && >&2 echo "-A OUTPUT -m set --match-set ${SET_SRV} dst -p tcp --dport ${PORT} -m conntrack --ctstate NEW -j ACCEPT"
    echo "-A OUTPUT -m set --match-set ${SET_SRV} dst -p tcp --dport ${PORT} -m conntrack --ctstate NEW -j ACCEPT"
  done
fi

if [ -n "${O_UDP_SRV}" ] ; then
  for PORT in ${O_UDP_SRV}; do
    [[ "${DEBUG}" > 1 ]] && >&2 echo "-A OUTPUT -m set --match-set ${SET_SRV} dst -p udp --dport "${PORT}" -j ACCEPT"
    echo "-A OUTPUT -m set --match-set ${SET_SRV} dst -p udp --dport "${PORT}" -j ACCEPT"
  done
fi

# Admin
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules: Admin"

if [ -n "${I_TCP_ADM}" ] ; then
  for PORT in ${I_TCP_ADM}; do
    [[ "${DEBUG}" > 1 ]] && >&2 echo "-A INPUT -m set --match-set ${SET_ADM} src -p tcp --dport ${PORT} -m conntrack --ctstate NEW -j ACCEPT"
    echo "-A INPUT -m set --match-set ${SET_ADM} src -p tcp --dport ${PORT} -m conntrack --ctstate NEW -j ACCEPT"
  done
fi

if [ -n "${I_UDP_ADM}" ] ; then
  for PORT in ${I_UDP_ADM}; do
    [[ "${DEBUG}" > 1 ]] && >&2 echo "-A INPUT -m set --match-set ${SET_ADM} src -p udp --dport ${PORT} -j ACCEPT"
    echo "-A INPUT -m set --match-set ${SET_ADM} src -p udp --dport ${PORT} -j ACCEPT"
  done
fi

if [ -n "${O_TCP_ADM}" ] ; then
  for PORT in ${O_TCP_ADM}; do
    [[ "${DEBUG}" > 1 ]] && >&2 echo "-A OUTPUT -m set --match-set ${SET_ADM} dst -p tcp --dport ${PORT} -m conntrack --ctstate NEW -j ACCEPT"
    echo "-A OUTPUT -m set --match-set ${SET_ADM} dst -p tcp --dport ${PORT} -m conntrack --ctstate NEW -j ACCEPT"
  done
fi

if [ -n "${O_UDP_ADM}" ] ; then
  for PORT in ${O_UDP_ADM}; do
    [[ "${DEBUG}" > 1 ]] && >&2 echo "-A OUTPUT -m set --match-set ${SET_ADM} dst -p udp --dport "${PORT}" -j ACCEPT"
    echo "-A OUTPUT -m set --match-set ${SET_ADM} dst -p udp --dport "${PORT}" -j ACCEPT"
  done
fi

