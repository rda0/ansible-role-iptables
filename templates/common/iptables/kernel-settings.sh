#! /bin/sh

## Kernel Settings: Significant enhancements to network security settings

# Disable IP forward (resetting all other /proc settings, must be first setting)
if [ -r /proc/sys/net/ipv4/ip_forward ]; then
  # echo "Disabling IP forwarding"
  echo -n '0' > /proc/sys/net/ipv4/ip_forward
fi

# Enable to help protect against IP spoofing of internal addresses (only if ip_forward is enabled)
# if [ -r /proc/sys/net/ipv4/conf/all/rp_filter ]; then
#   # echo "Enabling rp_filter"
#   echo -n '1' > /proc/sys/net/ipv4/conf/all/rp_filter
# fi

# Block ICMP Echo Request to broadcast/multicast, Allow to host
echo -n '1' > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts
echo -n '0' > /proc/sys/net/ipv4/icmp_echo_ignore_all

# Disable ICMP redirect messages (only required for router)
echo -n '0' > /proc/sys/net/ipv4/conf/all/accept_redirects

# Tell Kernel to ignore invalid responses to broadcast frames from routers
echo -n '1' > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses

# Disable IP Source Routing
if [ -r /proc/sys/net/ipv4/conf/all/accept_source_route ]; then
  # echo "Disabling source routing"
  echo -n '0' > /proc/sys/net/ipv4/conf/all/accept_source_route
fi

if [ -r /proc/sys/net/ipv4/conf/all/log_martians ]; then
  # echo "Enabling logging of martians"
  echo -n '1' > /proc/sys/net/ipv4/conf/all/log_martians
fi

# Enable protection against SYN flood attacks
# if [ -r /proc/sys/net/ipv4/tcp_syncookies ]; then
#   # echo "Enabling tcp_syncookies"
#   echo -n '1' > /proc/sys/net/ipv4/tcp_syncookies
# fi

# echo -n '0' > /proc/sys/net/ipv4/conf/all/send_redirects
# echo -n '1' > /proc/sys/net/ipv4/ip_always_defrag

return 0
