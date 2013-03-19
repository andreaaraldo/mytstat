#see: http://samkear.com/networking/iperf-commands-network-troubleshooting

#how many seconds the client must run
RUNTIME=2000000
TARGET=localhost
DEV=lo
LOSS_PROBABILITY=0 #(percentage)

all: load dbg srv netem cli 

clean:
	sudo ./network_emulation.sh clean

srv:
	iperf -s
	
netem:	
	sudo ./network_emulation.sh 1 $(LOSS_PROBABILITY) fifo $(DEV)
	
cli:
	iperf -t $(RUNTIME) -c $(TARGET)

#bidirection
bidir:
	iperf -t $(RUNTIME) -c $(TARGET) -d
