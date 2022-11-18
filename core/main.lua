
local screen_width = 20
local screen_height = 20

local buffer = pixbuf.newBuffer(screen_width * screen_height, 3)

buffer:fill(0, 0, 0)

tiles = {
  [1] = random_pixels,
  [2] = random_walk,
  [3] = cryptopunks,
}

local screen = {
  width = screen_width,
  height = screen_height,
  buffer = buffer
}

ws2812.init()

local current = 3
local state = nil

tmr.create():alarm(80, 1, function()

    state = tiles[current](state, screen)
 
    ws2812.write(buffer)
    
    if state == nil then
        current = node.random(1, table.getn(tiles));
    end
    
end)


