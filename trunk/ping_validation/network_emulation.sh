#!/bin/bash -

# remember that I gave sudo powers for www-data for /sbin/tc

# emulation:
#	iperf @ pcix speed
#	iperf @ netem speed 
#	iperf @ netem speed + 2% losses
#	iperf -c -P 10 @ netem speed 
# qos: 
# 	video: (streaming.sh, bunnyt 3.345 mbps stream rate)
#		0.1% - 1% - 2% loss  
#		3 mbps , 3.5 mbps, 5 mbps
#		
#	bufferbloat: throughput vs delay (ping.plot)
#	filetransfer (iperf -F FILENAME)


# Careful: in TC
#    All parameters accept a floating point number, possibly followed by a unit.
# 
#        Bandwidths or rates can be specified in:
# 
#        kbps   Kilobytes per second
#        mbps   Megabytes per second
#        kbit   Kilobits per second
#        mbit   Megabits per second
#---------------------------------------


# netem:
# http://www.linuxfoundation.org/collaborate/workgroups/networking/netem
# sudo aptitude install iproute 
# sudo aptitude install iproute-doc
#
# visualization ping/mtr


# Bufferbloat:
# open iperf -s 
# 	iper -c localhost
#	ping.plot


cap=${1:-1} #<aa> link capacity (in kbit)</aa>
loss=${2:-0}
aqm=${3:-fifo}
dev=$4
#<aa>
dst=$5 #ip address (for example 84.57.14.201)
#</aa>

# input check + restore
[[ "$1" == "clean" ]] && { tc qdisc del dev $dev root; tc qdisc show dev $dev; exit 0; }
[[ "$1" == "show" ]] && { tc qdisc show dev $dev; exit 0; }
[[ "$#" == "5"  ]] || { 
	echo "usage
	sudo $0 (clean|show) <dev>
	sudo ./network_emulation.sh capacity[kbit] loss% (fifo|red|sfq) <dev> <ip_dst>
	"
	exit 1; 
}


# variable configuration
cap=${1:-1}
loss=${2:-0}
aqm=${3:-fifo}

# main procedure
echo "reset"
tc qdisc del dev $dev root

echo "build tree"
tc qdisc add dev $dev root handle 1: htb default 11

#---------------------------------------------------
# LINK CAPACITY 
#
#examples 
#dsl:
#tc class add dev $dev parent 1: classid 1:1 htb rate 1mbit ceil 1mbit
#dsl+:
#tc class add dev $dev parent 1: classid 1:1 htb rate 10mbit ceil 10mbit
#ftth:
#tc class add dev $dev parent 1: classid 1:1 htb rate 100mbit ceil 100mbit
#
# - as specified on the command line 
# OLD - Mbit 
#echo "tc class add dev $dev parent 1: classid 1:1 htb rate ${cap}mbit ceil ${cap}mbit"
#tc class add dev $dev parent 1: classid 1:1 htb rate ${cap}mbit ceil ${cap}mbit
# NEW
echo "tc class add dev $dev parent 1: classid 1:1 htb rate ${cap}kbit ceil ${cap}kbit"
tc class add dev $dev parent 1: classid 1:1 htb rate ${cap}kbit ceil ${cap}kbit
#---------------------------------------------------


# on whom to apply the emulated conditions ?
# - add addr filter
echo "tc filter add dev $dev protocol ip parent 1:0 prio 1 u32 match ip dst $dst flowid 1:1"
tc filter add dev $dev protocol ip parent 1:0 prio 1 u32 match ip dst $dst flowid 1:1

#---------------------------------------------------
# PROPAGATION DELAY
#
# - add base "fifo" limitation and delay
echo "tc qdisc add dev $dev parent 1:1 handle 11: netem loss $loss% delay 30ms 10ms"
tc qdisc add dev $dev parent 1:1 handle 11: netem loss $loss% delay 30ms 0ms
#tc qdisc add dev $dev parent 1:1 handle 11: netem loss $loss% delay 30ms 10ms

#sudo tc qdisc change dev lo  parent 1:1 handle 11:  netem loss 0.1% delay 10ms

#limit 500
#---------------------------------------------------


#---------------------------------------------------
# AQM configuration
#
if [[ "$3" == "fifo" ]]; then
	true
	#note: 500 pkt = 
	# 11760ms/5880ms/588ms/58ms delay with 
	# 0.5mbps/1mbps/10mbps/100mbps capacity
	
elif [ "$3" == "sfq" ]; then
	tc qdisc add dev $dev parent 11:1 handle 111: sfq perturb 10
	
elif [ "$3" == "red" ]; then	
	#---------------------------------------------------
	# RED adviced configuration
	#    red_prob=0.1
	#    #red_cap=$((cap*1024))
	#    red_cap=` echo "$cap*1024" | bc | sed 's/\.[0-9]*$//' ` 
	#    red_ttl=50
	#    red_avpkt=1500
	#    red_max=$((red_cap*125*red_ttl/1000))
	#    red_min=$((red_max/3))
	#    [[ "$red_min" -lt "$red_avpkt" ]] && { red_min=$red_avpkt; }
	#    red_burst=$(((red_min*2+red_max)/(3*red_avpkt)))
	#    red_limit=$((red_max*8))
	#
	#tc qdisc add dev $dev parent 11:1 handle 111: red limit $red_limit min $red_min max $red_max avpkt $red_avpkt burst $red_burst probability $red_prob bandwidth $red_cap
        #---------------------------------------------------

	#ns2 configuration	
	#tc qdisc add dev $dev parent 11:1 handle 111: red limit 75000 min 3125 max 9375 avpkt 500 burst 10 probability 0.1 bandwidth 10240
		
	#not that bad for dsl 1mbit	
	tc qdisc add dev $dev parent 11:1 handle 111: red limit 150000 min 15000 max 150000 avpkt 1500 burst 10 probability 0.1 bandwidth 10240	

	#not that bad for dsl+ 10mbit	
	#tc qdisc add dev $dev parent 11:1 handle 111: red limit 450000 min 15000 max 450000 avpkt 1500 burst 10 probability 0.01 bandwidth 10240	
fi
#---------------------------------------------------

echo "--- tc show --"

# result verify
[[ "$?" -ne 0 ]] && { echo "Error detected, restoring..."; tc qdisc del dev $dev root; tc qdisc show dev $dev; exit 1; }
tc qdisc show dev $dev
