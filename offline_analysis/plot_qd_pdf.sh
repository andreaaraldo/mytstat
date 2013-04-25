#the windowed qd must be the first column

if [ $# -ne 1 ]
then
	echo "usage:    $0 <aggregate_file>"
	exit 1; 
fi

AGGREGATE_FILE=$1
GNUPLOT_SCRIPT=~/temp/gnuplot.plot


WIDTH=10
HALF_WIDTH=`expr $WIDTH / 2`
echo "half width" $HALF_WIDTH

echo "set title 'queueing delay pdf';" > $GNUPLOT_SCRIPT
echo "set autoscale;" >> $GNUPLOT_SCRIPT
echo "set xrange [0:1000];" >> $GNUPLOT_SCRIPT
echo "set yrange [0:*];" >> $GNUPLOT_SCRIPT
echo "set xlabel 'qd(ms)';" >> $GNUPLOT_SCRIPT
echo "set ylabel 'how many windows';" >> $GNUPLOT_SCRIPT
echo "hist(x)=$WIDTH*int(x/$WIDTH)+$HALF_WIDTH;" >> $GNUPLOT_SCRIPT
echo "set style fill solid $HALF_WIDTH;" >> $GNUPLOT_SCRIPT
echo "set tics out nomirror;" >> $GNUPLOT_SCRIPT
echo "set boxwidth $WIDTH;" >> $GNUPLOT_SCRIPT
echo "plot \"$AGGREGATE_FILE\" u (hist(\$1)):(1.0) smooth freq with boxes;" >> $GNUPLOT_SCRIPT
echo "pause 2; reread;" >> $GNUPLOT_SCRIPT


gnuplot $GNUPLOT_SCRIPT
