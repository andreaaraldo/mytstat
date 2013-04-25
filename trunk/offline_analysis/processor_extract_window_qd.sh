### It extracts the windowed queueing delays of not void windows

if [ $# -ne 1 ]
then
	echo "usage:    $0 <logfile>"
	exit 1; 
fi


LOGFILE=$1

sed '/^$/d' $LOGFILE | awk '{if($13>0) {print $7} if($26>0) {print $20} }'
