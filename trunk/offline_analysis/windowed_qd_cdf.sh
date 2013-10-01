WINDOWED_QD_FILE=~/bufferbloat/r_out.01.old/breakdown_qd.txt
FILENAME_PREFIX=~/temp/breakdown
GNUPLOT_SCRIPT=~/temp/breakdown_gnuplot_script.gp
DELAY_COLUMN=6


CLASS_OTHER_FILE="$FILENAME_PREFIX""_OTHER.txt"
CLASS_CHAT_FILE="$FILENAME_PREFIX""_CHAT.txt"
CLASS_MAIL_FILE="$FILENAME_PREFIX""_MAIL.txt"
CLASS_MEDIA_FILE="$FILENAME_PREFIX""_MEDIA.txt"
CLASS_P2P_FILE="$FILENAME_PREFIX""_P2P.txt"
CLASS_SSH_FILE="$FILENAME_PREFIX""_SSH.txt"
CLASS_VOIP_FILE="$FILENAME_PREFIX""_VOIP.txt"
CLASS_WEB_FILE="$FILENAME_PREFIX""_WEB.txt"

LINES_OTHER_FILE="$FILENAME_PREFIX""_LINES_OTHER.txt"
LINES_CHAT_FILE="$FILENAME_PREFIX""_LINES_CHAT.txt"
LINES_MAIL_FILE="$FILENAME_PREFIX""_LINES_MAIL.txt"
LINES_MEDIA_FILE="$FILENAME_PREFIX""_LINES_MEDIA.txt"
LINES_P2P_FILE="$FILENAME_PREFIX""_LINES_P2P.txt"
LINES_SSH_FILE="$FILENAME_PREFIX""_LINES_SSH.txt"
LINES_VOIP_FILE="$FILENAME_PREFIX""_LINES_VOIP.txt"
LINES_WEB_FILE="$FILENAME_PREFIX""_LINES_WEB.txt"

## After a first run, deactivate it to go faster
#awk '{if($7=="\"OTHER\"" && $6!="NA") print $0}' $WINDOWED_QD_FILE > $CLASS_OTHER_FILE
#awk '{if($7=="\"CHAT\"" && $6!="NA") print $0}' $WINDOWED_QD_FILE > $CLASS_CHAT_FILE
#awk '{if($7=="\"MAIL\"" && $6!="NA") print $0}' $WINDOWED_QD_FILE > $CLASS_MAIL_FILE
#awk '{if($7=="\"MEDIA\"" && $6!="NA") print $0}' $WINDOWED_QD_FILE > $CLASS_MEDIA_FILE
#awk '{if($7=="\"P2P\"" && $6!="NA") print $0}' $WINDOWED_QD_FILE > $CLASS_P2P_FILE
#awk '{if($7=="\"SSH\"" && $6!="NA") print $0}' $WINDOWED_QD_FILE > $CLASS_SSH_FILE
#awk '{if($7=="\"VOIP\"" && $6!="NA") print $0}' $WINDOWED_QD_FILE > $CLASS_VOIP_FILE
#awk '{if($7=="\"WEB\"" && $6!="NA") print $0}' $WINDOWED_QD_FILE > $CLASS_WEB_FILE

## After a first run, deactivate it to go faster
#wc -l $CLASS_OTHER_FILE | cut -f1 -d" " > $LINES_OTHER_FILE
#wc -l $CLASS_CHAT_FILE | cut -f1 -d" " > $LINES_CHAT_FILE
#wc -l $CLASS_MAIL_FILE | cut -f1 -d" " > $LINES_MAIL_FILE
#wc -l $CLASS_MEDIA_FILE | cut -f1 -d" " > $LINES_MEDIA_FILE
#wc -l $CLASS_P2P_FILE | cut -f1 -d" " > $LINES_P2P_FILE
#wc -l $CLASS_SSH_FILE | cut -f1 -d" " > $LINES_SSH_FILE
#wc -l $CLASS_VOIP_FILE | cut -f1 -d" " > $LINES_VOIP_FILE
#wc -l $CLASS_WEB_FILE | cut -f1 -d" " > $LINES_WEB_FILE

LINES_OTHER=`cat $LINES_OTHER_FILE`
LINES_CHAT=`cat $LINES_CHAT_FILE`
LINES_MAIL=`cat $LINES_MAIL_FILE`
LINES_MEDIA=`cat $LINES_MEDIA_FILE`
LINES_P2P=`cat $LINES_P2P_FILE`
LINES_SSH=`cat $LINES_SSH_FILE`
LINES_VOIP=`cat $LINES_VOIP_FILE`
LINES_WEB=`cat $LINES_WEB_FILE`


PLOT_COMMAND="plot \"$CLASS_OTHER_FILE\" using (\$$DELAY_COLUMN+1):(1./$LINES_OTHER.) smooth cumulative title 'OTHER', "
PLOT_COMMAND=$PLOT_COMMAND"\"$CLASS_CHAT_FILE\" using (\$$DELAY_COLUMN+1):(1./$LINES_CHAT.) smooth cumulative title 'CHAT', "
PLOT_COMMAND=$PLOT_COMMAND"\"$CLASS_MAIL_FILE\" using (\$$DELAY_COLUMN+1):(1./$LINES_MAIL.) smooth cumulative title 'MAIL', "
PLOT_COMMAND=$PLOT_COMMAND"\"$CLASS_MEDIA_FILE\" using (\$$DELAY_COLUMN+1):(1./$LINES_MEDIA.) smooth cumulative title 'MEDIA', "
PLOT_COMMAND=$PLOT_COMMAND"\"$CLASS_P2P_FILE\" using (\$$DELAY_COLUMN+1):(1./$LINES_P2P.) smooth cumulative title 'P2P', "
PLOT_COMMAND=$PLOT_COMMAND"\"$CLASS_SSH_FILE\" using (\$$DELAY_COLUMN+1):(1./$LINES_SSH.) smooth cumulative title 'SSH', "
PLOT_COMMAND=$PLOT_COMMAND"\"$CLASS_VOIP_FILE\" using (\$$DELAY_COLUMN+1):(1./$LINES_VOIP.) smooth cumulative title 'VOIP', "
PLOT_COMMAND=$PLOT_COMMAND"\"$CLASS_WEB_FILE\" using (\$$DELAY_COLUMN+1):(1./$LINES_WEB.) smooth cumulative title 'WEB', "
PLOT_COMMAND=$PLOT_COMMAND"p25(x) with points, p50(x) with points, p75(x) with points; "
echo $PLOT_COMMAND

echo "Starting gnuplot scripting"

echo "set title 'queueing delay cdf';" > $GNUPLOT_SCRIPT
echo "set logscale x;" >> $GNUPLOT_SCRIPT
echo "set xrange [10:1200];" >> $GNUPLOT_SCRIPT
echo "set yrange [0:1];" >> $GNUPLOT_SCRIPT
echo "set xlabel 'queueing delay (ms)';" >> $GNUPLOT_SCRIPT
echo "set ylabel 'cdf';" >> $GNUPLOT_SCRIPT
echo "p25(x)=0.25;" >> $GNUPLOT_SCRIPT
echo "p50(x)=0.5;" >> $GNUPLOT_SCRIPT
echo "p75(x)=0.75;" >> $GNUPLOT_SCRIPT
echo $PLOT_COMMAND >> $GNUPLOT_SCRIPT

echo "pause 20; reread;" >> $GNUPLOT_SCRIPT


gnuplot $GNUPLOT_SCRIPT
