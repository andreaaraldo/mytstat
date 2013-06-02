#see: http://samkear.com/networking/iperf-commands-network-troubleshooting

#how many seconds the client must run
RUNTIME=2000000
TARGET=137.194.164.37
DEV=eth0
LOSS_PROBABILITY=0 #(percentage)
LINK_CAPACITY=1000 #link capacity to emulate (in kbit)

all: load dbg srv netem cli 

clean:
	sudo ./network_emulation.sh clean

srv:
	iperf -s
	
netem:	
	sudo ./network_emulation.sh $(LINK_CAPACITY) $(LOSS_PROBABILITY) fifo $(DEV)
	
cli:
	iperf -t $(RUNTIME) -c $(TARGET)

#bidirection
bidir:
	iperf -t $(RUNTIME) -c $(TARGET) -d
