networks
========

Some useful functions that make network location switching easier.

Usage
-----

Network profiles are simply shell scripts that source the `functions`
file at the right time, and specify what family of interfaces they
use.  To call one, run, as root (either by running a root shell, or by
using sudo):

    # zsh /path/to/netswitcher/example-profile arrive

or

    # zsh /path/to/netswitcher/example-profile depart

Writing Profiles
----------------

The simplest profile looks like:

    #!/bin/zsh

	profile=example.com
	ifname=enp0s25

    . `dirname $0`/functions

    dhcp_if $1

This defines a profile called 'example.com', on a system with one
network interface, `enp0s25`.  Its profile class is `dhcp_if`, which
automatically configures DHCP on an interface.

Each profile class expects some environment variables to be set, and
may fail in odd ways if they are not.  All profile classes depend on
`$profile`.

Profile Classes
---------------

### `dhcp_if` ###

__Depends__: `$profile` `$ifname`  
__Example usage__:

	profile=example.com
	ifname=enp0s25
    . `dirname $0`/functions
    dhcp_if $1

Configures `$ifname` using DHCP (via `dhcpcd`).

### `static_if` ###

__Depends__: `$profile` `$ifname` `$v4addr` `$v4mask` `$v4route` `$dns_ns` `$dns_search`  
__Example usage__:

	profile=example.com
	ifname=enp0s25
	v4addr=192.168.1.222
	v4mask=24
	v4route=192.168.1.1
	dns_ns=192.168.1.1
	dns_search=example.com
    . `dirname $0`/functions
    static_if $1

Configures `$ifname` as a statically-addressed interface.

- `$v4addr`/`$v4mask` together specify a CIDR address
- `$v4route` specifies the default route
- `$dns_ns` specifies the DNS nameserver
- `$dns_search` specifies the DNS search domain

### `dhcp_bond` ###

__Depends__: `$profile` `$bond_ifs`  
__Example usage__:

	profile=example.com
	bond_ifs="enp0s25 wlp7s0"
    . `dirname $0`/functions
    dhcp_bond $1

Creates an interface `bond0` by enslaving `$bond_ifs` in order, then
configures the interface using DHCP.

Note, this interface must have at least one active interface when arrived.

Note, you must configure `bonding` yourself.

### `static_bond` ###

__Depends__: `$profile` `$bond_ifs` `$v4addr` `$v4mask` `$v4route` `$dns_ns` `$dns_search`  
__Example usage__:

	profile=example.com
	bond_ifs="enp0s25 wlp7s0"
	v4addr=192.168.1.222
	v4mask=24
	v4route=192.168.1.1
	dns_ns=192.168.1.1
	dns_search=example.com
    . `dirname $0`/functions
    static_bond $1

Creates an interface `bond0` by enslaving `$bond_ifs` in order, then
configures `$ifname` as a statically-addressed interface.

- `$v4addr`/`$v4mask` together specify a CIDR address
- `$v4route` specifies the default route
- `$dns_ns` specifies the DNS nameserver
- `$dns_search` specifies the DNS search domain

### `bluez_if` ###

__Depends__: `$profile` `$remote_btaddr`  
__Example usage__:

	profile=example.com
	remote_btaddr=AA:BB:CC:DD:EE:FF
    . `dirname $0`/functions
    bluez_if $1

Using Bluez5, create an interface `bnep0` connected to a Bluetooth
personal-area network in network-access-point (NAP) mode, and
configures it with DHCP (for tethering, for instance, Android
devices).

Note, you must pair the device at `$remote_btaddr` yourself.

More Complex Profiles
---------------------

As a profile script is just a shell script, one can do shell-script
things.  For instance, here's one I use to detect if my phone has
appeared over USB-RNDIS before attempting to configure the interface:

    profile=exetel.com.au
    . `dirname $0`/functions
    ifname=`ip link | egrep '^[0-9]+:' | awk '{ print $2 }' | sed -e "s/://" | egrep 'enp[0-9]+s[0-9]+u[0-9]+'`
    
    if [ X$ifname = X ]
    then
        _print_profile "-" "-" "no interface found!"
        exit 19 # ENODEV
    else
        dhcp_if $1
    fi

Future Features
---------------

### Short-Term ###

 - multiple DNS servers,
 - multiple DNS search domains,
 - IPv6 (testers wanted!)

### Long-Term ###

 - migrate to plain POSIX shell
 - remove as much dependence on Linuxisms as possible
 - remove dependence on dhcpcd
 - write a bluez4-compatible bluez_if
 - remove the ugly profile class call
 - i18n

