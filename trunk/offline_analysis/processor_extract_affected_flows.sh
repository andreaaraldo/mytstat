### It extracts the tuples (ipaddr1,port1,ipaddr2,port2,dir) that has experimented, at least one time a windowed queueing delay greater or equal to $TRESHOLD

if [ $# -ne 1 ]
then
	echo "usage:    $0 <logfile>"
	exit 1; 
fi

TRESHOLD=100
LOGFILE=$1

sed '/^$/d' $LOGFILE | awk -v TR=$TRESHOLD '{if($26>0 && $20>=$TR) {print $2,$3,$4,$5,"S2C"} if($13>0 && $7>=$TR) {printf $2,$3,$4,$5,"C2S"} }' | sort -n | uniq
