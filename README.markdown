# ansible-role-iptables

This repo contains an Ansible role to deploy a stateful [iptables](https://netfilter.org/projects/iptables/index.html) firewall in combination with [ipsets](https://netfilter.org/projects/ipset/index.html) for fast filtering against IP ranges or IP addresses. It supports both IPv4 and IPv6 with a single configuration. The filter policy is **deny all**, **allow some** in all packet flow directions (INPUT, OUTPUT, FORWARD). This policy may seem very strict, but it ensures not only to know all the services provided to a network, but also all the services in the other direction (consumed from a network). However, there is also a configuration option to enable unidirectional filtering mode to allow all outgoing traffic, as it is a common setup on most homegrade router firewalls.

## Features

- Internet protocol versions: **IPv4**, **IPv6**
- Filter policy: **deny all**, **allow some**
- Filter direction: **ALL** directions (default) | **INPUT**, **FORWARD** (all outgoing traffic allowed)
- Deny policy: **REJECT** as per RFC (default) | **DROP**
- IP spoofing protection: denies private address ranges (RFC 1918, RFC 4193) by default
- Explicitely allow locally routed private address ranges for your network
- Multiple interfaces: internal, external and bridged interfaces
- Once deployed fully independant from Ansible, it's just one config file and a bunch of bash scripts
- Persistent accross reboots: started/stopped/restarted using a systemd service unit
- Error handling: if a service restart fails after a config change it falls back to the last working configuration
- Integrates with other service units: fail2ban, libvirtd
- Port rate limiting: protects sensitive ports like ssh from bruteforce attacks
- Extensive logging: all denied packets can be logged (depending on the configured loglevel)
- Logging DOS protection: all types of denied packets are limited by a separately configurable rate limit
