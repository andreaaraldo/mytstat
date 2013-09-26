set title 'queueing delay cdf';
set autoscale;
set xlabel 'qd(ms);
set ylabel 'how many windows';
plot "~/temp/prova.txt" u 6:(1)  smooth cumulative;
pause 200; reread;
