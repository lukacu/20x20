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

typedef struct rect
{
  int x;
  int y;
  int w;
  int h;
} rect_t;

#define min(a, b) ((a) < (b) ? (a) : (b))
#define max(a, b) ((a) > (b) ? (a) : (b))

static rect_t rect(int x, int y, int w, int h)
{
  rect_t r;
  r.x = x;
  r.y = y;
  r.w = w;
  r.h = h;
  return r;
}

static rect_t rect_intersection(rect_t *r1, rect_t *r2)
{
  int x = max(r1->x, r2->x);
  int y = max(r1->y, r2->y);
  int w = min(r1->x + r1->w, r2->x + r2->w) - x;
  int h = min(r1->y + r1->h, r2->y + r2->h) - y;
  return rect(x, y, w, h);
}

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


static void print_buffer(pixelbuffer_t *pb)
{
  printf("width: %d, height: %d, stride: %d, bpp: %d\n", pb->width, pb->height, pb->stride, pb->bpp);
}

static void print_rect(rect_t *r)
{
  printf("x: %d, y: %d, w: %d, h: %d\n", r->x, r->y, r->w, r->h);
}

static pixelbuffer_t cut_buffer(pixelbuffer_t *pb, int x, int y, int w, int h)
{
  pixelbuffer_t pb2;
  assert(pb != NULL);
  assert(x >= 0 && y >= 0 && w > 0 && h > 0);
  assert(x + w <= pb->width && y + h <= pb->height);
  pb2.width = w;
  pb2.height = h;
  // Correct stride for cut buffer
  pb2.stride = pb->stride;
  pb2.data = pb->data + y * pb->stride + x * pb->bpp;
  pb2.bpp = pb->bpp;
  return pb2;
}

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

static inline void _pixmod_set(pixelbuffer_t *pixbuf, int x, int y, uint32_t color)
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

static inline void _pixmod_line(pixelbuffer_t *pixbuf, int x0, int y0, int x1, int y1, uint32_t color)
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

static void _pixmod_copy(pixelbuffer_t *src, pixelbuffer_t *dst)
{

  if (src->width != dst->width || src->height != dst->height)
    return;

  // Determine if the buffers overlap, overlap direction and copy direction
  uint8_t *src_start = src->data;
  uint8_t *dst_start = dst->data;
  uint8_t *src_end = src->data + (src->height - 1) * src->stride + src->width * src->bpp;
  uint8_t *dst_end = dst->data + (dst->height - 1) * dst->stride + dst->width * dst->bpp;

  int reverse = (max(src_start, dst_start) < min(src_end, dst_end)) && (src_start < dst_start);

  if (reverse) {
    for (int i = src->height - 1; i >= 0; i--)
    {
      for (int j = src->width - 1; j >= 0; j--)
      {
        uint32_t color = _pixmod_get(src, j, i);
        _pixmod_set(dst, j, i, color);
      }
    }
  } else {
    for (int i = 0; i < src->height; i++)
    {
      for (int j = 0; j < src->width; j++)
      {
        uint32_t color = _pixmod_get(src, j, i);
        _pixmod_set(dst, j, i, color);
      }
    }
  }
}

static void _pixmod_blit(pixelbuffer_t *src, pixelbuffer_t *dst, int x, int y, int w, int h, int dx, int dy)
{
  // x, y, w, h are the region of the mask to be blitted
  // dx, dy are the coordinates of the destination

  rect_t src_rect = rect(x, y, w, h);
  rect_t dst_rect = rect(dx, dy, w, h);

  rect_t src_bounds = rect(0, 0, src->width, src->height);
  rect_t dst_bounds = rect(0, 0, dst->width, dst->height);

  // Take care of out of bounds
  rect_t src_clip = rect_intersection(&src_rect, &src_bounds);
  rect_t dst_clip = rect_intersection(&dst_rect, &dst_bounds);

  // Compute the intersection of the clipped source and destination
  rect_t src_clip2 = rect(src_clip.x - x, src_clip.y - y, src_clip.w, src_clip.h);
  rect_t dst_clip2 = rect(dst_clip.x - dx, dst_clip.y - dy, dst_clip.w, dst_clip.h);

  rect_t clip = rect_intersection(&src_clip2, &dst_clip2);

  if (clip.w <= 0 || clip.h <= 0)
    return;

  // Cut source buffer
  pixelbuffer_t src_cut = cut_buffer(src, x + clip.x, y + clip.y, clip.w, clip.h);
  // Cut destination buffer
  pixelbuffer_t dst_cut = cut_buffer(dst, dst_clip.x, dst_clip.y, clip.w, clip.h);

  _pixmod_copy(&src_cut, &dst_cut);
}

