import sys
import serial
import socket
import os
import stat
from time import sleep

class TransportError(Exception):
    """Custom exception to represent errors with a transport
    """
    def __init__(self, message):
        self.message = message

    def __str__(self):
        return self.message

class AbstractTransport:
    def __init__(self):
        raise NotImplementedError('abstract transports cannot be instantiated.')

    def close(self):
        raise NotImplementedError('Function not implemented')

    def read(self, length):
        raise NotImplementedError('Function not implemented')

    def raw(self, data, check=1):
        raise NotImplementedError('Function not implemented')

    def data(self, data):
        bytes = ["%d" % i for i in data]
        self.raw("file.write(string.char(" + ",".join(bytes) + "))\r")

    def echocheck(self, expected):
        i = 0
        keep = bytearray()
        while i < len(expected):  # '>'
            char = self.read(1)
            if len(char) == 0 or expected[i] != char[0]:
                raise TransportError('Echo check failed: "%s" != "%s"' % (expected.decode("utf-8"), keep.decode("utf-8")))
            i+=1
            keep += char

class SerialTransport(AbstractTransport):
    def __init__(self, port, baud, delay):
        self.port = port
        self.baud = baud
        self.serial = None
        self.delay = delay

        try:
            self.serial = serial.Serial(port, baud)
        except serial.SerialException as e:
            raise TransportError(e.strerror)

        self.serial.timeout = 3
        self.serial.interCharTimeout = 3

    def raw(self, data, check=True):
        if isinstance(data, str):
            data = data.encode("utf-8")
    
        if self.serial.inWaiting() > 0:
            self.serial.flushInput()
        self.serial.write(data)
        sleep(self.delay)
        if check:
            self.echocheck(data)

    def read(self, length):
        return self.serial.read(length)

    def close(self):
        self.serial.flush()
        self.serial.close()


class TcpSocketTransport(AbstractTransport):
    def __init__(self, host, port):
        self.host = host
        self.port = port
        self.socket = None

        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        except socket.error as e:
            raise TransportError(e.strerror)

        try:
            self.socket.connect((host, port))
        except socket.error as e:
            raise TransportError(e.strerror)
        # read intro from telnet server (see telnet_srv.lua)
        #self.socket.recv(50)

    def raw(self, data, check=True):
        if isinstance(data, str):
            data = data.encode("utf-8")
            
        self.socket.sendall(data)
        #if check:
        #    self.echocheck(data)

    def read(self, length):
        return self.socket.recv(length)

    def close(self):
        self.socket.close()


def create_transport(port, baud=9600, delay=0.05):

    is_serial = False

    try:
        is_serial = stat.S_ISCHR(os.lstat(port)[stat.ST_MODE])
    except:
        pass

    if not is_serial:
        data = port.split(':')
        host = data[0]
        if len(data) == 2:
            port = int(data[1])
        else:
            port = 9091
        return TcpSocketTransport(host, port)
    else:
        return SerialTransport(port, baud, delay)
