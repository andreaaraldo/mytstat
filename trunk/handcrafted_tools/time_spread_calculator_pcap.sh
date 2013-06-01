#It calculates (in seconds) the difference between the first packet timestamp and the last packet timestamp
#of a pcap file

#this name is strange, so we have low probability to overwrite other files
TEMPFILE=~/temp/ijdqgvaoira8763zra.tmp;
PCAP_FILE=$1;

tcpdump.hack -tt -r $PCAP_FILE | awk '{if($3=="UDP") print $1}' |head -n1 > $TEMPFILE;
MIN="$(cat $TEMPFILE)";
echo "min="$MIN

tcpdump.hack -tt -r $PCAP_FILE | awk '{if($3=="UDP") print $1}' |tail -n1 > $TEMPFILE;
MAX="$(cat $TEMPFILE)";
echo "max="$MAN

calc $MAX - $MIN;

rm $TEMPFILE;
