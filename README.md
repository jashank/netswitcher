netswitcher
===========

Some useful functions that make network location switching easier.

This isn't guaranteed to work everywhere.  It may cause your computer
to catch fire, eat your pets or destroy your marriage.

Usage
-----

Network profiles are simply shell scripts that source the `functions`
file at the right time, and specify what family of interfaces they
use.  All profiles offer two functions: _arrive_ and _depart_, which
should be called when you arrive at, or depart from, a certain
location.

To call one, run, as root (either by running a root shell, or by using
sudo):

    # zsh /path/to/netswitcher/example-profile arrive

or

    # zsh /path/to/netswitcher/example-profile depart

The name of the currently active profile can be found in
`/run/network-location`.

System Requirements
-------------------

 - `zsh` (this may change)
 - `iproute2`

Optionally,

 - `ifenslave`
 - `dhcpcd`
 - `dbus`
 - `bluez`
 - `bluez-utils`
 - `wpa_supplicant`

Known to work:

 - Arch (tested _every day_ in the real world)

Should work:

 - Fedora

May work someday:

 - FreeBSD (?!)
 - illumos

Why?
----

I spent three years dragging a Mac around with me.  If there's one
thing from OS X (well, Darwin, actually) I could have and nothing
else, it's the SystemConfiguration framework (`scutil`, `scselect`),
which is the functionality behind network "Locations" on OS X.

I also needed some other features from _scselect_, so I wound up
writing a wrapper around it, called _scselects_, which did network
location switching and updated some files that control Darwin
behaviours.

On Linux, there's nothing that does the job.  NetworkManager should,
in theory, do the trick, but it's terrible at doing this.  `netctl`, a
more natural choice considering I use Arch, is even worse and has
especially shaky support for link aggregation.

So I bit the bullet and wrote this bag of shell scripty goodness.

The philosophical objectives are:

 - I'm a sysadmin, so I know how to do this by hand, but I'm lazy,
   therefore I do not.  Use a format that other sysadmins ran read,
   understand and hack to do what they want, not what _I_ want nor
   what I think they want.
   
 - If it breaks, it should not break everything.  NetworkManager is
   especially guilty of this, in my experience.
   
 - Simple, fast, debuggable, light.  Don't use extraneous tools when
   they're not needed (Bluetooth `bnep` support violates this because
   bluez is braindead).  _netctl_ embodies this.

 - Do not change persistent system state, so a reboot can undo damage.
   _Never_ write to system configuration files.  Fedora's netconfig is
   especially guilty of this, in my experience.

Many of these should be self-evident through the following examples
and by reading the source.

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

Convention is that a profile's filename should be the same as
`$profile`.

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
 - firewalling with firewalld,
 - IPv6 (testers wanted!)

### Long-Term ###

 - migrate to plain POSIX sh(1)
 - remove as much dependence on Linuxisms as possible
 - remove dependence on dhcpcd
 - write a bluez4-compatible bluez_if
 - remove the ugly profile class call
 - wrapper script that manages file locations
 - i18n

License
-------

Copyright (c) 2014 Jashank Jeremy.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
