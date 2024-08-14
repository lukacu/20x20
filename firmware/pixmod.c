// Module for advanced pixbuf manipulation, primarly for performing 2D graphics operations on pixbufs

// Based on: https://github.com/nodemcu/nodemcu-firmware/wiki/%5BDRAFT%5D-How-to-write-a-C-module

#ifndef _EMULATOR_MODE_

#include "module.h"
#include "lauxlib.h"
#include "lmem.h"
#include "platform.h"

#endif

#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <assert.h>
#include <stdint.h>

typedef struct pixelbuffer
{
  uint8_t bpp;
  uint16_t width;
  uint16_t height;
  uint16_t stride;
  uint8_t *data;
} pixelbuffer_t;

#ifndef _EMULATOR_MODE_

#include "pixbuf.h"
#include "color_utils.h"

#ifdef LUA_USE_MODULES_PIXMOD_EFFECTS
#ifndef LUA_USE_MODULES_PIXBUF
#error module pixbuf is required for pixmod
#endif
#ifndef LUA_USE_MODULES_COLOR_UTILS
#error module color_utils is required for pixmod
#endif
#endif
static pixelbuffer_t wrap_buffer(pixbuf *buf, int width, int height, int offset, int stride)
{
  pixelbuffer_t pb;
  assert(buf != NULL);
  assert(offset >= 0);
  pb.width = width;
  pb.height = height;
  if (stride == 0)
    stride = width * buf->nchan;
  pb.stride = stride;
  pb.data = buf->values + offset * buf->nchan;
  pb.bpp = buf->nchan;
  assert(pb.data != NULL);
  assert(buf->npix >= stride * height + offset * buf->nchan);
  return pb;
}

#define DEBUG_PRINT(...) 

#else
#include <stdio.h>

#define DEBUG_PRINT(...) printf(__VA_ARGS__)

static pixelbuffer_t wrap_buffer(uint8_t *data, int width, int height, int bpp, int offset, int stride)
{
  pixelbuffer_t pb;
  assert(offset >= 0);
  assert(bpp > 0);
  if (stride == 0)
    stride = width * bpp;

  pb.width = width;
  pb.height = height;
  pb.stride = stride;
  pb.data = data + offset * bpp;
  pb.bpp = bpp;
  return pb;
}
#endif

static uint32_t _color_pack(int r, int g, int b)
{
  // Clamp values to 0-255
  r = (r < 0) ? 0 : ((r > 255) ? 255 : r);
  g = (g < 0) ? 0 : ((g > 255) ? 255 : g);
  b = (b < 0) ? 0 : ((b > 255) ? 255 : b);

  return ((r & 0xFF) << 16) | ((g  & 0xFF) << 8) | (b & 0xFF);
}

static uint32_t _pixmod_get(pixelbuffer_t *pixbuf, int x, int y)
{
  if (x < 0 || x >= pixbuf->width || y < 0 || y >= pixbuf->height)
    return 0;
  uint8_t *p = pixbuf->data + y * pixbuf->stride + x * pixbuf->bpp;
  switch (pixbuf->bpp)
  {
  case 1:
    return *p;
  case 2:
    return *(uint16_t *)p;
  case 3:
    return p[0] | (p[1] << 8) | (p[2] << 16);
  case 4:
    return *(uint32_t *)p;
  }
  return 0;
}

static void _pixmod_set(pixelbuffer_t *pixbuf, int x, int y, uint32_t color)
{
  if (x < 0 || x >= pixbuf->width || y < 0 || y >= pixbuf->height)
    return;
  uint8_t *p = pixbuf->data + y * pixbuf->stride + x * pixbuf->bpp;
  switch (pixbuf->bpp)
  {
  case 1:
    *p = color;
    break;
  case 2:
    *(uint16_t *)p = color;
    break;
  case 3:
    p[0] = color & 0xFF;
    p[1] = (color >> 8) & 0xFF;
    p[2] = (color >> 16) & 0xFF;
    break;
  case 4:
    *(uint32_t *)p = color;
    break;
  }
}

