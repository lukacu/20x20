#!/usr/bin/env python
#
# Based on ESP8266 luatool (http://esp8266.ru)


import sys
import serial
import socket
import argparse
import os
import logging
import threading

from ._transport import create_transport

logger = logging.getLogger("install")

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

def run_prompt(transport):

    connected = True

    def handle(transport):
        line = bytearray()
    
        while True:
            char = transport.read(1)
            if len(char) == 0:
                break
            line += char
            print(char)
            if char[0] == 10:
                sys.stdout.write(line.decode("urf-8"))
                sys.stdout.flush()
                line = bytearray()
    
        connected = False
    
    thread = threading.Thread(target=handle, args=(transport,))
    thread.start()   

    try:

        while connected:
            line = input("> ")
            transport.raw(line + "\r")
            
    except KeyboardInterrupt:
        pass
        
    transport.close()

def run_wifi_config(transport, ssid, passphrase):

    content = 'WIFI_SSID="%s"\nWIFI_PASSWORD="%s"\n' % (ssid, passphrase)

    run_push(transport, content, "_config.lua")


def run_hostname_config(transport, name):

    run_push(transport, name, "hostname")


def run_push(transport, content, name):

    buffer_len = 32

    if isinstance(content, str):
        content = content.encode("utf-8")
    transport.raw("file.open(\"" + name + "\", \"w\")\r")
        
    position = 0

    while position < len(content):
        transport.data(content[position:min(len(content), position+buffer_len)])
        position += buffer_len

    transport.raw("file.flush()\r")
    transport.raw("file.close()\r")


def run_copy(transport, source, name=None):

    if name is None:
        name = os.path.basename(source)

    with open(source, "rb") as filehandle:
        run_push(transport, filehandle.read(), name)

def run_remove(transport, name):

    transport.raw("file.remove(\"" + name + "\")\r")

def run_format(transport):

    transport.raw("file.format()\r")

def run_restart(transport):

    transport.raw("node.restart()\r")

def run_list(transport):

    transport.raw("local l = file.list();for k,v in pairs(l) do print(k..' ('..v .. ' bytes)'); end\r", 0)
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
    
    source_dir = os.path.dirname(os.path.realpath(__file__))
    
    run_copy(transport, os.path.join(source_dir, "_bootstrap.lua"))
    run_copy(transport, os.path.join(source_dir, "init.lua"))

    run_restart(transport)

def main():

    parser = argparse.ArgumentParser(description='NodeMCU app manager', prog="nodeamg")
    parser.add_argument("--debug", "-d", default=False, help="Turn on debug", required=False, action='store_true')
    parser.add_argument('-p', '--port', default='/dev/ttyUSB0', help='Device name, defaults to /dev/ttyUSB0')
    parser.add_argument('-b', '--baud', default=115200, help='Baudrate, defaults to 115200')
    subparsers = parser.add_subparsers(help='commands', dest='action', title="Commands")

    init_parser = subparsers.add_parser('init', help='Format filesystem, initialize manager bootloader and restart')

    restart_parser = subparsers.add_parser('restart', help='Restart system')

    prompt_parser = subparsers.add_parser('prompt', help='Open interactive prompt')

    list_parser = subparsers.add_parser('list', help='List files on the device')
    list_parser.add_argument("-a", "--all", default="store_true", help='List all files')

    push_parser = subparsers.add_parser('push', help='Pushes files to the device')
    push_parser.add_argument("--force", "-f", default=False, help="Force upload even if file exists", required=False, action='store_true')
    push_parser.add_argument('-c', '--compile', action='store_true',  help='Compile lua to lc after upload')
    push_parser.add_argument('-r', '--restart', action='store_true',  help='Restart MCU after upload')
    push_parser.add_argument('files', nargs=argparse.REMAINDER, help='Files to upload')

    rm_parser = subparsers.add_parser('rm', help='Removes files from the device')
    rm_parser.add_argument('files', nargs=argparse.REMAINDER, help='Files to remove')

    wifi_parser = subparsers.add_parser('wifi', help='Configure WiFi')
    wifi_parser.add_argument('ssid', help='SSID of the access point')
    wifi_parser.add_argument('passphrase', default="", help='SSID of the access point')

    hostname_parser = subparsers.add_parser('hostname', help='Configure node hostname')
    hostname_parser.add_argument('name', help='Name of the node')

    args = parser.parse_args()

    logger.setLevel(logging.INFO)
    if args.debug:
        logger.setLevel(logging.DEBUG)
        logger.addHandler(RichHandler(rich_tracebacks=args.debug, console=Console(stderr=True)))
    else:
        logger.addHandler(logging.StreamHandler())

    try:

        transport = create_transport(args.port, args.baud)    

        if args.action == "push":
            for f in args.files:
                run_copy(transport, f)
        elif args.action == "init":
            run_init(transport)
        elif args.action == "restart":
            run_restart(transport)
        elif args.action == "prompt":
            run_prompt(transport)
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

