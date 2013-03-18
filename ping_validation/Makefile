#see: http://samkear.com/networking/iperf-commands-network-troubleshooting

#how many seconds the client must run
RUNTIME=2000000

all: load dbg srv netem cli 

clean:
	sudo ./network_emulation.sh clean

srv:
	iperf -s
	
netem:	
	sudo ./network_emulation.sh 1 1 fifo lo
	sudo ./network_emulation.sh 1 1 fifo lo
	
cli:
	iperf -t $(RUNTIME) -c localhost

#bidirectional
bidir:
	iperf -t $(RUNTIME) -c localhost -d