static void _pixmod_line(pixelbuffer_t *pixbuf, int x0, int y0, int x1, int y1, uint32_t color)
{
  // Draw line using Bresenham's algorithm
  int dx = abs(x1 - x0);
  int dy = abs(y1 - y0);
  int sx = x0 < x1 ? 1 : -1;
  int sy = y0 < y1 ? 1 : -1;
  int err = dx - dy;
  int e2;

  for (;;)
  {
    _pixmod_set(pixbuf, x0, y0, color);
    if (x0 == x1 && y0 == y1)
      break;
    e2 = 2 * err;
    if (e2 > -dy)
    {
      err -= dy;
      x0 += sx;
    }
    if (e2 < dx)
    {
      err += dx;
      y0 += sy;
    }
  }
}

static void _pixmod_add(pixelbuffer_t *pixbuf, int value)
{
  for (int y = 0; y < pixbuf->height; y++)
  {
    for (int x = 0; x < pixbuf->width; x++)
    {
      uint32_t color = _pixmod_get(pixbuf, x, y);
      int r = (color >> 16) & 0xFF;
      int g = (color >> 8) & 0xFF;
      int b = color & 0xFF;
      r = r + value;
      g = g + value;
      b = b + value;
      //DEBUG_PRINT("x: %d, y: %d, r: %d, g: %d, b: %d\n", x, y, r, g, b);
      _pixmod_set(pixbuf, x, y, _color_pack(r, g, b));
    }
  }
}

static void _pixmod_fill(pixelbuffer_t *pixbuf, int x, int y, int width, int height, uint32_t color)
{
  for (int i = 0; i < height; i++)
  {
    for (int j = 0; j < width; j++)
    {
      _pixmod_set(pixbuf, x + j, y + i, color);
    }
  }
}


/*
static int pixmod_mask(lua_State *L)
{
  PIXBUF *pixbuf = (PIXBUF *)luaL_checkudata(L, 1, "pixbuf.buffer");
  PIXBUF *mask = (PIXBUF *)luaL_checkudata(L, 2, "pixbuf.buffer");
  int x = luaL_checkinteger(L, 3);
  int y = luaL_checkinteger(L, 4);
  int w = luaL_checkinteger(L, 5);
  int h = luaL_checkinteger(L, 6);
  int dx = luaL_checkinteger(L, 7);
  int dy = luaL_checkinteger(L, 8);
  int dw = luaL_checkinteger(L, 9);
  int dh = luaL_checkinteger(L, 10);
  pixbuf_mask(pixbuf, mask, x, y);
  return 0;
}

// bilt one image to another, both images must be the same type
static int pixmod_bilt(lua_State *L)
{
  PIXBUF *src = (PIXBUF *)luaL_checkudata(L, 1, "pixbuf.buffer");
  int sw = luaL_checkinteger(L, 2);
  int sh = luaL_checkinteger(L, 3);
  PIXBUF *dst = (PIXBUF *)luaL_checkudata(L, 4, "pixbuf.buffer");
  int dw = luaL_checkinteger(L, 5);
  int dh = luaL_checkinteger(L, 6);

  int x = luaL_checkinteger(L, 7);
  int y = luaL_checkinteger(L, 8);
  int w = luaL_checkinteger(L, 9);
  int h = luaL_checkinteger(L, 10);

  for (int i = 0; i < h; i++)
  {
    for (int j = 0; j < w; j++)
    {
      int src_x = j * sw / w;
      int src_y = i * sh / h;
      int dst_x = x + j;
      int dst_y = y + i;
      uint32_t color = pixbuf_get(src, src_x, src_y);
      pixbuf_set(dst, dst_x, dst_y, color);
    }
  }

  return 1;
}

static int pixmod_fill(lua_State *L)
{
  PIXBUF *pixbuf = (PIXBUF *)luaL_checkudata(L, 1, "pixbuf.buffer");
  int w = luaL_checkinteger(L, 2);
  int h = luaL_checkinteger(L, 3);
  int x = luaL_checkinteger(L, 4);
  int y = luaL_checkinteger(L, 5);
  int width = luaL_checkinteger(L, 6);
  int height = luaL_checkinteger(L, 7);
  uint32_t color = luaL_checkinteger(L, 8);
  pixbuf_fill(pixbuf, x, y, width, height, color);
  return 0;
}
*/
#ifndef _EMULATOR_MODE_

