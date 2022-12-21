#!/usr/bin/env python
#

import sys
import os
import random
import json
import requests
import concurrent.futures
import traceback

import cv2 as cv
import numpy as np

import lupa
from lupa import LuaRuntime

root = os.path.dirname(os.path.dirname(__file__))

def exception_printer(func):
    def inner_function(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except Exception as e:
            traceback.print_exc()
            raise e
    return inner_function

class Environment():

    def __init__(self, root) -> None:
        self._lua = LuaRuntime(unpack_returned_tuples=True, encoding=None)
        self._executor = concurrent.futures.ThreadPoolExecutor(max_workers=5)
        self._root = root

    @property
    def lua(self) -> LuaRuntime:
        return self._lua

    @property
    def root(self) -> str:
        return self._root

    @property
    def executor(self) -> concurrent.futures.ThreadPoolExecutor:
        return self._executor

class Module():

    def __init__(self, environment: Environment) -> None:
        self.environment = environment

class Node(Module):

    def __init__(self, environment: Environment) -> None:
        super().__init__(environment)

    def random(self, a, b):
        return random.randint(a, b)  

class HTTP(Module):

    def __init__(self, environment: Environment) -> None:
        super().__init__(environment)

    # http.get(url, headers, callback)

    def get(self, url, headers, callback):
        self.request(url, b"GET", headers, b"", callback)

    # http.request(url, method, headers, body, callback)

    def request(self, url, method, headers, body, callback):
        if headers is not None:
            headers = headers.decode("ascii").split("\n\r")
        else:
            headers = {}

        url = url.decode("ascii")
        method = method.decode("ascii")

        @exception_printer
        def handle():
            session = requests.Session()
            response = session.get(url)
            #request = session.request(method, url, headers=headers)
            #response = session.send(request.prepare(), stream=False)
            headers = "\n\r".join(["%s: %s" % (k, v) for k, v in response.headers.items()]).encode("ascii")
            callback(response.status_code, response.content, headers)
  
        self.environment.executor.submit(handle)


class JSON(Module):

    def __init__(self, environment: Environment) -> None:
        super().__init__(environment)
    class JSONEncoder():

        def __init__(self, environment, options):
            self._environment = environment

        def read(self, o):
            return json.dumps(o).encode("ascii")

    class JSONDecoder():

        def __init__(self, environment, options):
            self._environment = environment
            self._buffer = b""

        def write(self, s):
            self._buffer += s

        def result(self):
            def convert(obj):
                c = {}
                for k, v in obj.items():
                    if isinstance(k, str):
                        k = k.encode("ascii")
                    if isinstance(v, dict):
                        v = convert(v)
                    c[k] = v
                return self._environment.lua.table_from(c)

            o = json.loads(self._buffer)
            self._buffer = b""
            o = convert(o)
            return o

    def encoder(self, options):
        return JSON.JSONEncoder(self.environment, options)

    def decoder(self, options):
        return JSON.JSONDecoder(self.environment, options)

    @exception_printer
    def decode(self, s, options=None):
        d = self.decoder(options)
        d.write(s)
        return d.result() 
        
    @exception_printer
    def encode(self, o, options=None):
        e = self.encoder(options)
        return e.read(o)

class File():

    def __init__(self, handle):
        self._handle = handle

    def seek(self, mode, position):
        if mode == b"set":
            self._handle.seek(position)

    def read(self, count):
        data = self._handle.read(count)
        return data

class Filesystem(Module):

    def __init__(self, environment: Environment) -> None:
        super().__init__(environment)


    def open(self, filename, mode):
        return File(open(os.path.join(self.environment.root, filename.decode("ascii")), mode.decode("ascii") + "b"))

class Buffer():

    def __init__(self, size, channels=3):
        self._buffer = np.zeros((size, channels), dtype=np.uint8)

    @staticmethod
    def newBuffer(size, channels):
        return Buffer(size, channels)

    def set(self, i, *args):
        i = i - 1
        if i < 0 or i >= self._buffer.shape[0]:
            raise RuntimeError("Out of bounds - index %d not within 1-%d" % (i+1, self._buffer.shape[0]))

        if isinstance(args[0], bytes):
            data = np.frombuffer(args[0], dtype=np.uint8)
            data = data.reshape((int(data.shape[0] / 3), 3))

            if data.shape[0] > self._buffer.shape[0] - i:
                raise RuntimeError("Out of bounds - index %d not within 1-%d" % (i+1, self._buffer.shape[0]))

            buffer_start = min(max(i, 0), self._buffer.shape[0])
            buffer_end = min(max(data.shape[0] + buffer_start, 0), self._buffer.shape[0])
            data_start = min(max(-buffer_start + i, 0), data.shape[0])
            data_end = min(max(buffer_end - buffer_start , 0), data.shape[0])

            length = buffer_end - buffer_start

            if length < 1:
                return
            self._buffer[buffer_start:buffer_end, :] = data[data_start:data_end, :]
        else:
            if len(args) == 1 and isinstance(args[0], (tuple, list)):
                args = args[0]
            for c, v in enumerate(args):
                self._buffer[i, c] = v

    def get(self, i):
        if self.channels() == 1:
            return int(self._buffer[i-1, 0])
        return self._buffer[i-1, :].tobytes()

    def fill(self, *args):
        for i, v in enumerate(args):
            self._buffer[:, i] = v

    def fade(self, d):
        self._buffer = np.clip(self._buffer.astype(np.int16) / d, 0, 255).astype(np.uint8)

    def size(self):
        return self._buffer.shape[0]

    def channels(self):
        return self._buffer.shape[1]

    def replace(self, input, offset = 1):
        assert self.channels() == input.channels()
        length = input.size() - offset + 1
        self._buffer[offset-1:length+offset, :] = input._buffer[0:length, :]

    def map(self, f, buffer, offset = 1, length = -1):
        if length == -1:
            length = min(self.size() + offset - 1, buffer.size())
        for i in range(0, length):
            self.set(i + 1, *f(*buffer._buffer[i + offset-1, :].tolist()))

class Screen():

    def __init__(self, width, height):
        self._width = width
        self._height = height
        self._buffer = Buffer(width * height)

    @property
    def width(self):
        return 20

    @property
    def height(self):
        return 20

    @property
    def buffer(self):
        return self._buffer

    def set(self, x, y, r, g, b):
        i = (x-1) + (y-1) * self._width + 1
        self._buffer.set(i, r, g, b)

def main():

    name = sys.argv[1]

    env = Environment(os.path.join(root, "tiles", name))

    def load_script(lua, filename):
        with open(filename, "r") as source:
            source = source.read()
            lua.execute(source)

    env.lua.globals()[b"pixbuf"] = Buffer
    env.lua.globals()[b"sjson"] = JSON(env)
    env.lua.globals()[b"http"] = HTTP(env)

    env.lua.globals()[b"node"] = Node(env)
    env.lua.globals()[b"file"] = Filesystem(env)

    os.chdir(os.path.join(root, "tiles", name))

    env.lua.execute('dofile("%s")' % os.path.join(root, "core", "utilities.lua"))
    env.lua.execute('dofile("%s")' % os.path.join(root, "core", "sprites.lua"))
    main, _ = env.lua.eval('require("%s")' % os.path.join("main"))

    screen = Screen(20, 20)

    state = None

    while True:
        state = main(state, screen)

        image = np.reshape(screen.buffer._buffer, (screen.height, screen.width, 3))
        image = image[:, :, (1, 0, 2)] # We are working with GRB ordering
        image = cv.cvtColor(image, cv.COLOR_RGB2BGR)
        image = cv.resize(image, (400, 400), -1, -1, interpolation=cv.INTER_NEAREST)

        cv.imshow("Screen", image)

        if cv.waitKey(50) != -1:
            break


if __name__ == "__main__":
    main()