static void _pixmod_blit_color(pixelbuffer_t *mask, pixelbuffer_t *dst, int x, int y, int w, int h, int dx, int dy, uint32_t color)
{
  // x, y, w, h are the region of the mask to be blitted
  // dx, dy are the coordinates of the destination

  rect_t src_rect = rect(x, y, w, h);
  rect_t dst_rect = rect(dx, dy, w, h);

  rect_t src_bounds = rect(0, 0, mask->width, mask->height);
  rect_t dst_bounds = rect(0, 0, dst->width, dst->height);

  // Take care of out of bounds
  rect_t src_clip = rect_intersection(&src_rect, &src_bounds);
  rect_t dst_clip = rect_intersection(&dst_rect, &dst_bounds);

  // Compute the intersection of the clipped source and destination
  rect_t src_clip2 = rect(src_clip.x - x, src_clip.y - y, src_clip.w, src_clip.h);
  rect_t dst_clip2 = rect(dst_clip.x - dx, dst_clip.y - dy, dst_clip.w, dst_clip.h);

  rect_t clip = rect_intersection(&src_clip2, &dst_clip2);

  if (clip.w <= 0 || clip.h <= 0)
    return;

  // Cut source buffer
  pixelbuffer_t mask_cut = cut_buffer(mask, x + clip.x, y + clip.y, clip.w, clip.h);

  // Cut destination buffer
  pixelbuffer_t dst_cut = cut_buffer(dst, dst_clip.x, dst_clip.y, clip.w, clip.h);

  for (int i = 0; i < mask_cut.height; i++)
  {
    for (int j = 0; j < mask_cut.width; j++)
    {
      uint32_t mask_color = _pixmod_get(&mask_cut, j, i);
      if (mask_color != 0)
      {
        _pixmod_set(&dst_cut, j, i, color);
      } else {
        }
    }
  }
}

static void _pixmod_blit_mask(pixelbuffer_t *src, pixelbuffer_t *dst, pixelbuffer_t *mask, int x, int y, int w, int h, int dx, int dy)
{
  // source and mask must have the same dimensions
  if (src->width != mask->width || src->height != mask->height)
    return;

  // x, y, w, h are the region of the mask to be blitted
  // dx, dy are the coordinates of the destination

  rect_t src_rect = rect(x, y, w, h);
  rect_t dst_rect = rect(dx, dy, w, h);

  rect_t src_bounds = rect(0, 0, mask->width, mask->height);
  rect_t dst_bounds = rect(0, 0, dst->width, dst->height);

  // Take care of out of bounds
  rect_t src_clip = rect_intersection(&src_rect, &src_bounds);
  rect_t dst_clip = rect_intersection(&dst_rect, &dst_bounds);

  // Compute the intersection of the clipped source and destination
  rect_t src_clip2 = rect(src_clip.x - x, src_clip.y - y, src_clip.w, src_clip.h);
  rect_t dst_clip2 = rect(dst_clip.x - dx, dst_clip.y - dy, dst_clip.w, dst_clip.h);

  rect_t clip = rect_intersection(&src_clip2, &dst_clip2);

  if (clip.w <= 0 || clip.h <= 0)
    return;

  // Cut source buffer
  pixelbuffer_t src_cut = cut_buffer(src, x + clip.x, y + clip.y, clip.w, clip.h);
  // Cut destination buffer
  pixelbuffer_t dst_cut = cut_buffer(dst, dst_clip.x, dst_clip.y, clip.w, clip.h);
  // Cut mask buffer
  pixelbuffer_t mask_cut = cut_buffer(mask, x + clip.x, y + clip.y, clip.w, clip.h);

  for (int i = 0; i < mask_cut.height; i++)
  {
    for (int j = 0; j < mask_cut.width; j++)
    {
      uint32_t mask_color = _pixmod_get(&mask_cut, j, i);
      if (mask_color != 0)
      {
        uint32_t color = _pixmod_get(&src_cut, j, i);
        _pixmod_set(&dst_cut, j, i, color);
      }
    }
  }
}

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

static int pixmod_blit(lua_State *L)
{
  pixbuf *src = pixbuf_from_lua_arg(L, 1);
  int src_w = luaL_checkinteger(L, 2);
  int src_h = luaL_checkinteger(L, 3);
  int src_x = luaL_checkinteger(L, 4);
  int src_y = luaL_checkinteger(L, 5);
  int src_w2 = luaL_checkinteger(L, 6);
  int src_h2 = luaL_checkinteger(L, 7);

  pixbuf *dst = pixbuf_from_lua_arg(L, 8);
  int dst_w = luaL_checkinteger(L, 9);
  int dst_h = luaL_checkinteger(L, 10);
  int dst_x = luaL_checkinteger(L, 11);
  int dst_y = luaL_checkinteger(L, 12);

  _pixmod_blit(wrap_buffer(src, src_w, src_h, 0, 0), wrap_buffer(dst, dst_w, dst_h, 0, 0), src_x, src_y, src_w2, src_h2, dst_x, dst_y);
  return 0;
}

