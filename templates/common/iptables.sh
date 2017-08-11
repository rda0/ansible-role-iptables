#!/bin/bash

CONF=/etc/iptables
UP4=/etc/iptables/up.ipv4.rules
UP6=/etc/iptables/up.ipv6.rules

. "${CONF}/iptables.conf"

# flush iptables (required to destroy sets)
[[ "${DEBUG}" > 0 ]] && >&2 echo "flush iptables"
/sbin/iptables -P INPUT DROP
/sbin/iptables -P OUTPUT DROP
/sbin/iptables -P FORWARD DROP
/sbin/iptables -F
/sbin/iptables -X
/sbin/iptables -A INPUT -p tcp --dport 22 -j ACCEPT
/sbin/iptables -A OUTPUT -p tcp --sport 22 -j ACCEPT
/sbin/ip6tables -P INPUT DROP
/sbin/ip6tables -P OUTPUT DROP
/sbin/ip6tables -P FORWARD DROP
/sbin/ip6tables -F
/sbin/ip6tables -X
/sbin/ip6tables -A INPUT -p tcp --dport 22 -j ACCEPT
/sbin/ip6tables -A OUTPUT -p tcp --sport 22 -j ACCEPT
#[[ "${DEBUG}" > 0 ]] && >&2 echo "restart fail2ban"
#/bin/systemctl restart fail2ban

# make ipset config

# destroy lists first
[[ "${DEBUG}" > 0 ]] && >&2 echo "destroy ipsets"
/sbin/ipset -q destroy trusted
/sbin/ipset -q destroy trusted6
# destroy sets
/sbin/ipset -q destroy admin
/sbin/ipset -q destroy update
/sbin/ipset -q destroy server
/sbin/ipset -q destroy custom
/sbin/ipset -q destroy trustednet
/sbin/ipset -q destroy private
/sbin/ipset -q destroy private-except
/sbin/ipset -q destroy admin6
/sbin/ipset -q destroy update6
/sbin/ipset -q destroy server6
/sbin/ipset -q destroy custom6
/sbin/ipset -q destroy trustednet6
/sbin/ipset -q destroy private6
/sbin/ipset -q destroy private6-except
# create sets
[[ "${DEBUG}" > 0 ]] && >&2 echo "create ipsets"
/sbin/ipset create admin            hash:ip  family inet
/sbin/ipset create update           hash:ip  family inet
/sbin/ipset create server           hash:net family inet
/sbin/ipset create custom           hash:net family inet
/sbin/ipset create trustednet       hash:net family inet
/sbin/ipset create private          hash:net family inet
/sbin/ipset create private-except   hash:net family inet
/sbin/ipset create trusted          list:set
/sbin/ipset create admin6           hash:ip  family inet6
/sbin/ipset create update6          hash:ip  family inet6
/sbin/ipset create server6          hash:net family inet6
/sbin/ipset create custom6          hash:net family inet6
/sbin/ipset create trustednet6      hash:net family inet6
/sbin/ipset create private6         hash:net family inet6
/sbin/ipset create private6-except  hash:net family inet6
/sbin/ipset create trusted6         list:set
# dynamic blocking
/sbin/ipset --exist create block-ssh4           hash:ip  family inet  timeout 3600
/sbin/ipset --exist create block-ssh6           hash:ip  family inet6 timeout 3600
/sbin/ipset --exist create block-ssh            list:set
/sbin/ipset --exist create block-ssh-trusted4   hash:ip  family inet  timeout 600
/sbin/ipset --exist create block-ssh-trusted6   hash:ip  family inet6 timeout 600
/sbin/ipset --exist create block-ssh-trusted    list:set
/sbin/ipset --exist add block-ssh block-ssh4
/sbin/ipset --exist add block-ssh block-ssh6
/sbin/ipset --exist add block-ssh-trusted block-ssh-trusted4
/sbin/ipset --exist add block-ssh-trusted block-ssh-trusted6

# fill ipv4 sets
[[ "${DEBUG}" > 0 ]] && >&2 echo "fill ipv4 ipsets"

if [ -n "${NET4_ADMIN}" ] ; then
  for IP in ${NET4_ADMIN}; do
    [[ "${DEBUG}" > 0 ]] && >&2 echo "/sbin/ipset add admin ${IP}"
    /sbin/ipset add admin "${IP}"
  done
fi

if [ -n "${NET4_UPDATE}" ] ; then
  for IP in ${NET4_UPDATE}; do
    [[ "${DEBUG}" > 0 ]] && >&2 echo "/sbin/ipset add update ${IP}"
    /sbin/ipset add update "${IP}"
  done
fi

