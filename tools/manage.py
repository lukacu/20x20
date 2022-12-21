#!/usr/bin/env python
#
# Based on ESP8266 luatool (http://esp8266.ru)


import sys
import serial
import traceback
import argparse
import os
import logging
from time import sleep
from cmd import Cmd


logger = logging.getLogger("manage")

root = os.path.dirname(os.path.realpath(__file__))

def exception_catch(func):
    def inner_function(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except Exception as e:
            traceback.print_exc()
            raise e
    return inner_function

class Commands(Cmd):
    prompt = "[?] "

    def __init__(self, transport):
        super().__init__()
        self._transport = transport
        self._quit = False

    def do_copy(self, arg):
        unpacker = lambda x,y=None:(x,y)
        file, name = unpacker(*arg.split(" "))
        run_copy(self._transport, file, name)

    def do_restart(self, _):
        run_restart(self._transport)

    def do_remove(self, name):
        run_remove(self._transport, name)

    def do_quit(self, _):
        self._quit = True
        return True

    def emptyline(self):
        return True

    @property
    def quit(self):
        return self._quit

def progress(iteration, total, prefix = '', suffix = '', decimals = 1, length = 100, fill = '█', printEnd = "\r"):
    """
    Call in a loop to create terminal progress bar
    @params:
        iteration   - Required  : current iteration (Int)
        total       - Required  : total iterations (Int)
        prefix      - Optional  : prefix string (Str)
        suffix      - Optional  : suffix string (Str)
        decimals    - Optional  : positive number of decimals in percent complete (Int)
        length      - Optional  : character length of bar (Int)
        fill        - Optional  : bar fill character (Str)
        printEnd    - Optional  : end character (e.g. "\r", "\r\n") (Str)
    """
    percent = ("{0:." + str(decimals) + "f}").format(100 * (iteration / float(total)))
    filledLength = int(length * iteration // total)
    bar = fill * filledLength + '-' * (length - filledLength)
    print(f'\r{prefix} |{bar}| {percent}% {suffix}', end = printEnd)
    # Print New Line on Complete
    if iteration == total: 
        print()

def command(serial, data, check=True):
    if isinstance(data, str):
        data = data.encode("utf-8")

    if serial.inWaiting() > 0:
        serial.flushInput()
    serial.write(data)
    sleep(0.05)
    if check:
        _echocheck(serial, data)

def _echocheck(serial, expected):
    i = 0
    keep = bytearray()
    while i < len(expected):  # '>'
        char = serial.read(1)
        if len(char) == 0 or expected[i] != char[0]:
            raise RuntimeError('Echo check failed: "%s" != "%s"' % (expected.decode("utf-8"), keep.decode("utf-8")))
        i+=1
        keep += char

def _read(transport):
    buffer = bytearray()
    while True:
        char = transport.read(1)
        if len(char) == 0:
            break
        buffer += char

    return buffer.decode("utf-8").strip()

def find_tiles(root):
    import json
    from os.path import isdir, isfile, join

    tiles = {}

    for e in os.listdir(root):
        if not isdir(join(root, e)):
            continue
        manifest = join(root, e, "tile.json")
        if not isfile(manifest):
            continue
        with open(manifest, "r") as handle:
            meta = json.load(handle)

        tiles[e] = meta
        tiles[e]["root"] = join(root, e)

    return tiles


def run_info(transport):
    transport.raw("=node.chipid()\r", 0)
    id=""
    while True:
        char = transport.read(1)
        if char == '' or char == chr(62):
            break
        if char.isdigit():
            id += char
    print("\n"+id)

def run_wifi_config(transport, ssid, passphrase):

    content = 'WIFI_SSID="%s"\nWIFI_PASSWORD="%s"\n' % (ssid, passphrase)

    push(transport, content, "_config.lua")


def run_hostname_config(transport, name):

    push(transport, name, "hostname")


def push(transport, content, name):
    import hashlib

    transport.timeout = 3
    transport.interCharTimeout = 3

    buffer_len = 32

    if isinstance(content, str):
        content = content.encode("utf-8")

    sha1 = hashlib.sha1()
    sha1.update(content)
    inhash = sha1.hexdigest()

    command(transport, "if run then run(-1) end\r", False)

    command(transport, "file.open(\"" + name + "\", \"w\")\r")
 
    position = 0

    while position < len(content):
        bytes = ["%d" % i for i in content[position:min(len(content), position+buffer_len)]]
        command(transport, "file.write(string.char(" + ",".join(bytes) + "))\r")
        position += buffer_len
        progress(position, len(content), prefix="Copy", length=10)

    command(transport, "file.flush()\r")
    command(transport, "file.close()\r")
    command(transport, 'print(encoder.toHex(crypto.fhash("sha1","%s"))) \r' % name)

    outhash = _read(transport)
    outhash = outhash.split("\n")[0].strip()

    if inhash != outhash:
        raise IOError("File copy failed %s != %s" % (inhash, outhash))

def copy(transport, source, name=None):

    if name is None:
        name = os.path.basename(source)

    with open(source, "rb") as filehandle:
        push(transport, filehandle.read(), name)

@exception_catch
def run_copy(transport, source, name=None):

    copy(transport, source, name)

@exception_catch
def run_remove(transport, name):
    command(transport, "file.remove(\"" + name + "\")\r", False)

def run_terminal(transport):

    import termios
    from serial.tools.miniterm import Miniterm

    fd = sys.stdin.fileno()
    defattr = termios.tcgetattr(fd)

    try:

        while True:

            terminal = Miniterm(transport, echo=False)
            terminal.exit_character = chr(0x1b)
            terminal.raw = False
            terminal.set_rx_encoding("UTF-8")
            terminal.set_tx_encoding("UTF-8")

            terminal.start()

            terminal.join(True)

            #terminal.join()

            termios.tcsetattr(fd, termios.TCSADRAIN, defattr)

            cmd = Commands(transport)
            cmd.cmdloop()
            if cmd.quit:
                break


    except KeyboardInterrupt:
        pass

def run_format(transport):

    command(transport, "file.format()\r")

@exception_catch
def run_restart(transport):
    command(transport, "node.restart()\r", False)

def run_list(transport):

    command(transport, "local l = file.list();for k,v in pairs(l) do print(k..' ('..v .. ' bytes)'); end\r", False)
    file_list = []
    fn = bytearray()
    while True:
        char = transport.read(1)
        if len(char) == 0 or char[0] == 62:
            break
        if char not in [b'\r', b'\n']:
            fn += char
        else:
            if len(fn) > 0:
                name = fn.decode("utf-8").strip()
                file_list.append(name)
            fn = bytearray()

    for item in file_list:
        print(item)

def run_init(transport):

    format(transport)
    
    copy(transport, os.path.join(root, "..", "core", "main.lua"))
    copy(transport, os.path.join(root , "..", "core", "init.lua"))

    run_restart(transport)

def main():

    parser = argparse.ArgumentParser(description='Tile manager', prog="manage")
    parser.add_argument("--debug", "-d", default=False, help="Turn on debug", required=False, action='store_true')
    parser.add_argument('-p', '--port', default='/dev/ttyUSB0', help='Device name, defaults to /dev/ttyUSB0')
    parser.add_argument('-b', '--baud', default=115200, help='Baudrate, defaults to 115200')
    subparsers = parser.add_subparsers(help='commands', dest='action', title="Commands")

    init_parser = subparsers.add_parser('init', help='Format filesystem, initialize core code and restart')

    restart_parser = subparsers.add_parser('restart', help='Restart system')

    terminal_parser = subparsers.add_parser('terminal', help='Interactive terminal')

    list_parser = subparsers.add_parser('list', help='List files on the device')
    list_parser.add_argument("-a", "--all", default="store_true", help='List all files')

    push_parser = subparsers.add_parser('copy', help='Copies files to the device')
    push_parser.add_argument("--force", "-f", default=False, help="Force upload even if file exists", required=False, action='store_true')
    push_parser.add_argument('-c', '--compile', action='store_true',  help='Compile lua to lc after upload')
    push_parser.add_argument('-r', '--restart', action='store_true',  help='Restart MCU after upload')
    push_parser.add_argument('files', nargs=argparse.REMAINDER, help='Files to upload')

    rm_parser = subparsers.add_parser('rm', help='Removes files from the device')
    rm_parser.add_argument('files', nargs=argparse.REMAINDER, help='Files to remove')

    wifi_parser = subparsers.add_parser('wifi', help='Configure WiFi')
    wifi_parser.add_argument('ssid', help='SSID of the access point')
    wifi_parser.add_argument('passphrase', default="", help='SSID of the access point')

    hostname_parser = subparsers.add_parser('hostname', help='Configure hostname')
    hostname_parser.add_argument('name', help='Name to be used')

    args = parser.parse_args()

    logger.setLevel(logging.INFO)
    if args.debug:
        logger.setLevel(logging.DEBUG)
    else:
        logger.addHandler(logging.StreamHandler())

    try:

        transport = serial.serial_for_url(
            args.port, args.baud)

        if args.action == "copy":
            for f in args.files:
                if f.find("=") != -1:
                    f, name = f.split("=")
                    run_copy(transport, f, name)
                else:
                    run_copy(transport, f)
        elif args.action == "init":
            run_init(transport)
        elif args.action == "restart":
            run_restart(transport)
        elif args.action == "terminal":
            run_terminal(transport)
        elif args.action == "wifi":
            run_wifi_config(transport, args.ssid, args.passphrase)
        elif args.action == "hostname":
            run_hostname_config(transport, args.name)
        elif args.action == "rm":
            for f in args.files:
                run_remove(transport, f)  
        elif args.action == "list":
            run_list(transport)
        else:
            parser.print_help()

        transport.close()

    except Exception as e:
        logger.exception(e)
        sys.exit(-1)


if __name__ == '__main__':

    main()

