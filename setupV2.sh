#! /bin/bash

BRCTL=brctl
IP=ip
KVM=kvm
BRIDGES="brdg1 brdg2"
INTF="r1-eth0 r1-eth1 r1-eth2 r2-eth0 r2-eth1 r2-eth2 r3-eth0 r3-eth1 r3-eth2"
KVM_OPTS="-m 1024"

do_setup()
{
	# Create KVM device 
	if [ ! -e /dev/kvm ]; then
		set +e
		mknod /dev/kvm c 10 $(grep '\<kvm\>' /proc/misc | cut -f 1 -d' ')   
		set -e
	fi

	for bridge in $BRIDGES; do
		printf "Adding bridge $bridge\n"
		$BRCTL addbr $bridge || die "$BRCTL addbr $bridge Failed"
		sleep 2
		$IP link set $bridge address 00:11:11:aa:aa:aa
		$IP link set $bridge address 00:11:11:bb:bb:bb
		sleep 2
		printf "Bringing up all bridge interfaces\n"
		$IP link set dev $bridge up || die "$IP link set dev $bridge up"
	done

	printf "Starting Router1\n"
	$KVM $KVM_OPTS \
		-name router1 \
		-net nic,macaddr=52:54:00:00:01:00 -net tap,ifname=r1-eth0,script=no,downscript=no \
	        -net nic,macaddr=52:54:00:00:01:01 -net tap,ifname=r1-eth1,script=no,downscript=no \
	        -net nic,macaddr=52:54:00:00:01:02 -net tap,ifname=r1-eth2,script=no,downscript=no \
	        -hda ./images/router1.qcow2 &

	sleep 5
	printf "Starting Router2\n"
	$KVM $KVM_OPTS \
	        -name router2 \
	        -net nic,macaddr=52:54:00:00:02:00 -net tap,ifname=r2-eth0,script=no,downscript=no \
	        -net nic,macaddr=52:54:00:00:02:01 -net tap,ifname=r2-eth1,script=no,downscript=no \
	        -net nic,macaddr=52:54:00:00:02:02 -net tap,ifname=r2-eth2,script=no,downscript=no \
	        -hda ./images/router2.qcow2 &

	sleep 5
	printf "Starting Router3\n"
	$KVM $KVM_OPTS \
	        -name router3 \
	        -net nic,macaddr=52:54:00:00:03:00 -net tap,ifname=r3-eth0,script=no,downscript=no \
	        -net nic,macaddr=52:54:00:00:03:01 -net tap,ifname=r3-eth1,script=no,downscript=no \
	        -net nic,macaddr=52:54:00:00:03:02 -net tap,ifname=r3-eth2,script=no,downscript=no \
	        -hda ./images/router3.qcow2 &

	printf "Waiting a bit for KVM to start\n"
	sleep 2

	for intf in $INTF; do 
		$IP link set dev $intf up
	done

	# Creating physical-links/bridges for routers
	$BRCTL addif brdg1 r1-eth0 || die "$BRCTL addif brdg1 r1-eth0"
	$BRCTL addif brdg1 r2-eth0 || die "$BRCTL addif brdg1 r2-eth0"
	$BRCTL addif brdg2 r1-eth1 || die "$BRCTL addif brdg1 r1-eth1"
	$BRCTL addif brdg2 r3-eth0 || die "$BRCTL addif brdg1 r3-eth0"
}

do_teardown() {

    printf "*** Killing all KVM instances\n"
    killall qemu-system-x86_64
  
    for bridge in $BRIDGES; do 
       printf "*** Bringing down all interfaces\n"
       $IP link set dev $bridge down
       printf "*** Removing bridge $bridge\n"
       $BRCTL delbr $bridge 
    done
}

do_usage() {
   printf "Usage: $0 <-setup|-teardown|-show>\n" >&2
   exit 1
}

do_show () {
    printf "*** Bridges:\n"
    $BRCTL show
    printf "*** Namespaces:\n"
    $IP netns 
    printf "*** Interfaces:\n"
    for intf in $INTERFACES ; do
       $IP addr show $intf
    done
    printf "*** KVM instances:\n"
    pgrep qemu-system-x86_6

}

case $1 in 
   -setup)
		do_setup;;
   -teardown)
		do_teardown;;
   -show)
		do_show;;
   *)
		do_usage;;
esac
