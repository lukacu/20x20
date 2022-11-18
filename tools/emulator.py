#!/usr/bin/env python
#

import sys
import os
import math
import random

import cv2 as cv
import numpy as np

import lupa
from lupa import LuaRuntime

root = os.path.dirname(os.path.dirname(__file__))

class Node():

    def random(self, a, b):
        return random.randint(a, b)  

class File():

    def __init__(self, handle):
        self._handle = handle

    def seek(self, mode, position):
        if mode == b"set":
            self._handle.seek(position)

    def read(self, count):
        data = self._handle.read(count)
        return data

class Filesystem():

    def __init__(self, root):
        self._root = root

    def open(self, filename, mode):
        return File(open(os.path.join(self._root, filename.decode("ascii")), mode.decode("ascii") + "b"))

class Buffer():
   
    def __init__(self, size):
        self._buffer = np.zeros((size, 3), dtype=np.uint8)

    def set(self, i, r, g = None, b = None):
        i = i - 1
        if g is None:
            data = np.frombuffer(r, dtype=np.uint8)
            data = data.reshape((int(data.shape[0] / 3), 3))

            buffer_start = min(max(i, 0), self._buffer.shape[0])
            buffer_end = min(max(data.shape[0] + buffer_start, 0), self._buffer.shape[0])
            data_start = min(max(-buffer_start + i, 0), data.shape[0])
            data_end = min(max(buffer_end - buffer_start , 0), data.shape[0])

            length = buffer_end - buffer_start

            if length < 1:
                return
            self._buffer[buffer_start:buffer_end, :] = data[data_start:data_end, :]
        else:
            self._buffer[i, :] = (r, g, b)

    def fill(self, r, g, b):
        self._buffer[:, 0] = r
        self._buffer[:, 1] = g
        self._buffer[:, 2] = b

    def fade(self, d):
        self._buffer = np.clip(self._buffer.astype(np.int16) - d, 0, 255).astype(np.uint8)

    def size(self):
        return self._buffer.shape[0]

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

    lua = LuaRuntime(unpack_returned_tuples=True, encoding=None)

    def load_script(lua, filename):
        with open(filename, "r") as source:
            source = source.read()
            lua.execute(source)

    lua.globals()[b"node"] = Node()
    lua.globals()[b"file"] = Filesystem(os.path.join(root, "tiles", name))

    load_script(lua, os.path.join(root, "core", "utilities.lua"))
    load_script(lua, os.path.join(root, "core", "sprites.lua"))
    load_script(lua, os.path.join(root, "tiles", name, "main.lua"))

    screen = Screen(20, 20)
    main = lua.globals()[name.encode("ascii")]

    state = None

    while True:
        state = main(state, screen)

        image = cv.cvtColor(np.reshape(screen.buffer._buffer, (screen.height, screen.width, 3)), cv.COLOR_RGB2BGR)
        image = cv.resize(image, (400, 400), -1, -1, interpolation=cv.INTER_NEAREST)

        cv.imshow("Screen", image)

        if cv.waitKey(50) != -1:
            break


if __name__ == "__main__":
    main()


