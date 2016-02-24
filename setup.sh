#! /bin/bash

BRCTL=brctl
IP=ip
KVM=kvm

SCREEN=routing
BRIDGES="brdg1"
KVM_OPTS="-m 1024"

#-vnc :0 \
do_setup()
{
	# Create KVM device 
	if [ ! -e /dev/kvm ]; then
	    set +e
	    mknod /dev/kvm c 10 $(grep '\<kvm\>' /proc/misc | cut -f 1 -d' ')   
	    set -e
	fi

	for bridge in $BRIDGES; do
		echo Adding bridge $bridge
		$BRCTL addbr $bridge || die "$BRCTL addbr $bridge Failed"
		sleep 2
		$IP link set $bridge address 00:11:11:aa:aa:aa
		sleep 2
		echo Bringing up all bridge interfaces
		$IP link set dev $bridge up || die "$IP link set dev $bridge up"
	done

	tmux -2 new-session -d -s $SCREEN
	echo Starting Router1
	tmux new-window -a -t $SCREEN -n router1 "$KVM $KVM_OPTS \
	            -name router1 \
	            -net nic,macaddr=52:54:00:00:01:00 -net tap,ifname=r1-eth0,script=no,downscript=no \
	            -net nic,macaddr=52:54:00:00:01:01 -net tap,ifname=r1-eth1,script=no,downscript=no \
	            -net nic,macaddr=52:54:00:00:01:02 -net tap,ifname=r1-eth2,script=no,downscript=no \
	            -hda ./images/router1.qcow2"

	echo Starting Router2
	tmux new-window -a -t $SCREEN -n router2 "$KVM $KVM_OPTS \
	            -name router2 \
	            -net nic,macaddr=52:54:00:00:02:00 -net tap,ifname=r2-eth0,script=no,downscript=no \
	            -net nic,macaddr=52:54:00:00:02:01 -net tap,ifname=r2-eth1,script=no,downscript=no \
	            -net nic,macaddr=52:54:00:00:02:02 -net tap,ifname=r2-eth2,script=no,downscript=no \
	            -hda ./images/router2.qcow2"

	echo Waiting a bit for KVM to start
	sleep 2

	for intf in r1-eth1 r1-eth2 r2-eth1 r2-eth2 ; do 
		$IP link set dev $intf up
	done

	# attach R1:e2 to R2:e2
	$BRCTL addif brdg1 r1-eth2 || die "$BRCTL addif br-r1-r2 r1-eth2"
	$BRCTL addif brdg1 r2-eth2 || die "$BRCTL addif br-r1-r2 r2-eth2"

	tmux source-file /etc/tmux.conf
	tmux -2 attach-session -t $SCREEN	
}

do_teardown() {

    echo '*** ' Killing all KVM instances
    killall qemu-system-x86_64
  
    for bridge in $BRIDGES; do 
       echo '*** ' Bringing down all interfaces
       $IP link set dev $bridge down
       echo '*** ' Removing bridge $bridge
       $BRCTL delbr $bridge 
    done

    echo '*** ' Removing screen \'$SCREEN\'
    tmux kill-session -t $SCREEN
}

do_usage() {
   echo "Usage: $0 <-setup|-teardown|-show>" >&2
   exit 1
}

do_show () {
    echo '*** ' Bridges:
    $BRCTL show
    echo '*** ' Namespaces:
    $IP netns 
    echo '*** ' Interfaces:
    for intf in $INTERFACES ; do
       $IP addr show $intf
    done
    echo '*** ' KVM instances:
    pgrep qemu-system-x86_6
    echo '*** ' Screen instances
    tmux  ls

}

case $1 in 
   -setup)
		do_setup ;;
   -teardown)
		do_teardown ;;
   -show)
		do_show ;;
   *)
		do_usage ;;
esac
