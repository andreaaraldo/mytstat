import socket
import sys

# Create a TCP/IP socket
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

# Connect the socket to the port where the server is listening
server_address = ('localhost', 10000)
print >>sys.stderr, 'connecting to %s port %s' % server_address
sock.connect(server_address)

try:
    
    while True:
	    # Send data
	    message = 'This is the message.  It will be repeated.'
	    print >>sys.stderr, 'sending "%s"' % message
	    for x in range(0, 1):
		    sock.sendall(message)
            
finally:
    print >>sys.stderr, 'closing socket'
    sock.close()
