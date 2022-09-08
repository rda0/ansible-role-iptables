# ansible-role-iptables

This role is designed to provide a robust iptables host firewall with just a few configuration options in the form of:

```yaml
# networks

iptables_net4_adm:
  admin-network1: 192.0.2.0/24
  admin-network2: 198.51.100.0/24

iptables_net4_srv:
  server-networks: 203.0.113.0/24

# open ports

iptables_i_tcp_adm: ssh http https 19999
iptables_i_tcp_srv: smtp imap
iptables_i_udp_srv: 53 123
```

## Description

This repo contains an [Ansible](https://www.ansible.com/) role to deploy a stateful [iptables](https://netfilter.org/projects/iptables/index.html) firewall in combination with [ipsets](https://netfilter.org/projects/ipset/index.html) for fast filtering against IP ranges or IP addresses. It supports both IPv4 and IPv6 with a single configuration. The filter policy is **deny all**, **allow some** in all [packet flow directions](https://upload.wikimedia.org/wikipedia/commons/3/37/Netfilter-packet-flow.svg) ([INPUT](https://github.com/rda0/diagram/blob/master/iptables-chains-hooks-dark.png), [OUTPUT](https://github.com/rda0/diagram/blob/master/iptables-chains-hooks-dark.png), [FORWARD](https://github.com/rda0/diagram/blob/master/iptables-chains-hooks-dark.png)). This policy allows not only to filter all the services provided to a network, but also to filter all the services in the other direction (consumed from a network). However, there is also a configuration option to enable unidirectional filtering mode to allow all outgoing traffic, as it is a common setup on most homegrade router firewalls.

While the end result only consists of a configuration file (with the networks and open ports) and a few bash scripts to generate the ipsets and iptables rules, deployment using Ansible makes it scalable across a wide range of hosts with different services.

This role is not intended for routers with lots of interfaces which would require a complex setup. All interfaces are treated equally and are automatically protected.

## Features

- Filter policy: **deny all**, **allow some**
- Deny policy: **REJECT** (default) | **DROP**
- Deny private address ranges ([RFC 1918](https://www.rfc-editor.org/rfc/rfc1918.txt), [RFC 4193](https://www.rfc-editor.org/rfc/rfc4193.txt)): **deny all**, **allow some**
- Multiple interfaces: All interfaces are protected automatically
- Persistent accross reboots: started/stopped/restarted using a systemd service unit
- Error handling: if a service restart fails after a config change it falls back to the last working configuration
- Integrates with other service units: fail2ban, libvirtd
- Port rate limiting: protects sensitive ports like ssh from bruteforce attacks
- Extensive logging: all denied packets can be logged (depending on the configured loglevel)
- Logging DOS protection: all types of denied packets are limited by a separately configurable rate limit
- Port forwarding rules: applicable for IPv4 only (experimental)
- Per host/IP/address rules (endpoints)
- Custom rules

Planned features (not implemented yet):

- Possibility for arbitrary network definitions
- Possiblity to define services (instead of protocols and ports)
- Possiblity to use this role as replacement for TCP wrappers
- Rewrite code for interface configs (internal/external)

## Variables

All configuration options are controlled via ansible variables. All variables and their default values are documented in the yaml files in the role defaults directory (`defaults/main/*.yml`).

It is best practice to define your variable values in the Ansible inventory (`group_vars` and `host_vars`).

## General options

These variables control the general behaviour of the firewall.

Unidirectional filtering mode: To allow all outbound traffic, set the following variable to `true`:

```yaml
iptables_allow_o_any: false
```

IP spoofing protection for private address ranges: To disable it, set to `false`:

```yaml
iptables_deny_i_prv: true
```

Deny policy: The default setting is to actively reject denied packets with a proper network response in the same way the Linux kernel would do it. Should you for any reason whish to drop packets instead, set the following variable to `true`:

```yml
iptables_deny_target_drop: false
```

## Interfaces

All interfaces are automatically detected and protected by the firewall. But for some advanced setups, like when interfaces are bridged, they need to be properly specified in the configuration.

There might be some confusion when we are talking about bridges and we are not using [ebtables](http://ebtables.netfilter.org/). We are using [iptables](https://netfilter.org/projects/iptables/index.html) only for this project, so why do we need to know the bridge interfaces? According to the TCP/IP model frames/packets forwarded across a bridge should not enter the IP layer? The reason is, when the bridge code and netfilter is enabled in the kernel, the `br-nf` code will be active. The `br-nf` code makes bridged IP frames/packets go through the `iptables` chains. Ebtables filters on the Ethernet layer, while iptables only filters IP packets. So the `br-nf` code is responsible for sometimes violating the TCP/IP Network Model. Please refer to [ebtables/iptables interaction on a Linux-based bridge](http://ebtables.netfilter.org/br_fw_ia/br_fw_ia.html), which details the functionality of the `br-nf` code.

Long story short, when we bridge interfaces and lock down our firewall in the `FORWARD` chain, we need to allow frames/packets in our iptables rules in the `FORWARD filter` chain, because iptables chains are also [attached onto the hooks of the bridging code](http://ebtables.netfilter.org/br_fw_ia/bridge5.png).

Here are some examples:

### Single or multiple interfaces

If you do not have bridges, the defaults are fine (you do not need to specify any interfaces in the inventory):

From `defaults/main/00-main.yml`:

```yaml
iptables_allow_bridge_interfaces:
```

### Using bridged interfaces

In a setup with bridges, the bridge interfaces need to be configured explicitely:

```yaml
iptables_allow_bridge_interfaces: br0 br1
```

In this example we have a host with two network interfaces `eth0` and `eth1` connected to separate networks. This machine is also serving as kvm hypervisor, hosting virtual machines in a bridged setup on two bridges `br0` and `br1` where the two physical interfaces are attached respectively.

All traffic in both directions of the bridge interfaces will be accepted.

### Using tuntap interfaces

Similarily we need to specify any tuntap interfaces:

```yaml
iptables_allow_tuntap_interfaces: tun+
```
All traffic originating from tuntap interfaces will be accepted.

### Allow any traffic from/to specific interfaces

```yaml
iptables_allow_interfaces: eno3
```


## Networks

This role knows 9 network zones that may be filled with IP ranges using Ansible:

| name   | description                   | definition   |
|--------|-------------------------------|--------------|
| adm    | admin networks                | user defined |
| prv    | private address ranges        | pre defined  |
| prvcan | locally routed ranges in prv  | user defined |
| san    | system/storage area networks  | user defined |
| cun    | custom network                | user defined |
| srv    | server networks               | user defined |
| lan    | local area network            | user defined |
| can    | campus/corporate area network | user defined |
| any    | any network ("the internet")  | pre defined  |

These network zones will be translated to ipsets that can be used to match packets against in the iptables rules. For each non empty ipset, a custom chain is created in iptables. Each packet will be matched against the ipsets in the following (customizable) order:

```yml
iptables_nets: adm san cun srv lan can
```

If a packet matches an ipset, it will be sent to the respective chain. Each network (ipset) chain may allow (accept) combinations of protocols and ports (see below). If a packet is accepted no more rules will be evaluated. If none of the rules match, the packet will be returned to the parent chain and continues on its way down with the next ipsets.

The network zones are to be configured for IPv4 and IPv6 separately using the following Ansible dictionary variables (see also `defaults/main/30-networks.yml`):

```yaml
# networks (ansible only variables)
# format: dict (elements: `<netname>: <cidr_network_address>`)

iptables_net4_adm: {}
iptables_net6_adm: {}
iptables_net4_prvcan: {}
iptables_net6_prvcan: {}
iptables_net4_san: {}
iptables_net6_san: {}
iptables_net4_cun: {}
iptables_net6_cun: {}
iptables_net4_srv: {}
iptables_net6_srv: {}
iptables_net4_lan: {}
iptables_net6_lan: {}
iptables_net4_can: {}
iptables_net6_can: {}
```

To list single IP addresses in the network ranges, just use the biggest CIDR prefix. For IPv4: `<ip>/32` or for IPv6: `<ip>/128`.

## Ports

Open ports can be configured using multiple variables per network. Each variable will be filled with a space separated list of port numbers, port names or port ranges understood by iptables.

The variable name syntax is as follows:

```
iptables_<chain>_<protocol>_<network>
```

While `<chain>` can be any of:

- `i`: INPUT chain
- `o`: OUTPUT chain
- `f`: FORWARD chain

and `<protocol>` can be:

- `tcp`: Transmission control protocol
- `udp`: User Datagram Protocol

and `<network>` can be any of the network/ipset names specified in the table in the previous section.


Here the 4 variables for the admin network (inbound, outbound) as an example:

```yaml
# open ports (input/output)
# format: [ port | port-range ... ]

iptables_i_tcp_adm:
iptables_i_udp_adm:
iptables_o_tcp_adm:
iptables_o_udp_adm:
```

Refer to `defaults/main/40-ports.yml` for a complete list of variables and their defaults.

The default is to deny all ports, except the inbound TCP port `22` (ssh) for the admin network. Should you forget or fail to configure an admin network, ssh connections will be accepted from any network. This serves as a failsave to hopefully prevent you from locking yourself out of the target host.

## Special endpoints

For special endpoints (single network or host addresses) not covered by the global networks (`iptables_net...`)
use the variable `iptables_endpoints`. **These will not use iptsets** (slower). The syntax is as follows:

```yaml
iptables_endpoints:
  <name>:
    address:
      [ipv4|ipv6]: <address>[/<mask>][,...]
    ports:
      [inbound|outbound]:
        [tcp|udp]: <port>[ ...]
```

Example:

```yaml
iptables_endpoints:
  host1:
    address:
      ipv4: 192.0.2.5/32
      ipv6: 1291:65bc:30ce:3dc4::26/128
    ports:
      inbound:
        tcp: 11 12 13
        udp: 13
      outbound:
        tcp: 12
        udp: 14 56
  net1:
    address: { ipv4: 198.51.100.0/24 }
    ports: { inbound: { tcp: 50 } }
  host2:
    address: { ipv4: 192.0.2.7 }
    ports: { outbound: { udp: 7 } }
```

## Custom rules

Refer to `defaults/main/50-rules.yml` for a complete list of variables and their defaults.

Use this to insert custom rules into chains. Example:

```yaml
iptables_rules_raw:
  - -I OUTPUT -j CT -p udp -m udp --dport 69 --helper tftp
iptables_rules_filter:
  - -4 -I INPUT -s 1.2.3.4 -j DROP
```

## Example configuration

In your inventorys `group_vars/all` variables you could define your network ranges and some sane port defaults as follows:

```yaml
## networks (ansible only variables)
## format: dict (elements: `<netname>: <cidr_network_address>`)

# admin workstations

iptables_net4_adm:
  admin-workstation-1: 192.0.2.2/32
  admin-workstation-2: 192.0.2.3/32
  admin-workstation-3: 192.0.2.4/32

# networks from private address ranges routed and allowed for your network

iptables_net4_prvcan:
  public-dhcp: 10.0.0.0/8
  vpn: 192.168.0.0/16

# server networks

iptables_net4_srv:
  core-server: 198.51.100.0/25
  customer-server: 198.51.100.128/25 192.0.2.67/32

iptables_net6_srv:
  core-server: 2001:db8:abc:42:/64

# local area network (department only)

iptables_net4_lan:
  core-server: 198.51.100.0/25
  customer-server: 198.51.100.128/25 192.0.2.67/32
  department-staff-vpn: 192.168.1.0/24 192.168.2.0/24

iptables_net6_lan:
  department-range: 2001:db8:abc:/48

# campus area network

iptables_net4_can:
  campus-main-1: 192.0.2.0/24
  campus-main-2: 198.51.100.0/24
  campus-main-3: 203.0.113.0/24
  public-dhcp: 10.0.0.0/8
  vpn: 192.168.0.0/16

iptables_net6_can:
  campus-range: 2001:db8:/32


## open ports (input/output)
## format: [ port | port-range ... ]

# ssh
iptables_i_tcp_adm: 22
# mosh
iptables_i_udp_adm: 60000:61000
# ssh
iptables_o_tcp_adm:
iptables_o_udp_adm:

# ssh
iptables_i_tcp_srv: 22
# ntp
iptables_i_udp_srv: 123
# kdc kadmin kpasswd ldap ldaps
iptables_o_tcp_srv: 88 749 464 389 636
# ntp syslog kdc kadmin kpasswd ldap ldaps
iptables_o_udp_srv: 123 514 88 749 464 389 636

iptables_i_tcp_can:
iptables_i_udp_can:
# dhcp
iptables_o_tcp_can: 67
# dhcp
iptables_o_udp_can: 67

iptables_i_tcp_any:
iptables_i_udp_any:
# ssh smtp whois dns rwhois http https git gpg
iptables_o_tcp_any: 22 25 43 53 4321 80 443 9418 11371
# whois dns ntp
iptables_o_udp_any: 43 53 123
```

In your specific `group_vars` or `host_vars` you can define open ports depending on the services provided by that host or host-group:

```yaml
# interfaces

iptables_allow_bridge_interfaces: br0 br1

# custom admins

iptables_net4_adm_custom:
  alice: 192.0.2.7/32
  bob: 192.0.2.34/32

# public services

iptables_i_tcp_any: 80 443
```