if [ -n "${NET4_SERVER}" ] ; then
  for NET in ${NET4_SERVER}; do
    [[ "${DEBUG}" > 0 ]] && >&2 echo "/sbin/ipset add server ${NET}"
    /sbin/ipset add server "${NET}"
  done
fi

if [ -n "${NET4_CUSTOM}" ] ; then
  for NET in ${NET4_CUSTOM}; do
    [[ "${DEBUG}" > 0 ]] && >&2 echo "/sbin/ipset add custom ${NET}"
    /sbin/ipset add custom "${NET}"
  done
fi

if [ -n "${NET4_TRUSTED}" ] ; then
  for NET in ${NET4_TRUSTED}; do
    [[ "${DEBUG}" > 0 ]] && >&2 echo "/sbin/ipset add trustednet ${NET}"
    /sbin/ipset add trustednet "${NET}"
  done
fi

if [ -n "${NET4_PRIVATE}" ] ; then
  for NET in ${NET4_PRIVATE}; do
    [[ "${DEBUG}" > 0 ]] && >&2 echo "/sbin/ipset add private ${NET}"
    /sbin/ipset add private "${NET}"
  done
fi

if [ -n "${NET4_PRIVATE_EXCEPT}" ] ; then
  for NET in ${NET4_PRIVATE_EXCEPT}; do
    [[ "${DEBUG}" > 0 ]] && >&2 echo "/sbin/ipset add private-except ${NET}"
    /sbin/ipset add private-except "${NET}"
  done
fi

[[ "${DEBUG}" > 0 ]] && >&2 echo "/sbin/ipset add trusted trustednet"
/sbin/ipset add trusted trustednet
[[ "${DEBUG}" > 0 ]] && >&2 echo "/sbin/ipset add trusted server"
/sbin/ipset add trusted server
[[ "${DEBUG}" > 0 ]] && >&2 echo "/sbin/ipset add trusted admin"
/sbin/ipset add trusted admin

# fill ipv6 sets
[[ "${DEBUG}" > 0 ]] && >&2 echo "fill ipv6 ipsets"

if [ -n "${NET6_ADMIN}" ] ; then
  for IP in ${NET6_ADMIN}; do
    [[ "${DEBUG}" > 0 ]] && >&2 echo "/sbin/ipset add admin6 ${IP}"
    /sbin/ipset add admin6 "${IP}"
  done
fi

if [ -n "${NET6_UPDATE}" ] ; then
  for IP in ${NET6_UPDATE}; do
    [[ "${DEBUG}" > 0 ]] && >&2 echo "/sbin/ipset add update6 ${IP}"
    /sbin/ipset add update6 "${IP}"
  done
fi

if [ -n "${NET6_SERVER}" ] ; then
  for NET in ${NET6_SERVER}; do
    [[ "${DEBUG}" > 0 ]] && >&2 echo "/sbin/ipset add server6 ${NET}"
    /sbin/ipset add server6 "${NET}"
  done
fi

if [ -n "${NET6_CUSTOM}" ] ; then
  for NET in ${NET6_CUSTOM}; do
    [[ "${DEBUG}" > 0 ]] && >&2 echo "/sbin/ipset add custom6 ${NET}"
    /sbin/ipset add custom6 "${NET}"
  done
fi

if [ -n "${NET6_TRUSTED}" ] ; then
  for NET in ${NET6_TRUSTED}; do
    [[ "${DEBUG}" > 0 ]] && >&2 echo "/sbin/ipset add trustednet6 ${NET}"
    /sbin/ipset add trustednet6 "${NET}"
  done
fi

if [ -n "${NET6_PRIVATE}" ] ; then
  for NET in ${NET6_PRIVATE}; do
    [[ "${DEBUG}" > 0 ]] && >&2 echo "/sbin/ipset add private6 ${NET}"
    /sbin/ipset add private6 "${NET}"
  done
fi

if [ -n "${NET6_PRIVATE_EXCEPT}" ] ; then
  for NET in ${NET6_PRIVATE_EXCEPT}; do
    [[ "${DEBUG}" > 0 ]] && >&2 echo "/sbin/ipset add private6-except ${NET}"
    /sbin/ipset add private6-except "${NET}"
  done
fi

[[ "${DEBUG}" > 0 ]] && >&2 echo "/sbin/ipset add trusted6 trustednet6"
/sbin/ipset add trusted6 trustednet6
[[ "${DEBUG}" > 0 ]] && >&2 echo "/sbin/ipset add trusted6 server6"
/sbin/ipset add trusted6 server6
[[ "${DEBUG}" > 0 ]] && >&2 echo "/sbin/ipset add trusted6 admin6"
/sbin/ipset add trusted6 admin6

