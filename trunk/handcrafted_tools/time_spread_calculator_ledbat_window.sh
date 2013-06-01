#It calculates (in seconds) the difference between the first window left edge and the last one
#of ledbat_window_log file (referring to revision 18)

LEDBAT_WINDOW_LOG=$1;

MIN="$(cut -f4 -d' '  $LEDBAT_WINDOW_LOG | sort -g |head -n1)"

MAX="$(cut -f4 -d' '  $LEDBAT_WINDOW_LOG | sort -g |tail -n1)"

calc $MAX/1e6 - $MIN/1e6;