static int pixmod_set(lua_State *L)
{
  pixbuf *source = pixbuf_from_lua_arg(L, 1);
  int w = luaL_checkinteger(L, 2);
  int h = luaL_checkinteger(L, 3);
  int x = luaL_checkinteger(L, 4);
  int y = luaL_checkinteger(L, 5);

  uint32_t color = _color_pack(luaL_checkinteger(L, 6), luaL_checkinteger(L, 7), luaL_checkinteger(L, 8));
  pixelbuffer_t pb = wrap_buffer(source, w, h, 0, 0);
  _pixmod_set(&pb, x-1, y-1, color);
  return 0;
}

static int pixmod_line(lua_State *L)
{
  pixbuf *source = pixbuf_from_lua_arg(L, 1);
  int w = luaL_checkinteger(L, 2);
  int h = luaL_checkinteger(L, 3);
  int x0 = luaL_checkinteger(L, 4);
  int y0 = luaL_checkinteger(L, 5);
  int x1 = luaL_checkinteger(L, 6);
  int y1 = luaL_checkinteger(L, 7);

  uint32_t color = _color_pack(luaL_checkinteger(L, 8), luaL_checkinteger(L, 9), luaL_checkinteger(L, 10));
  pixelbuffer_t pb = wrap_buffer(source, w, h, 0, 0);
  _pixmod_line(&pb, x0-1, y0-1, x1-1, y1-1, color);
  return 0;
}

static int pixmod_add(lua_State *L)
{
  pixbuf *source = pixbuf_from_lua_arg(L, 1);
  int w = luaL_checkinteger(L, 2);
  int h = luaL_checkinteger(L, 3);
  int value = luaL_checkinteger(L, 4);
  pixelbuffer_t pb = wrap_buffer(source, w, h, 0, 0);
  _pixmod_add(&pb, value);
  return 0;
}

static int pixmod_fill(lua_State *L)
{
  pixbuf *source = pixbuf_from_lua_arg(L, 1);
  int w = luaL_checkinteger(L, 2);
  int h = luaL_checkinteger(L, 3);
  int x = luaL_checkinteger(L, 4);
  int y = luaL_checkinteger(L, 5);
  int width = luaL_checkinteger(L, 6);
  int height = luaL_checkinteger(L, 7);
  uint32_t color = _color_pack(luaL_checkinteger(L, 8), luaL_checkinteger(L, 9), luaL_checkinteger(L, 10));
  pixelbuffer_t pb = wrap_buffer(source, w, h, 0, 0);
  _pixmod_fill(&pb, x-1, y-1, width, height, color);
  return 0;
}

LROT_BEGIN(pixmod_map, NULL, 0)
LROT_FUNCENTRY(set, pixmod_set)
LROT_FUNCENTRY(line, pixmod_line)
LROT_FUNCENTRY(add, pixmod_add)
LROT_FUNCENTRY(fill, pixmod_fill)
LROT_END(pixmod_map, NULL, 0)

NODEMCU_MODULE(PIXMOD, "pixmod", pixmod_map, NULL);

#else

int set(uint8_t *data, int width, int height, int bpp, int x, int y, int r, int g, int b)
{
  pixelbuffer_t pb = wrap_buffer(data, width, height, bpp, 0, 0);
  uint32_t color = _color_pack(r, g, b);
  _pixmod_set(&pb, x-1, y-1, color);
  return 0;
}

int line(uint8_t *data, int width, int height, int bpp, int x0, int y0, int x1, int y1, int r, int g, int b)
{
  pixelbuffer_t pb = wrap_buffer(data, width, height, bpp, 0, 0);
  uint32_t color = _color_pack(r, g, b);
  _pixmod_line(&pb, x0-1, y0-1, x1-1, y1-1, color);
  return 0;
}

int add(uint8_t *data, int width, int height, int bpp, int value)
{
  pixelbuffer_t pb = wrap_buffer(data, width, height, bpp, 0, 0);
  _pixmod_add(&pb, value);
  return 0;
}

int fill(uint8_t *data, int width, int height, int bpp, int x, int y, int w, int h, int r, int g, int b)
{
  pixelbuffer_t pb = wrap_buffer(data, width, height, bpp, 0, 0);
  uint32_t color = _color_pack(r, g, b);
  _pixmod_fill(&pb, x-1, y-1, w, h, color);
  return 0;
}

#endif