static int pixmod_blit_color(lua_State *L)
{
  pixbuf *mask = pixbuf_from_lua_arg(L, 1);
  int mask_w = luaL_checkinteger(L, 2);
  int mask_h = luaL_checkinteger(L, 3);
  int mask_x = luaL_checkinteger(L, 4);
  int mask_y = luaL_checkinteger(L, 5);
  int mask_w2 = luaL_checkinteger(L, 6);
  int mask_h2 = luaL_checkinteger(L, 7);

  pixbuf *dst = pixbuf_from_lua_arg(L, 8);
  int dst_w = luaL_checkinteger(L, 9);
  int dst_h = luaL_checkinteger(L, 10);
  int dst_x = luaL_checkinteger(L, 11);
  int dst_y = luaL_checkinteger(L, 12);

  uint32_t color = _color_pack(luaL_checkinteger(L, 13), luaL_checkinteger(L, 14), luaL_checkinteger(L, 15));

  _pixmod_blit_color(wrap_buffer(mask, mask_w, mask_h, 0, 0), wrap_buffer(dst, dst_w, dst_h, 0, 0), mask_x, mask_y, mask_w2, mask_h2, dst_x, dst_y, color);
  return 0;
}

static int pixmod_blit_mask(lua_State *L)
{
  pixbuf *src = pixbuf_from_lua_arg(L, 1);
  int src_w = luaL_checkinteger(L, 2);
  int src_h = luaL_checkinteger(L, 3);
  int src_x = luaL_checkinteger(L, 4);
  int src_y = luaL_checkinteger(L, 5);
  int src_w2 = luaL_checkinteger(L, 6);
  int src_h2 = luaL_checkinteger(L, 7);

  pixbuf *dst = pixbuf_from_lua_arg(L, 8);
  int dst_w = luaL_checkinteger(L, 9);
  int dst_h = luaL_checkinteger(L, 10);
  int dst_x = luaL_checkinteger(L, 11);
  int dst_y = luaL_checkinteger(L, 12);

  pixbuf *mask = pixbuf_from_lua_arg(L, 13);
  int mask_w = luaL_checkinteger(L, 14);
  int mask_h = luaL_checkinteger(L, 15);

  _pixmod_blit_mask(wrap_buffer(src, src_w, src_h, 0, 0), wrap_buffer(dst, dst_w, dst_h, 0, 0), wrap_buffer(mask, mask_w, mask_h, 0, 0), src_x, src_y, src_w2, src_h2, dst_x, dst_y);
  return 0;
}


LROT_BEGIN(pixmod_map, NULL, 0)
LROT_FUNCENTRY(set, pixmod_set)
LROT_FUNCENTRY(line, pixmod_line)
LROT_FUNCENTRY(add, pixmod_add)
LROT_FUNCENTRY(fill, pixmod_fill)
LROT_FUNCENTRY(blit, pixmod_blit)
LROT_FUNCENTRY(blit_color, pixmod_blit_color)
LROT_FUNCENTRY(blit_mask, pixmod_blit_mask)
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

int blit(uint8_t *src, int src_width, int src_height, int src_bpp, uint8_t *dst, int dst_width, int dst_height, int dst_bpp, int x, int y, int w, int h, int dx, int dy)
{
  pixelbuffer_t pb_src = wrap_buffer(src, src_width, src_height, src_bpp, 0, 0);
  pixelbuffer_t pb_dst = wrap_buffer(dst, dst_width, dst_height, dst_bpp, 0, 0);
  _pixmod_blit(&pb_src, &pb_dst, x-1, y-1, w, h, dx-1, dy-1);
  return 0;
}

int blit_color(uint8_t *mask, int mask_width, int mask_height, int mask_bpp, uint8_t *dst, int dst_width, int dst_height, int dst_bpp, int x, int y, int w, int h, int dx, int dy, int r, int g, int b)
{
  pixelbuffer_t pb_target = wrap_buffer(dst, dst_width, dst_height, dst_bpp, 0, 0);
  pixelbuffer_t pb_mask = wrap_buffer(mask, mask_width, mask_height, mask_bpp, 0, 0);
  uint32_t color = _color_pack(r, g, b);
  _pixmod_blit_color(&pb_mask, &pb_target, x-1, y-1, w, h, dx-1, dy-1, color);
  return 0;
}

int blit_mask(uint8_t *src, int src_width, int src_height, int src_bpp, uint8_t *dst, int dst_width, int dst_height, int dst_bpp, uint8_t *mask, int mask_width, int mask_height, int x, int y, int w, int h, int dx, int dy)
{
  pixelbuffer_t pb_src = wrap_buffer(src, src_width, src_height, src_bpp, 0, 0);
  pixelbuffer_t pb_dst = wrap_buffer(dst, dst_width, dst_height, dst_bpp, 0, 0);
  pixelbuffer_t pb_mask = wrap_buffer(mask, mask_width, mask_height, 1, 0, 0);
  _pixmod_blit_mask(&pb_src, &pb_dst, &pb_mask, x-1, y-1, w, h, dx-1, dy-1);
  return 0;
}

#endif