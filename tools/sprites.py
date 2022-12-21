# Reading an animated GIF file using Python Image Processing Library - Pillow

import sys
import os
import struct
import argparse

from PIL import Image, ImageColor
from PIL import GifImagePlugin

import numpy as np

def main():

    parser = argparse.ArgumentParser(description='NodeMCU app manager', prog="nodeamg")
    parser.add_argument("--debug", "-d", default=False, help="Turn on debug", required=False, action='store_true')
    parser.add_argument('--width', default=None, type=int, help='Tile width')
    parser.add_argument('--height', default=None, type=int, help='Tile height')
    parser.add_argument('--select', default=None, help='Limit selected tiles')
    parser.add_argument('--background', default="black", help='Background color')
    parser.add_argument('--format', choices=("rgb", "rgbw", "grb", "grbw"), default="grb")
    parser.add_argument('filename') 

    args = parser.parse_args()

    source = Image.open(args.filename)
    output = os.path.splitext(args.filename)[0] + ".dat"

    tile_width = source.width if args.width is None else args.width
    tile_height = source.height if args.height is None else args.height

    assert source.width % tile_width == 0
    assert source.height % tile_height == 0

    frames = source.n_frames

    size = (tile_width, tile_height)

    background = Image.new("RGBA", size, ImageColor.getrgb(args.background))

    content = bytearray()

    count = 0
    total = int((source.width / tile_width) * (source.height / tile_height) * frames)

    if args.select is None:
        selection = list(range(0,total))
    else:
        selection = [int(x) for x in args.select.split(",")]

    tile = 0

    for y in range(0, source.height, tile_height):
        for x in range(0, source.width, tile_width):
            if tile in selection:
                for i in range(0, frames):
                    source.seek(i)
                    frame = source.crop((x, y, x + tile_width, y + tile_height)).convert()
                    frame = Image.alpha_composite(background, frame)
                    frame = np.asarray(frame)[:, :, 0:3]
                    if args.format == "grb":
                        frame = frame[:, :, (1, 0, 2)]
                    elif args.format == "grbw":
                        frame = frame[:, :, (1, 0, 2)]
                        frame = np.stack((frame, np.mean(frame, axis=2, keepdims=True)), axis=2)
                    elif args.format == "rgbw":
                        frame = np.stack((frame, np.mean(frame, axis=2, keepdims=True)), axis=2)
                    content += frame.tobytes()
                    count += 1
            tile += 1
            
    content = struct.pack("3H", count, *size) + content
            
    with open(output, "wb") as out:
        out.write(content)

if __name__ == "__main__":
    main()