# concat ipv4 rules
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules IPv4"
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules conf.nat.policy"
cat "${CONF}/conf.nat.policy" > "${UP4}"
echo -ne '\n' >> "${UP4}"
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules conf.nat.rules"
cat "${CONF}/conf.nat.rules" >> "${UP4}"
echo -ne '\nCOMMIT\n\n' >> "${UP4}"
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules conf.filter.policy"
cat "${CONF}/conf.filter.policy" >> "${UP4}"
echo -ne '\n' >> "${UP4}"
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules conf.filter.rules.head.conntrack"
"${CONF}/conf.filter.rules.head.conntrack.sh" >> "${UP4}"
echo -ne '\n' >> "${UP4}"
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules conf.filter.rules.head.ipv4.lo"
"${CONF}/conf.filter.rules.head.ipv4.lo.sh" >> "${UP4}"
echo -ne '\n' >> "${UP4}"
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules conf.filter.rules.head.lo"
cat "${CONF}/conf.filter.rules.head.lo" >> "${UP4}"
echo -ne '\n' >> "${UP4}"
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules conf.filter.rules.head.ipv4.private"
"${CONF}/conf.filter.rules.head.ipv4.private.sh" >> "${UP4}"
echo -ne '\n' >> "${UP4}"
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules conf.filter.rules.head.ipv4.icmp"
"${CONF}/conf.filter.rules.head.ipv4.icmp.sh" >> "${UP4}"
echo -ne '\n' >> "${UP4}"
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules conf.filter.rules.head.ratelimit"
"${CONF}/conf.filter.rules.head.ratelimit.sh" >> "${UP4}"
echo -ne '\n' >> "${UP4}"
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules conf.filter.rules.body.ipv4"
"${CONF}/conf.filter.rules.body.ipv4.sh" >> "${UP4}"
echo -ne '\n' >> "${UP4}"
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules conf.filter.rules.tail.ipv4"
"${CONF}/conf.filter.rules.tail.ipv4.sh" >> "${UP4}"
echo -ne '\nCOMMIT\n' >> "${UP4}"

# concat ipv6 rules
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules IPv6"
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules conf.nat.policy"
cat "${CONF}/conf.nat.policy" > "${UP6}"
echo -ne '\n' >> "${UP6}"
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules conf.nat.rules"
cat "${CONF}/conf.nat.rules" >> "${UP6}"
echo -ne '\nCOMMIT\n\n' >> "${UP6}"
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules conf.filter.policy"
cat "${CONF}/conf.filter.policy" >> "${UP6}"
echo -ne '\n' >> "${UP6}"
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules conf.filter.rules.head.conntrack"
"${CONF}/conf.filter.rules.head.conntrack.sh" >> "${UP6}"
echo -ne '\n' >> "${UP6}"
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules conf.filter.rules.head.ipv6.lo"
"${CONF}/conf.filter.rules.head.ipv6.lo.sh" >> "${UP6}"
echo -ne '\n' >> "${UP6}"
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules conf.filter.rules.head.lo"
cat "${CONF}/conf.filter.rules.head.lo" >> "${UP6}"
echo -ne '\n' >> "${UP6}"
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules conf.filter.rules.head.ipv6.private"
"${CONF}/conf.filter.rules.head.ipv6.private.sh" >> "${UP6}"
echo -ne '\n' >> "${UP6}"
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules conf.filter.rules.head.ipv6.icmp"
"${CONF}/conf.filter.rules.head.ipv6.icmp.sh" >> "${UP6}"
echo -ne '\n' >> "${UP6}"
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules conf.filter.rules.head.ratelimit"
"${CONF}/conf.filter.rules.head.ratelimit.sh" >> "${UP6}"
echo -ne '\n' >> "${UP6}"
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules conf.filter.rules.body.ipv6"
"${CONF}/conf.filter.rules.body.ipv6.sh" >> "${UP6}"
echo -ne '\n' >> "${UP6}"
[[ "${DEBUG}" > 0 ]] && >&2 echo "generate rules conf.filter.rules.tail.ipv6"
"${CONF}/conf.filter.rules.tail.ipv6.sh" >> "${UP6}"
echo -ne '\nCOMMIT\n' >> "${UP6}"

# restore rules
[[ "${DEBUG}" > 0 ]] && >&2 echo "load ipv4 rules: ${UP4}"
/sbin/iptables-restore < "${UP4}"
[[ "${DEBUG}" > 0 ]] && >&2 echo "load ipv6 rules: ${UP6}"
/sbin/ip6tables-restore < "${UP6}"

#[[ "${DEBUG}" > 0 ]] && >&2 echo "restart fail2ban"
#/bin/systemctl restart fail2ban

# wait a second to avoid race condition with dhcpclient
sleep 1
