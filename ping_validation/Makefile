all: load dbg srv netem cli 

clean:
	sudo ./network_emulation.sh clean

srv:
	iperf -s &
	
netem:	
	sudo ./network_emulation.sh 1 1 fifo
	
cli:
	iperf -t 20 -c localhost

