# -*- shell-script -*-
# netswitcher -- network location switcher
#
# Copyright (c) 2014 Jashank Jeremy.
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

if [ X$1 = X ]
then
    print "[${profile}] usage:" `basename $0` "(arrive|depart)"
    exit 1
fi

function _print_profile_nonl() {
    printf "\x1b[32m[%s: %s %s]\x1b[39m %s" ${profile} $1 $2 "$3"
}

function _print_profile() {
    printf "\x1b[32m[%s: %s %s]\x1b[39m %s\n" ${profile} $1 $2 "$3"
}

function _advise_up() {
    _print_profile $ifname "L" "link up"
    echo ${profile} > /run/network-location
}

function _advise_down() {
    _print_profile $ifname "-" "link down"
    echo '' > /run/network-location
}

function _if_up() {
    _print_profile $1 "+" "bringing up interface"
    ip link set $1 up
}

function _if_down() {
    _print_profile $1 "-" "tearing down interface"
    ip link set $1 down
}

function _bond_up() {
    _print_profile $1 "-" "creating bond interface"
    ip link set $1 up

    _print_profile $1 "-" "enslaving interfaces"
    # man, screw you, shell quoting
    eval "ifenslave $1 $bond_ifs"
}

function _bond_down() {
    _print_profile $1 "-" "interface teardown"
    ip link set $1 down
}

function _dhcpcd_up() {
    _print_profile $1 "l" "launching DHCP client daemon"
    dhcpcd $1
}

function _dhcpcd_down() {
    _print_profile $1 "L" "terminating DHCP client daemon"
    kill -9 `cat /run/dhcpcd-$1.pid`
}

function _firewall_up() {
}

function _firewall_down() {
}

function _bnep_up() {
    _print_profile $1 "-" "poking bluez via dbus"
    dbus-send --system --type=method_call --dest=org.bluez \
	/org/bluez/hci0/dev_`echo $remote_btaddr | sed -e "s/:/_/g"` \
	org.bluez.Network1.Connect string:'nap'
}

function _bnep_down() {
    _print_profile $1 "-" "poking bluez via dbus"
    dbus-send --system --type=method_call --dest=org.bluez \
	/org/bluez/hci0/dev_`echo $remote_btaddr | sed -e "s/:/_/g"` \
	org.bluez.Network1.Disconnect
}

function _static_up() {
    _print_profile $1 "l" "addressing and routing interface"
    ip addr add $2/$3 dev $1
    ip route add default via $4 dev $1
}

function _static_down() {
    _print_profile $1 "l" "unrouting and unaddressing interface"
    ip route delete default via $4 dev $1
    ip addr delete $2/$3 dev $1
}

function _resolvconf_up() {
    _print_profile $1 "l" "configuring DNS resolution"
    (echo "nameserver $2"; echo "search $3") | resolvconf -a $1    
}

function _resolvconf_down() {
    _print_profile $1 "l" "cleaning up DNS resolution"
    resolvconf -d $1
}

function dhcp_if() {
    case "$1" in
	arrive)
	    _if_up $ifname
	    _dhcpcd_up $ifname

	    if [ X$2 != XQUIET ]
	    then
		_advise_up
	    fi
	    ;;
	depart)
	    _dhcpcd_down $ifname
	    _resolvconf_down $ifname
	    _if_down $ifname

	    if [ X$2 != XQUIET ]
	    then
		_advise_down
	    fi
	    ;;
    esac
}

function static_if() {
    if [ X$ifname = X ]
    then
	_print_profile "-" "-" "no interface specified in source!"
	exit 1
    fi

    case "$1" in
	arrive)
	    _if_up $ifname
	    _static_up $ifname $v4addr $v4mask $v4route
	    _resolvconf_up $ifname $dns_ns $dns_search

	    if [ X$2 != XQUIET ]
	    then
		_advise_up
	    fi
	    ;;
	depart)
	    _resolvconf_down $ifname
	    _static_down $ifname $v4addr $v4mask $v4route
	    _if_down $ifname

	    if [ X$2 != XQUIET ]
	    then
		_advise_down
	    fi
	    ;;
    esac
}

function dhcp_bond() {
    ifname=bond0

    case "$1" in
        arrive)
	    _bond_up $ifname

	    dhcp_if $1
            ;;
        depart)
	    dhcp_if $1 QUIET

	    _bond_down $ifname
	    _advise_down
            ;;
    esac
}

function static_bond() {
    ifname=bond0

    case "$1" in
        arrive)
	    _bond_up $ifname

	    static_if $1
            ;;
        depart)
	    static_if $1 QUIET

	    _bond_down $ifname
	    _advise_down
            ;;
    esac
}

# bluez_if <(arrive|depart)>
function bluez_if() {
    if [ X$remote_btaddr = X ]
    then
	_print_profile "-" "-" "no Bluetooth device specified!"
	exit 1
    fi

    ifname=bnep0

    case "$1" in
	arrive)
	    _bnep_up $ifname $remote_btaddr

	    _print_profile_nonl $ifname "-" "waiting for link to come up... "
	    until ip link show $ifname >/dev/null 2>&1
	    do
		sleep 1
		echo -n '.'
	    done
	    echo " ok"

	    dhcp_if $1
	    ;;
	depart)
	    dhcp_if $1 QUIET
	    _bnep_down $ifname $remote_btaddr

	    _advise_down
	    ;;
    esac
}

